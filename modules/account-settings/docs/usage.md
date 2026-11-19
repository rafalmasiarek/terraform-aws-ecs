## Usage

```hcl
module "account_settings" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git//modules/account-settings?ref=v0.6.0"

  settings = {
    containerInsights   = "enhanced"
    defaultLogDriverMode = "blocking"
  }
}
```

Account-wide and per-Region - this is a real, shared opt-in, not scoped
to one cluster. Normally called once via the root
[terraform-aws-ecs](../../) module's `account_settings` variable.
