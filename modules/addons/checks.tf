# Plan-time requirement checks (SG for any enabled preset, VPC for presets
# that create LBs or need VPC-scoped resources).

check "cluster_sg_required" {
  assert {
    condition     = !local.addons_require_sg || var.cluster_security_group_id != null
    error_message = "cluster_security_group_id is required when any add-on preset is enabled."
  }
}

check "vpc_required" {
  assert {
    condition     = !local.addons_require_vpc || var.vpc_id != null
    error_message = "vpc_id is required when a preset creates a load balancer or needs VPC-scoped resources."
  }
}
