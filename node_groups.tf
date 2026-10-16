module "node_group" {
  source = "./modules/node-group"

  for_each = var.node_groups

  cluster_name = var.name
  name         = "${var.name}-${each.key}"

  ami_id        = try(each.value.ami_id, null)
  instance_type = each.value.instance_type

  subnet_ids = each.value.subnet_ids
  vpc_security_group_ids = concat(
    [aws_security_group.this.id],
    try(each.value.additional_security_group_ids, []),
  )
  associate_public_ip_address = try(each.value.associate_public_ip_address, false)

  iam_instance_profile_name = try(
    each.value.iam_instance_profile_name,
    var.create_instance_iam_role ? aws_iam_instance_profile.instance[0].name : null,
  )
  key_name = try(each.value.key_name, null)

  min_size         = each.value.min_size
  max_size         = each.value.max_size
  desired_capacity = try(each.value.desired_capacity, null)

  mixed_instances_policy = try(each.value.mixed_instances_policy, null)
  instance_refresh = try(each.value.instance_refresh, {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 66
    }
  })
  block_device_mappings = try(each.value.block_device_mappings, [])
  cloudinit_config      = try(each.value.cloudinit_config, {})

  force_delete = try(each.value.force_delete, false)

  autoscaling_policies_enabled = try(each.value.autoscaling_policies_enabled, false)

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = var.tags
  origin_module  = "node-group"
}
