## Usage

```hcl
module "app_container" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git//modules/container-definition?ref=v0.6.0"

  container_name = "app"
  image          = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/app:latest"
  memory         = 512

  port_mappings = [
    { container_port = 8080 }
  ]
}

module "ecs" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git?ref=v0.6.0"
  # ...

  services = {
    app = {
      container_definitions = [module.app_container.container_definition]
      # ...
    }
  }
}
```
