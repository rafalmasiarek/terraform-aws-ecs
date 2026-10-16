# SSM-delivered configs: secrets in container_definitions are referenced by
# ARN, and a file-provider document (traefik routes) is materialized at task
# start from an environment secret.

resource "aws_ssm_parameter" "traefik_routes" {
  count = local.addon_enabled.traefik && local.traefik_routes_count > 0 ? 1 : 0

  name  = "/ecs/${var.cluster_name}/addon-traefik-routes"
  type  = "SecureString"
  value = local.traefik_routes_yaml
  tier  = "Standard"

  tags = merge(var.tags, coalesce(try(local.traefik_cfg.tags, null), {}))
}
