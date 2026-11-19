## Usage

Not called directly - configured via the root [terraform-aws-ecs](../../)
module's `services` variable (one entry per service, `container_definitions`
typically built with [modules/container-definition](../container-definition)):

```hcl
module "ecs" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git?ref=v0.6.0"

  name   = "demo"
  vpc_id = var.vpc_id

  services = {
    app = {
      container_definitions = [module.app_container.container_definition]
      desired_count          = 2
    }
  }
}
```
