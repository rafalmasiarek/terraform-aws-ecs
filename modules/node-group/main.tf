data "aws_ssm_parameter" "ami_x86_64" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

data "aws_ssm_parameter" "ami_arm64" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}

data "aws_ec2_instance_type" "this" {
  count         = var.ami_id == null ? 1 : 0
  instance_type = var.instance_type
}

locals {
  resolved_ami_id = var.ami_id != null ? var.ami_id : (
    contains(try(data.aws_ec2_instance_type.this[0].supported_architectures, []), "arm64")
    ? data.aws_ssm_parameter.ami_arm64[0].value
    : data.aws_ssm_parameter.ami_x86_64[0].value
  )

  agent_environment = coalesce(try(var.ecs_agent_config.environment, null), {})
  registry_auth     = try(var.ecs_agent_config.registry_auth, null)
  registry_map      = coalesce(try(local.registry_auth.registries, null), {})
  registry_type     = try(local.registry_auth.type, "")

  agent_env = merge(
    {
      ECS_ENABLE_CONTAINER_METADATA     = "true"
      ECS_ENABLE_SPOT_INSTANCE_DRAINING = "true"
    },
    local.agent_environment,
  )

  auth_entries = [
    for i, reg in sort(keys(local.registry_map)) : {
      index    = i
      registry = reg
      username = local.registry_map[reg].username
      email    = local.registry_map[reg].email != null ? local.registry_map[reg].email : ""
      source   = local.registry_map[reg].password.plaintext != null ? "plaintext" : (local.registry_map[reg].password.file != null ? "file" : "secretsmanager")
      ref      = local.registry_map[reg].password.plaintext != null ? local.registry_map[reg].password.plaintext : (local.registry_map[reg].password.file != null ? local.registry_map[reg].password.file : local.registry_map[reg].password.secretsmanager_secret_arn)
    }
  ]

  auth_all_plaintext = local.registry_auth != null && alltrue([for e in local.auth_entries : e.source == "plaintext"])
  auth_has_file      = local.registry_auth != null && anytrue([for e in local.auth_entries : e.source == "file"])

  auth_data_static = local.registry_auth == null ? null : jsonencode({
    for e in local.auth_entries : e.registry => local.registry_type == "docker"
    ? merge({ username = e.username, password = e.ref }, e.email != "" ? { email = e.email } : {})
    : merge({ auth = base64encode("${e.username}:${e.ref}") }, e.email != "" ? { email = e.email } : {})
  })

  shq = { for v in distinct(flatten([
    [var.cluster_name],
    [for k, v in local.agent_env : v],
    [local.registry_type],
    [for e in local.auth_entries : [e.registry, e.username, e.email, e.ref]],
    local.registry_auth == null ? [] : ["ECS_ENGINE_AUTH_DATA=${local.auth_data_static}"],
  ])) : v => "'${replace(v, "'", "'\\''")}'" }

  agent_env_lines = [
    for k in sort(keys(local.agent_env)) :
    "printf '%s\\n' '${k}=${local.shq[local.agent_env[k]]}'"
  ]

  auth_wait_fn_tpl = <<-FN
wait_for_file() {
  local path="$1"
  local retries="$${ECS_REGISTRY_AUTH_WAIT_RETRIES:-30}"
  local interval="$${ECS_REGISTRY_AUTH_WAIT_INTERVAL:-5}"
  local i=0
  while [ "$i" -lt "$retries" ]; do
    [ -f "$path" ] && return 0
    i=$((i + 1))
    sleep "$interval"
  done
  echo "registry secret file '$path' not found after $((retries * interval))s" >&2
  return 1
}
FN

  auth_fn_tpl = <<-FN
resolve_password() {
  local kind="$1" ref="$2"
  case "$kind" in
    plaintext) printf '%s' "$ref" ;;
    file)
      wait_for_file "$ref" || return 1
      printf '%s' "$(cat -- "$ref")"
      ;;
    secretsmanager) aws secretsmanager get-secret-value --secret-id "$ref" --query 'SecretString' --output text ;;
  esac
}

add_registry() {
  local reg="$1" user="$2" pass="$3" email="$4"
  if [ "$REGISTRY_AUTH_TYPE" = "dockercfg" ]; then
    local auth
    auth=$(printf '%s' "$${user}:$${pass}" | base64 -w0)
    REGISTRY_AUTH_DATA=$(jq -c -n --argjson d "$REGISTRY_AUTH_DATA" --arg r "$reg" --arg a "$auth" --arg e "$email" '$d + {($r): (({auth: $a} + (if $e == "" then {} else {email: $e} end)))}')
  else
    REGISTRY_AUTH_DATA=$(jq -c -n --argjson d "$REGISTRY_AUTH_DATA" --arg r "$reg" --arg u "$user" --arg p "$pass" --arg e "$email" '$d + {($r): (({username: $u, password: $p} + (if $e == "" then {} else {email: $e} end)))}')
  fi
}
FN

  auth_wait_fn = local.auth_has_file ? local.auth_wait_fn_tpl : ""
  auth_fn      = local.registry_auth == null ? "" : local.auth_fn_tpl

  auth_resolve_lines = local.auth_all_plaintext ? [] : flatten([
    for e in local.auth_entries : e.source == "plaintext" ? [
      "pass_${e.index}=${local.shq[e.ref]}",
      ] : [
      "pass_${e.index}=$(resolve_password '${e.source}' ${local.shq[e.ref]})",
    ]
  ])

  auth_append_lines = local.registry_auth == null ? [] : [
    "printf '%s\\n' 'ECS_ENGINE_AUTH_TYPE=${local.registry_type}' >> /etc/ecs/ecs.config",
    local.auth_all_plaintext ?
    "printf '%s\\n' ${local.shq["ECS_ENGINE_AUTH_DATA=${local.auth_data_static}"]} >> /etc/ecs/ecs.config" :
    "printf '%s\\n' \"ECS_ENGINE_AUTH_DATA=$${REGISTRY_AUTH_DATA}\" >> /etc/ecs/ecs.config",
  ]

  # All-plaintext needs no boot-time resolution - the JSON is embedded as-is.
  auth_block = local.registry_auth == null ? "" : local.auth_all_plaintext ? join("\n", local.auth_append_lines) : join("\n", concat(
    [
      "REGISTRY_AUTH_TYPE=${local.shq[local.registry_type]}",
      "REGISTRY_AUTH_DATA='{}'",
      local.auth_fn,
      local.auth_wait_fn,
    ],
    local.auth_resolve_lines,
    [for e in local.auth_entries : "add_registry ${local.shq[e.registry]} ${local.shq[e.username]} \"$pass_${e.index}\" ${local.shq[e.email]}"],
    local.auth_append_lines,
  ))

  agent_config_script = <<-EOT
#!/bin/bash
set -euo pipefail
{
printf '%s\n' 'ECS_CLUSTER=${local.shq[var.cluster_name]}'
${join("\n", local.agent_env_lines)}
} >> /etc/ecs/ecs.config
${local.auth_block}
EOT

  # First-boot agent start. Not enabled: runcmd (once per instance) starts it,
  # so reboots go through the packaged ecs unit (enabled by the AMI, or by
  # enable --now on first boot) and the agent is never restarted by this
  # module again. The unit only enables/starts the packaged ecs unit - it
  # never writes to it.
  agent_start_unit = <<-EOT
[Unit]
Description=Start the ECS agent (managed by Terraform, once per instance)
After=cloud-final.service docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl enable --now ecs
EOT

  node_role_created      = try(var.iam.create, null) != null
  registry_auth_sm_arns  = [for c in values(local.registry_map) : c.password.secretsmanager_secret_arn if c.password.secretsmanager_secret_arn != null]
  registry_auth_kms_arns = [for c in values(local.registry_map) : c.password.kms_key_arn if c.password.kms_key_arn != null]
  node_role_profile_name = local.node_role_created ? aws_iam_instance_profile.instance[0].name : coalesce(try(var.iam.use_existing.instance_profile_name, null), var.iam_instance_profile_name)
}

data "aws_iam_policy_document" "instance_assume" {
  count = local.node_role_created ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

module "instance_role" {
  source = "../iam-role"
  count  = local.node_role_created ? 1 : 0

  name                        = var.iam.create.name
  assume_role_policy_document = data.aws_iam_policy_document.instance_assume[0].json
  permissions_boundary_arn    = var.iam.create.permission_boundary_arn
  managed_policy_arns = concat(
    [
      "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    ],
    var.iam.create.managed_policy_arns,
  )
  inline_policies = var.iam.create.inline_policies
  least_privilege = {
    ecr_registry_arns          = var.iam.create.least_privilege.ecr_registry_arns
    secretsmanager_secret_arns = concat(var.iam.create.least_privilege.secretsmanager_secret_arns, local.registry_auth_sm_arns)
    ssm_parameter_arns         = var.iam.create.least_privilege.ssm_parameter_arns
    kms_key_arns               = concat(var.iam.create.least_privilege.kms_key_arns, local.registry_auth_kms_arns)
    route53_hosted_zone_arns   = var.iam.create.least_privilege.route53_hosted_zone_arns
  }
  tags = var.tags
}

resource "aws_iam_instance_profile" "instance" {
  count = local.node_role_created ? 1 : 0

  role = module.instance_role[0].name
}

locals {
  agent_start_unit_name = "terraform-ecs-agent-start"

  # Appended after the user's own entries (in order) - separate cloud-init
  # parts, so user parts run first and are never touched: the config script
  # only appends module-owned lines to /etc/ecs/ecs.config, and the start unit
  # only enables/starts the packaged ecs unit (no unit files of its own, no
  # drop-ins). Start is queued non-blocking from runcmd: the unit is ordered
  # After=cloud-final.service, which is the very unit running runcmd, so a
  # blocking start would deadlock.
  node_group_cloudinit_config = merge(
    var.cloudinit_config,
    {
      shell_scripts = concat(
        try(var.cloudinit_config.shell_scripts, []),
        [local.agent_config_script],
      )
      systemd_units = concat(
        try(var.cloudinit_config.systemd_units, []),
        [{
          name    = local.agent_start_unit_name
          content = local.agent_start_unit
        }],
      )
      commands = concat(
        try(var.cloudinit_config.commands, []),
        ["systemctl start ${local.agent_start_unit_name} --no-block"],
      )
    },
  )
}

module "nodes" {
  source  = "rafalmasiarek/ec2-autoscale-group/aws"
  version = "0.2.0"

  name          = var.name
  ami_id        = local.resolved_ami_id
  instance_type = var.instance_type

  subnet_ids                  = var.subnet_ids
  vpc_security_group_ids      = var.vpc_security_group_ids
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile_name   = local.node_role_profile_name
  key_name                    = var.key_name
  cloudinit_config            = local.node_group_cloudinit_config
  block_device_mappings       = var.block_device_mappings

  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.desired_capacity
  mixed_instances_policy = var.mixed_instances_policy
  instance_refresh       = var.instance_refresh

  # ProtectFromScaleIn is required by ECS managed_termination_protection;
  # ECS has no ELB-aware health check of its own, so EC2 (instance status)
  # is the correct type.
  protect_from_scale_in = var.protect_from_scale_in
  health_check_type     = "EC2"

  autoscaling_policies_enabled = var.autoscaling_policies_enabled

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = var.tags
}
