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
  # ECS platform context for the standardized tag set: the node group's ASG
  # and its instances are tagged with the container profile ({ cluster,
  # node_group }) so cost tooling can attribute node spend to the cluster.
  node_group_service_profile = {
    container = {
      cluster    = var.cluster_name
      node_group = var.name
    }
  }

  taggable = {
    this = {
      name       = var.name
      service    = local.node_group_service_profile
      attributes = ["node-group"]
      created_at = null
      extra_tags = {}
    }
  }

  resolved_ami_id = var.ami_id != null ? var.ami_id : (
    contains(try(data.aws_ec2_instance_type.this[0].supported_architectures, []), "arm64")
    ? data.aws_ssm_parameter.ami_arm64[0].value
    : data.aws_ssm_parameter.ami_x86_64[0].value
  )

  user_data = <<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=${var.cluster_name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
  EOT
}

locals {
  node_group_cloudinit_config = merge(
    var.cloudinit_config,
    {
      cloudinit_parts = concat(
        try(var.cloudinit_config.cloudinit_parts, []),
        [{
          content_type = "text/x-shellscript"
          content      = local.user_data
        }],
      )
    },
  )
}

module "nodes" {
  source  = "rafalmasiarek/ec2-autoscale-group/aws"
  version = "0.1.0"

  name          = var.name
  ami_id        = local.resolved_ami_id
  instance_type = var.instance_type

  subnet_ids                  = var.subnet_ids
  vpc_security_group_ids      = var.vpc_security_group_ids
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile_name   = var.iam_instance_profile_name
  key_name                    = var.key_name
  # The autoscale-group module forwards this as a wildcard passthrough to
  # terraform-null-cloudinit (map of its inputs) - keep the map shape, but
  # pin ssh_authorized_keys to a list: try() with a {} default would hand an
  # empty object to a list(string) variable and fail the plan.
  cloudinit_config = merge(local.node_group_cloudinit_config, {
    ssh_authorized_keys = []
  })
  block_device_mappings = var.block_device_mappings

  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.desired_capacity
  mixed_instances_policy = var.mixed_instances_policy
  instance_refresh       = var.instance_refresh

  # Required by ECS managed_termination_protection; ECS has no ELB-aware
  # health check of its own, so EC2 (instance status) is the correct type.
  protect_from_scale_in = true
  health_check_type     = "EC2"
  force_delete          = var.force_delete

  autoscaling_policies_enabled = var.autoscaling_policies_enabled

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = local.tagger_tags["this"]
}
