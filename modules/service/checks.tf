# Validate that launch_type and requires_compatibilities are consistent.
# A FARGATE launch type requires ["FARGATE"] in compatibilities; an EC2
# launch type (or capacity provider strategy) requires ["EC2"].
check "launch_type_compatibility" {
  assert {
    # When using capacity provider strategy, either EC2 or FARGATE compat is acceptable.
    condition = length(var.capacity_provider_strategy) == 0 ? true : (
      contains(var.requires_compatibilities, "EC2") || contains(var.requires_compatibilities, "FARGATE")
    )
    error_message = "When using capacity_provider_strategy, requires_compatibilities must include \"EC2\" or \"FARGATE\"."
  }
}

check "launch_type_matches_compat" {
  assert {
    # Only validate when not using capacity provider strategy (which overrides launch_type).
    condition = local.use_capacity_provider_strategy ? true : (
      var.launch_type == "FARGATE" ? contains(var.requires_compatibilities, "FARGATE") : contains(var.requires_compatibilities, "EC2")
    )
    error_message = "launch_type and requires_compatibilities must match: FARGATE launch type requires [\"FARGATE\"] in compatibilities; EC2 launch type requires [\"EC2\"]."
  }
}
