locals {
  # Auto-detect the cluster's capacity model from plan facts.
  # Hybrid approach (mirrors terraform-aws-modules/eks philosophy):
  # - Mixed clusters (EC2 + Fargate): awsvpc addons get ["EC2", "FARGATE"]
  #   so the ECS scheduler places them optimally.
  # - Pure-EC2: everything defaults to EC2.
  # - Pure-Fargate: everything defaults to FARGATE.
  # - EC2-only addons (node_exporter, cadvisor, falco) are ALWAYS EC2
  #   regardless of cluster type (they need host mounts).
  addon_has_ec2      = try(var.plan_facts.has_ec2_capacity, false)
  addon_has_fargate  = try(var.plan_facts.has_fargate_capacity, false)
  addon_is_mixed     = try(var.plan_facts.is_mixed, false)

  # Default for awsvpc addons (otel, cwa, fluent_bit, blackbox):
  # mixed -> both, pure-EC2 -> EC2, pure-Fargate -> FARGATE.
  addon_default_launch = local.addon_has_ec2 && !local.addon_has_fargate ? "EC2" : "FARGATE"
  addon_default_compat = concat(
    local.addon_has_ec2 ? ["EC2"] : [],
    local.addon_has_fargate ? ["FARGATE"] : [],
  )

  # EC2 daemon addons are always EC2 (host mounts requirement).
  addon_ec2_daemon_compat = ["EC2"]

  # Per-preset enabled flags, defaulting to true when the block is present.
  # Every known preset key is always present (defaulting to false when the
  # block is absent) so attribute access never fails on a partial map.
  addon_all_keys = ["traefik", "opentelemetry", "cloudwatch_agent", "fluent_bit",
  "node_exporter", "cadvisor", "falco", "blackbox_exporter"]

  addon_enabled = { for k in local.addon_all_keys : k => (
    var.cluster_addons != null && contains(keys(var.cluster_addons), k) ? try(var.cluster_addons[k].enabled, true) : false
  ) }

  addon_services = { for k, v in local.addon_enabled : k => v if v }

  # Enabled presets need a cluster SG; LB/port-rule presets need a VPC.
  addons_require_sg = length(local.addon_services) > 0
  addons_require_vpc = anytrue([
    local.addon_enabled.traefik && local.traefik_create_lb,
    local.addon_enabled.opentelemetry,
    local.addon_enabled.cloudwatch_agent,
    local.addon_enabled.fluent_bit,
    local.addon_enabled.blackbox_exporter,
  ])

  taggable = merge(
    { for k in keys(local.addon_services) : "svc-${k}" => {
      name       = "${var.cluster_name}-addon-${k}"
      service    = {}
      attributes = []
      created_at = null
      extra_tags = {}
    } },
    { for k in keys(local.addon_services) : "${k}-task" => {
      name       = "${var.cluster_name}-addon-${k}-task"
      service    = {}
      attributes = []
      created_at = null
      extra_tags = {}
    } },
    { for k in keys(local.addon_services) : "${k}-execution" => {
      name       = "${var.cluster_name}-addon-${k}-execution"
      service    = {}
      attributes = []
      created_at = null
      extra_tags = {}
    } },
  )

  awslogs_options = { for k in local.addon_all_keys : k => {
    "awslogs-group"         = "/aws/ecs/${var.cluster_name}/addons/${k}"
    "awslogs-region"        = data.aws_region.current.region
    "awslogs-stream-prefix" = "ecs/${var.cluster_name}/addons/${k}"
    "awslogs-create-group"  = "true"
  } }

  # ---------------------------------------------------------------------
  # Traefik
  # ---------------------------------------------------------------------

  traefik_cfg = try(var.cluster_addons.traefik, {})

  # Deployment model: an EC2 launch type (or EC2 capacity providers)
  # defaults to a DAEMON bridge service - one proxy per node, host ports
  # 80/443, no task ENI. Fargate stays a replicated awsvpc service; an
  # explicit scheduling_strategy = "REPLICA" forces replicas on EC2 too.
  traefik_daemon = try(var.plan_facts.traefik_daemon, false)

  # Ingress facts (pre-computed at the root where cluster_addons is known).
  traefik_create_lb    = try(var.plan_facts.traefik_create_lb, true)
  traefik_nlb          = try(var.plan_facts.traefik_nlb, false)
  traefik_internal     = try(var.plan_facts.traefik_internal, true)
  traefik_ep_443       = try(var.plan_facts.traefik_entrypoint_443, false)
  traefik_routes_count = try(var.plan_facts.traefik_routes_count, 0)

  # Subnets: awsvpc tasks default to every available subnet of the VPC.
  traefik_subnets = length(coalesce(try(local.traefik_cfg.subnets, null), [])) > 0 ? local.traefik_cfg.subnets : [for s in data.aws_subnets.vpc[0].ids : s]

  # Declarative routes -> dynamic file provider config, delivered through
  # an SSM parameter secret (TRAEFIK_ROUTES) written to /etc/traefik/dynamic.
  traefik_routes_yaml = local.traefik_routes_count > 0 ? yamlencode({
    http = {
      routers = {
        for r in coalesce(try(local.traefik_cfg.routes, null), []) : r.name => {
          rule        = r.rule
          entryPoints = coalesce(try(r.entrypoints, null), ["web"])
          service     = r.service
        }
      }
    }
  }) : null

  # TLS management: "lb" (default, ALB terminates), "traefik" (ACME Let's
  # Encrypt), or "manual" (user-provided certs in a directory).
  traefik_tls_managed_by = try(local.traefik_cfg.tls.managed_by, "lb")
  traefik_acme           = local.traefik_tls_managed_by == "traefik"
  traefik_manual_tls     = local.traefik_tls_managed_by == "manual"
  traefik_acme_cfg       = try(local.traefik_cfg.tls.acme, null)

  # Manual TLS: certificates_directory (container path, default
  # /etc/traefik/certs) + optional storage volume (EFS/EBS) mounted there.
  traefik_manual_certs_dir   = local.traefik_manual_tls ? coalesce(try(local.traefik_cfg.tls.certificates_directory, null), "/etc/traefik/certs") : null
  traefik_manual_tls_storage = local.traefik_manual_tls ? try(local.traefik_cfg.tls.storage, null) : null

  # ACME storage: tls.acme.storage (EFS/EBS) mounted at /data.
  traefik_acme_storage = local.traefik_acme ? try(local.traefik_acme_cfg.storage, null) : null

  # Storage volumes: ACME -> /data (rw), manual TLS -> certificates_directory (ro).
  traefik_acme_volume = local.traefik_acme && local.traefik_acme_storage != null ? [{
    name = "acme-storage"
    efs_volume_configuration = try(local.traefik_acme_storage.type, "") == "efs" ? {
      file_system_id     = coalesce(try(local.traefik_acme_storage.filesystem_id, null), try(local.traefik_acme_storage.arn, null) != null ? split("/", local.traefik_acme_storage.arn)[length(split("/", local.traefik_acme_storage.arn)) - 1] : null)
      transit_encryption = "ENABLED"
    } : null
    ebs_volume_configuration = try(local.traefik_acme_storage.type, "") == "ebs" ? {
      volume_id = coalesce(try(local.traefik_acme_storage.volume_id, null), try(local.traefik_acme_storage.arn, null) != null ? split("/", local.traefik_acme_storage.arn)[length(split("/", local.traefik_acme_storage.arn)) - 1] : null)
    } : null
  }] : []

  traefik_manual_tls_volume = local.traefik_manual_tls && local.traefik_manual_tls_storage != null ? [{
    name = "tls-certs"
    efs_volume_configuration = try(local.traefik_manual_tls_storage.type, "") == "efs" ? {
      file_system_id     = coalesce(try(local.traefik_manual_tls_storage.filesystem_id, null), try(local.traefik_manual_tls_storage.arn, null) != null ? split("/", local.traefik_manual_tls_storage.arn)[length(split("/", local.traefik_manual_tls_storage.arn)) - 1] : null)
      transit_encryption = "ENABLED"
    } : null
    ebs_volume_configuration = try(local.traefik_manual_tls_storage.type, "") == "ebs" ? {
      volume_id = coalesce(try(local.traefik_manual_tls_storage.volume_id, null), try(local.traefik_manual_tls_storage.arn, null) != null ? split("/", local.traefik_manual_tls_storage.arn)[length(split("/", local.traefik_manual_tls_storage.arn)) - 1] : null)
    } : null
  }] : []

  traefik_volumes = concat(local.traefik_acme_volume, local.traefik_manual_tls_volume)

  traefik_mount_points = concat(
    local.traefik_acme && local.traefik_acme_storage != null ? [{ sourceVolume = "acme-storage", containerPath = "/data", readOnly = false }] : [],
    local.traefik_manual_tls && local.traefik_manual_tls_storage != null ? [{ sourceVolume = "tls-certs", containerPath = local.traefik_manual_certs_dir, readOnly = true }] : [],
  )

  # Static configuration as CLI flags (no config file needed).
  traefik_provider_cfg = try(local.traefik_cfg.provider, {})

  traefik_flags = concat(
    [
      "--providers.ecs=true",
      "--providers.ecs.exposedByDefault=${try(local.traefik_provider_cfg.exposed_by_default, false)}",
      "--providers.ecs.defaultRule=false",
      "--api.insecure=false",
      "--log.level=INFO",
    ],
    local.traefik_ep_443 ? [
      "--entrypoints.websecure.address=:443",
      # Redirect all HTTP (port 80) to HTTPS (port 443).
      "--entrypoints.web.http.redirections.entryPoint.to=websecure",
      "--entrypoints.web.http.redirections.entryPoint.scheme=https",
      "--entrypoints.web.http.redirections.entryPoint.permanent=true",
    ] : [],
    local.traefik_acme ? [
      "--entrypoints.websecure.http.tls=true",
      "--entrypoints.websecure.http.tls.certificatesResolvers=le",
      "--certificatesResolvers.le.acme.email=${local.traefik_acme_cfg.email}",
      "--certificatesResolvers.le.acme.storage=/data/acme.json",
      "--certificatesResolvers.le.acme.dnsChallenge.provider=${try(local.traefik_acme_cfg.dns_provider, "route53")}",
    ] : [],
    # Manual TLS: enable TLS on websecure; traefik serves certs from the
    # mounted directory (user must name files to match SNI hosts, e.g.
    # example.com.crt/.key for example.com).
    local.traefik_manual_tls ? [
      "--entrypoints.websecure.http.tls=true",
    ] : [],
    local.traefik_routes_count > 0 ? [
      "--providers.file.directory=/etc/traefik/dynamic",
      "--providers.file.watch=true",
    ] : [],
    coalesce(try(local.traefik_cfg.extra_args, null), []),
  )

  # The image entrypoint execs the first argument (command must lead with
  # "traefik"), and Traefik 3.7+ treats a bare first argument as a subcommand,
  # so bootstrap through a shell that materializes the routes file first.
  traefik_bootstrap = concat(
    local.traefik_routes_count > 0 ? ["printf '%s' \"$TRAEFIK_ROUTES\" > /etc/traefik/dynamic/routes.yml &&"] : [],
    ["exec /entrypoint.sh ${join(" ", local.traefik_flags)}"],
  )

  traefik_env_map = merge(
    { TRAEFIK_ROUTES = local.traefik_routes_yaml },
    coalesce(try(local.traefik_cfg.environment, null), {}),
  )

  # Port mappings: hostPort always equals containerPort (Fargate requires
  # the match; EC2 awsvpc accepts it; daemon binds the node port directly).
  traefik_port_mappings = concat(
    [{ containerPort = 80, hostPort = 80, protocol = "tcp" }],
    local.traefik_ep_443 ? [{ containerPort = 443, hostPort = 443, protocol = "tcp" }] : [],
  )

  traefik_container = merge(
    {
      name             = "traefik"
      image            = local.addon_image.traefik
      essential        = true
      entryPoint       = ["/bin/sh", "-c"]
      command          = local.traefik_bootstrap
      environment      = [for k, v in local.traefik_env_map : { name = k, value = v } if v != null]
      portMappings     = local.traefik_port_mappings
      logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.traefik }
    },
    length(local.traefik_mount_points) > 0 ? { mountPoints = local.traefik_mount_points } : {},
    local.traefik_routes_count > 0 ? {
      secrets = [{ name = "TRAEFIK_ROUTES", valueFrom = try(aws_ssm_parameter.traefik_routes[0].arn, null) }]
    } : {},
    length(coalesce(try(local.traefik_cfg.docker_labels, null), {})) > 0 ? { dockerLabels = try(local.traefik_cfg.docker_labels, {}) } : {},
  )

  # EC2 (daemon or capacity providers) -> EC2 compat; Fargate -> FARGATE.
  # CPU/memory sizes must match the compatibility list (512/256 is invalid
  # for Fargate).
  traefik_compat = local.traefik_daemon || length(coalesce(try(local.traefik_cfg.capacity_provider_strategy, null), [])) > 0 ? ["EC2"] : ["FARGATE"]

  traefik_task_cpu    = local.traefik_compat == ["EC2"] ? try(local.traefik_cfg.task_cpu, 512) : coalesce(try(local.traefik_cfg.task_cpu, null), 256)
  traefik_task_memory = local.traefik_compat == ["EC2"] ? try(local.traefik_cfg.task_memory, 256) : coalesce(try(local.traefik_cfg.task_memory, null), 512)

  # Target group wiring: create mode uses the module-built TGs (keyed by
  # container port); existing mode uses the caller's ARNs.
  traefik_tg_arn_80 = local.traefik_create_lb ? try(aws_lb_target_group.traefik[80].arn, null) : try(local.traefik_cfg.ingress.target_group_arn, null)
  traefik_tg_arn_443 = local.traefik_ep_443 ? (
    local.traefik_create_lb ? try(aws_lb_target_group.traefik[443].arn, null) : try(local.traefik_cfg.ingress.target_group_arn_443, null)
  ) : null

  traefik_load_balancers = concat(
    local.traefik_tg_arn_80 != null ? [{ target_group_arn = local.traefik_tg_arn_80, container_name = "traefik", container_port = 80 }] : [],
    local.traefik_tg_arn_443 != null ? [{ target_group_arn = local.traefik_tg_arn_443, container_name = "traefik", container_port = 443 }] : [],
  )

  # ---------------------------------------------------------------------
  # OpenTelemetry collector
  # ---------------------------------------------------------------------

  otel_cfg = try(var.cluster_addons.opentelemetry, {})

  otel_cloudwatch_enabled = try(local.otel_cfg.exporters.aws_cloudwatch.enabled, true)
  otel_xray_enabled       = try(local.otel_cfg.exporters.aws_xray.enabled, false)
  otel_otlp_enabled       = try(local.otel_cfg.exporters.otlp.enabled, false)
  otel_discovery_enabled  = try(local.otel_cfg.discovery.enabled, false)

  otel_exporters  = try(local.otel_cfg.exporters, {})
  otel_cloudwatch = try(local.otel_exporters.aws_cloudwatch, {})
  otel_xray       = try(local.otel_exporters.aws_xray, {})
  otel_otlp       = try(local.otel_exporters.otlp, {})

  otel_config = coalesce(
    try(local.otel_cfg.config_override, null),
    yamlencode({
      receivers = merge(
        { otlp = { protocols = { grpc = { endpoint = "0.0.0.0:4317" }, http = { endpoint = "0.0.0.0:4318" } } } },
        local.otel_discovery_enabled ? { ec2scraper = { region = data.aws_region.current.region } } : {},
      )
      processors = { batch = {} }
      exporters = merge(
        local.otel_cloudwatch_enabled ? {
          "otlp/awscloudwatch" = {
            region        = data.aws_region.current.region
            loggroup_name = "/aws/ecs/${var.cluster_name}/addons/opentelemetry"
            namespace     = coalesce(try(local.otel_cloudwatch.namespace, null), "${var.cluster_name}")
          }
        } : {},
        local.otel_xray_enabled ? { "otlp/awsxray" = { region = data.aws_region.current.region } } : {},
        local.otel_otlp_enabled ? {
          otlp = {
            endpoint = local.otel_otlp.endpoint
            tls      = { insecure = try(local.otel_otlp.insecure, false) }
          }
        } : {},
      )
      service = { pipelines = {
        traces  = { receivers = ["otlp"], processors = ["batch"], exporters = compact(["otlp/awsxray", local.otel_otlp_enabled ? "otlp" : null]) }
        metrics = { receivers = compact(["otlp", local.otel_discovery_enabled ? "ec2scraper" : null]), processors = ["batch"], exporters = compact(["otlp/awscloudwatch", local.otel_otlp_enabled ? "otlp" : null]) }
      } }
    }),
  )

  otel_container = {
    name             = "opentelemetry-collector"
    image            = local.addon_image.opentelemetry
    essential        = true
    entryPoint       = ["/bin/sh", "-c"]
    command          = ["printf '%s' \"$OTEL_CONFIG\" > /tmp/otel.yaml && exec /otelcol-contrib --config /tmp/otel.yaml"]
    environment      = [for k, v in merge({ OTEL_CONFIG = local.otel_config }, coalesce(try(local.otel_cfg.environment, null), {})) : { name = k, value = v }]
    portMappings     = [{ containerPort = 4317, protocol = "tcp" }, { containerPort = 4318, protocol = "tcp" }]
    logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.opentelemetry }
  }

  # ---------------------------------------------------------------------
  # CloudWatch agent
  # ---------------------------------------------------------------------

  cwa_cfg = try(var.cluster_addons.cloudwatch_agent, {})

  cwa_config = coalesce(
    try(local.cwa_cfg.config, null),
    jsonencode({
      agent   = { region = data.aws_region.current.region }
      metrics = { metrics_collected = { cpu = {}, mem = {}, disk = {}, net = {} }, force_flush_interval = 15 }
    }),
  )

  cwa_container = {
    name             = "cloudwatch-agent"
    image            = local.addon_image.cloudwatch_agent
    essential        = true
    entryPoint       = ["/bin/sh", "-c"]
    command          = ["printf '%s' \"$CWA_CONFIG\" | /bin/cloudwatch-agent -configure -metric -noninteractive && exec /bin/cloudwatch-agent -daemon -c file:/tmp/cwa-config.json"]
    environment      = [for k, v in merge({ CWA_CONFIG = local.cwa_config }, coalesce(try(local.cwa_cfg.environment, null), {})) : { name = k, value = v }]
    portMappings     = [{ containerPort = 25888, protocol = "tcp" }]
    logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.cloudwatch_agent }
  }

  # ---------------------------------------------------------------------
  # Fluent Bit
  # ---------------------------------------------------------------------

  fb_cfg = try(var.cluster_addons.fluent_bit, {})

  fluentbit_config = coalesce(
    try(local.fb_cfg.config_override, null),
    try(local.fb_cfg.config, null),
    <<EOF
[SERVICE]
    Flush         5
    Daemon        off
    Log_Level     info

[INPUT]
    Name              tail
    Path              /var/log/containers/*.log
    Parser            docker
    Tag               ecs.*
    Mem_Buf_Limit     5MB
    Refresh_Interval  10

[FILTER]
    Name              kubernetes
    Match             ecs.*
    Merge_Log         On
    Keep_Log          Off

[OUTPUT]
    Name              cloudwatch
    Match             ecs.*
    Region            ${data.aws_region.current.region}
    Log_Group_Name    /aws/ecs/${var.cluster_name}/addons/fluent-bit
    Log_Stream_Name   {stream_name}
    Topic_Name        ecs
    Auto_Create_Group true
EOF
  )

  fluentbit_container = {
    name             = "fluent-bit"
    image            = local.addon_image.fluent_bit
    essential        = true
    entryPoint       = ["/bin/sh", "-c"]
    command          = ["printf '%s' \"$FLUENTBIT_CONFIG\" > /fluent-bit/etc/fluent-bit.conf && exec /fluent-bit/bin/fluent-bit -c /fluent-bit/etc/fluent-bit.conf"]
    environment      = [for k, v in merge({ FLUENTBIT_CONFIG = local.fluentbit_config }, coalesce(try(local.fb_cfg.environment, null), {})) : { name = k, value = v }]
    logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.fluent_bit }
  }

  # ---------------------------------------------------------------------
  # Node exporter / cAdvisor / Falco / Blackbox exporter
  # (EC2 daemon-style metrics & security agents)
  # ---------------------------------------------------------------------

  # Shared host-path mount points for EC2 daemon-style agents. Each container
  # gets the same set; volumesFrom is NOT used (it references other containers
  # in the task, not named volumes).
  host_mount_points = [
    { sourceVolume = "host-root", containerPath = "/host", readOnly = true },
    { sourceVolume = "host-var", containerPath = "/var", readOnly = true },
    { sourceVolume = "host-dev", containerPath = "/dev", readOnly = true },
    { sourceVolume = "host-proc", containerPath = "/proc", readOnly = true },
    { sourceVolume = "host-sys", containerPath = "/sys", readOnly = true },
  ]

  ne_cfg = try(var.cluster_addons.node_exporter, {})
  ne_container = {
    name             = "node-exporter"
    image            = local.addon_image.node_exporter
    essential        = true
    command          = concat(["--path.rootfs=/host"], coalesce(try(local.ne_cfg.extra_args, null), []))
    environment      = [for k, v in coalesce(try(local.ne_cfg.environment, null), {}) : { name = k, value = v }]
    portMappings     = [{ containerPort = try(local.ne_cfg.port, 9100), hostPort = try(local.ne_cfg.port, 9100), protocol = "tcp" }]
    logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.node_exporter }
    mountPoints      = local.host_mount_points
  }

  cadvisor_cfg = try(var.cluster_addons.cadvisor, {})
  cadvisor_container = {
    name             = "cadvisor"
    image            = local.addon_image.cadvisor
    essential        = true
    command          = concat(["--rootfs=/host"], coalesce(try(local.cadvisor_cfg.extra_args, null), []))
    environment      = [for k, v in coalesce(try(local.cadvisor_cfg.environment, null), {}) : { name = k, value = v }]
    portMappings     = [{ containerPort = try(local.cadvisor_cfg.port, 8080), hostPort = try(local.cadvisor_cfg.port, 8080), protocol = "tcp" }]
    logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.cadvisor }
    mountPoints      = local.host_mount_points
  }

  falco_cfg = try(var.cluster_addons.falco, {})
  falco_container = {
    name             = "falco"
    image            = local.addon_image.falco
    essential        = true
    command          = concat(["--driver", try(local.falco_cfg.driver_mode, "ebpf")], coalesce(try(local.falco_cfg.extra_args, null), []))
    environment      = [for k, v in coalesce(try(local.falco_cfg.environment, null), {}) : { name = k, value = v }]
    logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.falco }
    mountPoints      = local.host_mount_points
  }

  bb_cfg = try(var.cluster_addons.blackbox_exporter, {})
  blackbox_config = coalesce(
    try(local.bb_cfg.config_override, null),
    try(local.bb_cfg.config, null),
    yamlencode({
      modules = {
        http_2xx = {
          prober = "http"
          http   = { valid_status_codes = [200, 201, 204] }
        }
      }
    }),
  )
  blackbox_container = {
    name             = "blackbox-exporter"
    image            = local.addon_image.blackbox_exporter
    essential        = true
    entryPoint       = ["/bin/sh", "-c"]
    command          = ["printf '%s' \"$BLACKBOX_CONFIG\" > /tmp/blackbox.yml && exec /bin/blackbox_exporter --config.file=/tmp/blackbox.yml"]
    environment      = [for k, v in merge({ BLACKBOX_CONFIG = local.blackbox_config }, coalesce(try(local.bb_cfg.environment, null), {})) : { name = k, value = v }]
    portMappings     = [{ containerPort = try(local.bb_cfg.port, 9115), hostPort = try(local.bb_cfg.port, 9115), protocol = "tcp" }]
    logConfiguration = { logDriver = "awslogs", options = local.awslogs_options.blackbox_exporter }
  }

  # Host-path bind mounts shared by the EC2 daemon-style agents.
  host_mount_volumes = anytrue([
    local.addon_enabled.node_exporter,
    local.addon_enabled.cadvisor,
    local.addon_enabled.falco,
    ]) ? [
    { name = "host-root", host_path = "/" },
    { name = "host-var", host_path = "/var" },
    { name = "host-dev", host_path = "/dev" },
    { name = "host-proc", host_path = "/proc" },
    { name = "host-sys", host_path = "/sys" },
  ] : []
}
