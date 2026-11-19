## Usage

Not called directly - configured via the root [terraform-aws-ecs](../../)
module's `cluster_addons` variable:

```hcl
module "ecs" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git?ref=v0.6.0"

  name   = "demo"
  vpc_id = var.vpc_id

  cluster_addons = {
    traefik       = {}
    observability = {}
  }
}
```

See `docs/addons.md` in the root module for the full set of presets and
their options.
