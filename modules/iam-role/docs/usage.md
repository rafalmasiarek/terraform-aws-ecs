## Usage

```hcl
module "task_execution_role" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-ecs.git//modules/iam-role?ref=v0.6.0"

  name                        = "demo-task-execution"
  assume_role_policy_document = data.aws_iam_policy_document.ecs_tasks_assume_role.json
  managed_policy_arns         = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]

  least_privilege = {
    ecr_registry_arns = [aws_ecr_repository.this.arn]
  }
}
```
