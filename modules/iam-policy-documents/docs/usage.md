## Usage

```hcl
module "exec_policy" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git//modules/iam-policy-documents?ref=v0.6.0"

  least_privilege = {
    ecr_registry_arns  = [aws_ecr_repository.this.arn]
    ssm_parameter_arns = [aws_ssm_parameter.app_config.arn]
  }
}

resource "aws_iam_role_policy" "exec" {
  role   = aws_iam_role.task_execution.id
  policy = module.exec_policy.json
}
```

This module is normally not called directly - the root
[terraform-aws-ecs](../../) module wires it into the task execution
role's inline policy itself.
