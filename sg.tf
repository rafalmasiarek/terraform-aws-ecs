resource "aws_security_group" "this" {
  name        = "${var.name}-tasks"
  description = "ECS tasks/instances for cluster ${var.name}"
  vpc_id      = var.vpc_id

  tags = local.tagger_tags["this"]
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

# Dynamic host port mapping range used by the EC2 (bridge/host) launch type -
# irrelevant for Fargate (awsvpc gives every task its own ENI), harmless to
# leave open either way.
resource "aws_security_group_rule" "alb_ephemeral_ports" {
  count = var.alb_security_group_id != null ? 1 : 0

  type                     = "ingress"
  from_port                = 32768
  to_port                  = 61000
  protocol                 = "TCP"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.this.id
}

resource "aws_security_group_rule" "alb_health_check_port" {
  count = var.alb_security_group_id != null && var.tg_health_check_port != null && var.tg_health_check_port != "traffic-port" ? 1 : 0

  type                     = "ingress"
  from_port                = tonumber(var.tg_health_check_port)
  to_port                  = tonumber(var.tg_health_check_port)
  protocol                 = "TCP"
  description              = "ALB target-group health check"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.this.id
}
