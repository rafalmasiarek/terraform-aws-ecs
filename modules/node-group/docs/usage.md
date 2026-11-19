## Usage

Not called directly - configured via the root [terraform-aws-ecs](../../)
module's `node_groups` variable:

```hcl
module "ecs" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git?ref=v0.6.0"

  name   = "demo"
  vpc_id = var.vpc_id

  node_groups = {
    nodes = {
      instance_type               = "m5.large"
      subnet_ids                  = var.subnet_ids
      min_size                    = 1
      max_size                    = 2
      desired_capacity            = 1
      associate_public_ip_address = true
    }
  }
}
```
