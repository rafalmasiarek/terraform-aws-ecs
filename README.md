# Terraform AWS ECS

ECS cluster module: cluster, capacity providers, EC2 node groups, services, composable IAM, cluster security group.

## Requirements

| Provider | Version |
|---|---|
| hashicorp/aws | >= 6.0 |
| rafalmasiarek/tagger (module) | >= 0.5.0 |

## Inputs (key variables)

| Variable | Description |
|---|---|
| `name` | Cluster name prefix. |
| `vpc_id` | VPC to create the cluster in. |
| `node_groups` | Map of EC2 node group configs (ASG + launch template). See `modules/node-group/`. |
| `fargate_capacity_providers` | List of Fargate capacity provider names to register. |
| `services` | Map of ECS service configs. See `modules/service/`. |
| `task_sg_ingress_rules` / `task_sg_egress_rules` | Custom rules on the cluster security group. |
| `create_ecs_infrastructure_role` | Create a dedicated IAM role for the cluster. |
| `create_task_execution_role` | Create a shared task execution role. |
| `exec_command_s3` | Enable ECS Exec session logging to S3. |
| `use_tagger` | Enable standardized tagging via terraform-null-tagger (default true). |
| `tagger_context` | Shared context from the root stack's base tagger call. |

## Outputs

| Output | Description |
|---|---|
| `cluster_id` / `cluster_arn` | Cluster identity. |
| `cloudwatch_log_group_name` | ECS Exec CloudWatch log group, when enabled. |
| `exec_s3_bucket_name` / `exec_s3_bucket_arn` | ECS Exec S3 logging bucket, when enabled. |
| `exec_kms_key_id` | KMS key used for ECS Exec logging. |
| `ecs_infrastructure_role_arn` | Cluster IAM role ARN. |

## Tagger integration

Resources are tagged via terraform-null-tagger when `use_tagger = true`. Each sub-module (`node-group`, `service`, `iam-role`) copies the same `tagger.tf` wiring and computes its own tags from the shared `tagger_context`.
