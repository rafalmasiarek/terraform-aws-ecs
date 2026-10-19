variable "cluster_id" {
  description = "ECS cluster identifier (short name or full ARN)."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster short name (used for resource naming)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID. Required when any preset creates a load balancer or needs VPC-scoped SG rules."
  type        = string
  default     = null
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Retention for every addon task's CloudWatch log group."
  type        = number
  default     = 30
}

variable "cluster_security_group_id" {
  description = "Cluster security group ID. Task ENIs (awsvpc) and node host ports (bridge) join this SG."
  type        = string
  default     = null
}

variable "default_execution_role_arn" {
  description = "The cluster's default task execution role ARN, used when a preset doesn't need its own execution role."
  type        = string
  default     = null
}

variable "infrastructure_role_arn" {
  description = "ARN of the ECS infrastructure role for EBS task volume management. Required when any addon uses configure_at_launch volumes."
  type        = string
  default     = null
}

variable "cluster_addons" {
  description = "ECS cluster infrastructure add-ons: traefik, opentelemetry, cloudwatch_agent, node_exporter, cadvisor, falco, blackbox_exporter. See docs/addons.md for per-preset semantics."
  type        = any
  default     = null

  # `any` on purpose: Terraform taints a typed object variable to unknown as
  # soon as any nested value is computed (a subnet id, an ARN referenced from
  # another resource), which would make every count-gated resource
  # un-planable. With `any`, known parts stay known; every optional field is
  # materialized with its default through try() in main.tf.
  #
  # Unknown top-level keys are rejected by the root module's validation on
  # this variable (a typed conversion would drop them silently). Unknown
  # per-preset attributes fail the plan at the first HCL attribute access.
  #
  # Reference schema (the documented shape):
  # type = object({
  # traefik = optional(object({
  # enabled       = optional(bool, true)
  # image         = optional(string)
  # task_cpu      = optional(number, 512)
  # task_memory   = optional(number, 256)
  # # Deployment model: an EC2 launch type (or EC2 capacity) defaults to a
  # # DAEMON bridge service - one proxy per node, host ports 80/443, no
  # # task ENI. Fargate stays a replicated awsvpc service; an explicit
  # # scheduling_strategy = "REPLICA" forces replicas on EC2 too.
  # launch_type   = optional(string, "FARGATE")
  # scheduling_strategy = optional(string, "DAEMON")
  # desired_count = optional(number, 2)            # REPLICA only
  # # Set true once when migrating an existing service between deployment
  # # models (REPLICA -> DAEMON or back); the provider requires it for
  # # capacity_provider_strategy updates. No-op on creation/no-op applies.
  # force_new_deployment = optional(bool, false)
  # capacity_provider_strategy = optional(list(object({
  # capacity_provider = string
  # weight            = optional(number, 1)
  # base              = optional(number)
  # })), [])
  # # awsvpc tasks: defaults to every available subnet of the VPC.
  # subnets          = optional(list(string), [])
  # security_groups  = optional(list(string), [])
  # assign_public_ip = optional(bool)  # default: true only if subnets have no NAT egress
  # # Declarative routes (EKS-Ingress analog): each entry becomes a
  # # traefik router. `service` must be "service-<ecs-service-name>-<container-name>"
  # # (the ECS provider's actual naming convention) - no load_balancer arg
  # # needed on that ECS service; label routing.
  # routes = optional(list(object({
  # name        = string
  # rule        = string
  # service     = string
  # entrypoints = optional(list(string), ["web"])
  # })), [])
  # environment     = optional(map(string), {})
  # docker_labels   = optional(map(string), {})
  # command         = optional(list(string))
  # extra_args      = optional(list(string), [])
  # extra_task_policies = optional(object({
  # managed_policy_arns = optional(list(string), [])
  # inline_policies = optional(map(list(object({
  # sid       = optional(string)
  # effect    = string
  # actions   = list(string)
  # resources = list(string)
  # }))), {})
  # }), {})
  # # Ingress. Create mode is the default - an omitted or empty ingress
  # # block still creates the load balancer. Existing mode
  # # (create_load_balancer = false) only registers the service on your
  # # target group - the LB, its listeners and the SG rules reaching the
  # # tasks are yours.
  # ingress = optional(object({
  # create_load_balancer = optional(bool, true)
  # # existing mode: your target group (required).
  # target_group_arn = optional(string)
  # # existing mode + 443 entrypoint: separate TG for 443 (ECS rejects dupes).
  # target_group_arn_443 = optional(string)
  # # create mode: "alb" (default, L7) or "nlb" (L4 TCP passthrough - an
  # # NLB cannot terminate TLS; use tls.managed_by = "traefik").
  # load_balancer_type = optional(string, "alb")
  # # create mode: internal (default, VPC-only traffic) or internet-facing.
  # internal = optional(bool, true)
  # # ALB create mode: terminate TLS on the LB (443 listener), requires
  # # certificate_arn. Existing mode: expose the container's 443
  # # entrypoint so your own TLS listener has a backend.
  # tls_enabled     = optional(bool, false)
  # certificate_arn = optional(string)
  # subnets         = optional(list(string), [])
  # security_groups = optional(list(string), [])
  # }))
  # # TLS management: "lb" (default, ALB terminates), "traefik" (ACME),
  # # or "manual" (user-provided certs in a directory).
  # tls = optional(object({
  # managed_by = optional(string, "lb")
  # # ACME (managed_by = "traefik"): Let's Encrypt with DNS-01 challenge.
  # acme = optional(object({
  # email        = string
  # dns_provider = optional(string, "route53")  # any traefik DNS provider
  # # Persistent certificate store (optional; default: task-ephemeral /data).
  # # Exactly one of filesystem_id/volume_id/arn per type.
  # storage = optional(object({
  # type          = string  # "efs" or "ebs"
  # filesystem_id = optional(string)  # EFS: "fs-..."
  # volume_id     = optional(string)  # EBS: "vol-..."
  # arn           = optional(string)  # full ARN (alternative to id)
  # }))
  # }))
  # # Manual TLS (managed_by = "manual"): user-provided certificates.
  # # Traefik serves *.crt/*.key pairs from this directory (SNI-based).
  # certificates_directory = optional(string, "/etc/traefik/certs")
  # # Volume mounted at certificates_directory (optional; omit if certs are
  # # baked into the image). Same shape as acme.storage.
  # storage = optional(object({
  # type          = string  # "efs" or "ebs"
  # filesystem_id = optional(string)
  # volume_id     = optional(string)
  # arn           = optional(string)
  # }))
  # }))
  # provider = optional(object({
  # exposed_by_default = optional(bool, false)
  # }))
  # tags = optional(map(string), {})
  # }))
  #
  # opentelemetry = optional(object({
  # enabled             = optional(bool, true)
  # image               = optional(string)
  # task_cpu            = optional(number, 512)
  # task_memory         = optional(number, 1024)
  # desired_count       = optional(number, 1)
  # scheduling_strategy = optional(string, "REPLICA")
  # launch_type         = optional(string, "FARGATE")
  # capacity_provider_strategy = optional(list(object({
  # capacity_provider = string
  # weight            = optional(number, 1)
  # base              = optional(number)
  # })), [])
  # subnets          = optional(list(string), [])
  # security_groups  = optional(list(string), [])
  # assign_public_ip = optional(bool)  # default: true only if subnets have no NAT egress
  # environment      = optional(map(string), {})
  # docker_labels    = optional(map(string), {})
  # command          = optional(list(string))
  # extra_args       = optional(list(string), [])
  # config_override  = optional(string)
  # exporters = optional(object({
  # aws_cloudwatch = optional(object({
  # enabled   = optional(bool, true)
  # namespace = optional(string)
  # }))
  # aws_xray = optional(object({
  # enabled = optional(bool, false)
  # }))
  # otlp = optional(object({
  # enabled  = optional(bool, false)
  # endpoint = optional(string)
  # insecure = optional(bool, false)
  # }))
  # }))
  # discovery = optional(object({
  # enabled = optional(bool, false)
  # }))
  # extra_task_policies = optional(object({
  # managed_policy_arns = optional(list(string), [])
  # inline_policies = optional(map(list(object({
  # sid       = optional(string)
  # effect    = string
  # actions   = list(string)
  # resources = list(string)
  # }))), {})
  # }), {})
  # tags = optional(map(string), {})
  # }))
  #
  # cloudwatch_agent = optional(object({
  # enabled          = optional(bool, true)
  # image            = optional(string)
  # task_cpu         = optional(number, 256)
  # task_memory      = optional(number, 512)
  # config           = optional(string)  # agent JSON; null = USE_DEFAULT_CONFIG
  # assign_public_ip = optional(bool)  # default: true only if subnets have no NAT egress
  # environment      = optional(map(string), {})
  # docker_labels    = optional(map(string), {})
  # command          = optional(list(string))
  # extra_args       = optional(list(string), [])
  # extra_task_policies = optional(object({
  # managed_policy_arns = optional(list(string), [])
  # inline_policies = optional(map(list(object({
  # sid       = optional(string)
  # effect    = string
  # actions   = list(string)
  # resources = list(string)
  # }))), {})
  # }), {})
  # tags = optional(map(string), {})
  # }))
  #
  # node_exporter = optional(object({
  # enabled       = optional(bool, true)
  # image         = optional(string)
  # task_cpu      = optional(number, 128)
  # task_memory   = optional(number, 128)
  # port          = optional(number, 9100)
  # environment   = optional(map(string), {})
  # docker_labels = optional(map(string), {})
  # command       = optional(list(string))
  # extra_args    = optional(list(string), [])
  # extra_task_policies = optional(object({
  # managed_policy_arns = optional(list(string), [])
  # inline_policies = optional(map(list(object({
  # sid       = optional(string)
  # effect    = string
  # actions   = list(string)
  # resources = list(string)
  # }))), {})
  # }), {})
  # tags = optional(map(string), {})
  # }))
  #
  # cadvisor = optional(object({
  # enabled       = optional(bool, true)
  # image         = optional(string)
  # task_cpu      = optional(number, 128)
  # task_memory   = optional(number, 128)
  # port          = optional(number, 8080)
  # environment   = optional(map(string), {})
  # docker_labels = optional(map(string), {})
  # command       = optional(list(string))
  # extra_args    = optional(list(string), [])
  # extra_task_policies = optional(object({
  # managed_policy_arns = optional(list(string), [])
  # inline_policies = optional(map(list(object({
  # sid       = optional(string)
  # effect    = string
  # actions   = list(string)
  # resources = list(string)
  # }))), {})
  # }), {})
  # tags = optional(map(string), {})
  # }))
  #
  # falco = optional(object({
  # enabled       = optional(bool, true)
  # image         = optional(string)
  # task_cpu      = optional(number, 512)
  # task_memory   = optional(number, 512)
  # driver_mode   = optional(string, "ebpf")  # "ebpf" or "kmod"
  # environment   = optional(map(string), {})
  # docker_labels = optional(map(string), {})
  # command       = optional(list(string))
  # extra_args    = optional(list(string), [])
  # extra_task_policies = optional(object({
  # managed_policy_arns = optional(list(string), [])
  # inline_policies = optional(map(list(object({
  # sid       = optional(string)
  # effect    = string
  # actions   = list(string)
  # resources = list(string)
  # }))), {})
  # }), {})
  # tags = optional(map(string), {})
  # }))
  #
  # blackbox_exporter = optional(object({
  # enabled          = optional(bool, true)
  # image            = optional(string)
  # task_cpu         = optional(number, 256)
  # task_memory      = optional(number, 512)
  # port             = optional(number, 9115)
  # config           = optional(string)  # blackbox YAML; null = generated
  # config_override  = optional(string)
  # assign_public_ip = optional(bool)  # default: true only if subnets have no NAT egress
  # environment      = optional(map(string), {})
  # docker_labels    = optional(map(string), {})
  # command          = optional(list(string))
  # extra_args       = optional(list(string), [])
  # extra_task_policies = optional(object({
  # managed_policy_arns = optional(list(string), [])
  # inline_policies = optional(map(list(object({
  # sid       = optional(string)
  # effect    = string
  # actions   = list(string)
  # resources = list(string)
  # }))), {})
  # }), {})
  # tags = optional(map(string), {})
  # }))
  # })

  # traefik ingress: create mode (the default - an omitted or empty ingress
  # block) builds the LB; subnets default to the VPC, certificate_arn is
  # required when tls_enabled, and an NLB is a TCP passthrough (no
  # LB-terminated TLS). Existing mode (create_load_balancer = false) wires
  # the service to your target group.
  validation {
    condition = var.cluster_addons == null ? true : (
      try(var.cluster_addons.traefik, null) == null || try(var.cluster_addons.traefik.ingress, null) == null ? true : (
        try(var.cluster_addons.traefik.ingress.create_load_balancer, true)
        ? (
          try(var.cluster_addons.traefik.ingress.target_group_arn, null) == null
          && (
            try(var.cluster_addons.traefik.ingress.load_balancer_type, "alb") != "nlb"
            || !try(var.cluster_addons.traefik.ingress.tls_enabled, false)
          )
          && (!try(var.cluster_addons.traefik.ingress.tls_enabled, false) || try(var.cluster_addons.traefik.ingress.certificate_arn, null) != null)
        )
        : (
          try(var.cluster_addons.traefik.ingress.certificate_arn, null) == null
          && try(var.cluster_addons.traefik.ingress.target_group_arn, null) != null
        )
      )
    )
    error_message = "traefik.ingress: create mode (default - an omitted or empty ingress block) builds the load balancer; subnets default to every available subnet of the VPC, certificate_arn is required when tls_enabled (ALB only - an NLB is a TCP passthrough, use tls.managed_by = \"traefik\" for HTTPS). existing mode (create_load_balancer = false) only wires the service to your target_group_arn - set tls_enabled to expose the container's 443 entrypoint to your TLS listener."
  }

  # traefik tls: ACME (managed_by = "traefik") needs a contact email.
  validation {
    condition = var.cluster_addons == null ? true : (
      try(var.cluster_addons.traefik, null) == null || try(var.cluster_addons.traefik.tls, null) == null ? true : (
        try(var.cluster_addons.traefik.tls.managed_by, "lb") != "traefik"
        || try(var.cluster_addons.traefik.tls.acme, null) == null
        || length(try(var.cluster_addons.traefik.tls.acme.email, "")) > 0
      )
    )
    error_message = "traefik.tls.acme: email is required when managed_by = \"traefik\" (ACME / Let's Encrypt)."
  }

  # traefik tls storage (acme.storage or manual tls.storage): when set,
  # exactly one of filesystem_id/volume_id/arn matching type.
  validation {
    condition = var.cluster_addons == null ? true : alltrue(flatten([
      for k, v in var.cluster_addons : k != "traefik" || v == null || try(v.tls, null) == null ? [true] : flatten([
        try(v.tls.acme, null) == null || try(v.tls.acme.storage, null) == null ? [true] : [
          (
            (try(v.tls.acme.storage.filesystem_id, null) != null ? 1 : 0)
            + (try(v.tls.acme.storage.volume_id, null) != null ? 1 : 0)
            + (try(v.tls.acme.storage.arn, null) != null ? 1 : 0)
          ) == 1
          && (
            (try(v.tls.acme.storage.type, "") == "efs"
            && (try(v.tls.acme.storage.filesystem_id, null) != null || try(v.tls.acme.storage.arn, null) != null))
            || (try(v.tls.acme.storage.type, "") == "ebs"
            && (try(v.tls.acme.storage.volume_id, null) != null || try(v.tls.acme.storage.arn, null) != null))
          )
        ],
        try(v.tls.storage, null) == null ? [true] : [
          (
            (try(v.tls.storage.filesystem_id, null) != null ? 1 : 0)
            + (try(v.tls.storage.volume_id, null) != null ? 1 : 0)
            + (try(v.tls.storage.arn, null) != null ? 1 : 0)
          ) == 1
          && (
            (try(v.tls.storage.type, "") == "efs"
            && (try(v.tls.storage.filesystem_id, null) != null || try(v.tls.storage.arn, null) != null))
            || (try(v.tls.storage.type, "") == "ebs"
            && (try(v.tls.storage.volume_id, null) != null || try(v.tls.storage.arn, null) != null))
          )
        ],
      ])
    ]))
    error_message = "traefik.tls storage (acme.storage or tls.storage): set exactly one of filesystem_id (type=efs), volume_id (type=ebs), or arn; type must match the identifier."
  }

  # traefik routes: every entry needs a name, rule and the ECS service it
  # routes to; entrypoints, when given, must be non-empty.
  validation {
    condition = var.cluster_addons == null ? true : (
      try(var.cluster_addons.traefik, null) == null ? true : alltrue([
        for r in coalesce(try(var.cluster_addons.traefik.routes, null), []) :
        try(r.name, null) != null && try(r.rule, null) != null && try(r.service, null) != null
        && (try(r.entrypoints, null) == null || length(r.entrypoints) > 0)
      ])
    )
    error_message = "traefik.routes: every entry needs a name, a rule and the ECS service name it routes to; entrypoints must be a non-empty list when given."
  }

  # traefik existing mode with a 443 entrypoint (tls_enabled or ACME/manual)
  # needs a separate target group for 443 - ECS rejects duplicate TGs.
  validation {
    condition = var.cluster_addons == null ? true : (
      try(var.cluster_addons.traefik, null) == null || try(var.cluster_addons.traefik.ingress, null) == null || try(var.cluster_addons.traefik.ingress.create_load_balancer, true) ? true : (
        !try(var.cluster_addons.traefik.ingress.tls_enabled, false)
        && try(var.cluster_addons.traefik.tls.managed_by, "lb") == "lb"
        || try(var.cluster_addons.traefik.ingress.target_group_arn_443, null) != null
      )
    )
    error_message = "traefik.ingress (existing mode): when tls_enabled or tls.managed_by is not \"lb\" (exposes a 443 entrypoint), set ingress.target_group_arn_443 to a separate target group (ECS rejects duplicate TGs)."
  }

  # An OTLP exporter without an endpoint would generate a broken collector
  # config - fail at plan time instead.
  validation {
    condition = var.cluster_addons == null ? true : (
      try(var.cluster_addons.opentelemetry, null) == null || try(var.cluster_addons.opentelemetry.exporters, null) == null || try(var.cluster_addons.opentelemetry.exporters.otlp, null) == null ? true : (
        !try(var.cluster_addons.opentelemetry.exporters.otlp.enabled, true) || var.cluster_addons.opentelemetry.exporters.otlp.endpoint != null
      )
    )
    error_message = "opentelemetry.exporters.otlp: endpoint is required when enabled = true."
  }

  # Falco driver_mode must be ebpf or kmod.
  validation {
    condition = var.cluster_addons == null ? true : (
      try(var.cluster_addons.falco, null) == null || contains(["ebpf", "kmod"], try(var.cluster_addons.falco.driver_mode, "ebpf"))
    )
    error_message = "falco.driver_mode: must be \"ebpf\" or \"kmod\"."
  }

}

# Caller-computed plan facts (known booleans/lengths derived from the raw
# cluster_addons value at the root, where it is still fully known). A value
# that crosses a module boundary containing a computed value becomes fully
# unknown in the child, so counts/for_each gates must arrive pre-computed.
variable "plan_facts" {
  description = "Caller-computed plan-critical facts (see root addons.tf)."
  type        = any
  default     = {}
}



