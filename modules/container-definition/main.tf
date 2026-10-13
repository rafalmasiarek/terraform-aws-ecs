locals {
  port_mappings = [
    for p in var.port_mappings : {
      containerPort = p.container_port
      hostPort      = p.host_port
      protocol      = p.protocol
      name          = p.name
    }
  ]

  environment = [for k, v in var.environment : { name = k, value = v }]
  secrets     = [for k, v in var.secrets : { name = k, valueFrom = v }]

  mount_points = [
    for m in var.mount_points : {
      sourceVolume  = m.source_volume
      containerPath = m.container_path
      readOnly      = m.read_only
    }
  ]

  depends_on_containers = [
    for d in var.depends_on_containers : {
      containerName = d.container_name
      condition     = d.condition
    }
  ]

  log_configuration = var.log_configuration == null ? null : {
    logDriver = var.log_configuration.log_driver
    options   = var.log_configuration.options
  }

  health_check = var.health_check == null ? null : {
    command     = var.health_check.command
    interval    = var.health_check.interval
    timeout     = var.health_check.timeout
    retries     = var.health_check.retries
    startPeriod = var.health_check.start_period
  }

  linux_parameters = var.linux_parameters == null ? null : {
    initProcessEnabled = try(var.linux_parameters.init_process_enabled, null)
    sharedMemorySize   = try(var.linux_parameters.shared_memory_size, null)
  }

  container_definition = {
    name                   = var.container_name
    image                  = var.image
    essential              = var.essential
    cpu                    = var.cpu
    memory                 = var.memory
    memoryReservation      = var.memory_reservation
    entryPoint             = var.entrypoint
    command                = var.command
    workingDirectory       = var.working_directory
    readonlyRootFilesystem = var.readonly_root_filesystem
    user                   = var.user
    portMappings           = length(local.port_mappings) > 0 ? local.port_mappings : null
    environment            = length(local.environment) > 0 ? local.environment : null
    secrets                = length(local.secrets) > 0 ? local.secrets : null
    logConfiguration       = local.log_configuration
    healthCheck            = local.health_check
    dependsOn              = length(local.depends_on_containers) > 0 ? local.depends_on_containers : null
    mountPoints            = length(local.mount_points) > 0 ? local.mount_points : null
    linuxParameters        = local.linux_parameters
  }

  container_definition_clean = { for k, v in local.container_definition : k => v if v != null }
  final_container_definition = merge(local.container_definition_clean, var.extra_fields)
}
