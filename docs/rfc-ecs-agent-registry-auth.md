# RFC: ECS agent configuration passthrough and registry authentication

Consolidates #4 (ECS agent configuration extension) and #9 (node-group: complete ECS Agent configuration and composable IAM).

## 1. Scope

- `ecs_agent_config` per node group: generic ECS Agent / ECS-Init environment passthrough + `registry_auth`
- Composable, least-privilege IAM for instance, execution, and task roles
- #6 (cluster), #7 (service) and #8 (task) are implemented on the same
  branch per their issue bodies; this RFC covers only #4 + #9
- Out of scope: cluster add-ons (#10)

## 2. Inputs

Optional `ecs_agent_config` on each `node_groups` entry:

```hcl
ecs_agent_config = {
  # Generic passthrough for every ECS Container Agent / ECS-Init
  # environment variable, current and future. No allowlist.
  environment = {
    ECS_LOGGING                   = "awslogs"
    ECS_AVAILABLE_LOGGING_DRIVERS = jsonencode(["awslogs", "gelf", "splunk", "syslog", "json-file"])
    ECS_RESERVED_PORTS            = jsonencode([22])
    ECS_INSTANCE_ATTRIBUTES       = jsonencode({ env = "prod" })
  }

  # Custom registry authentication, see §4.
  registry_auth = {
    type = "dockercfg" # docker | dockercfg
    registries = {
      "docker.io" = {
        username = "ci-bot"
        password = {
          # exactly one of: plaintext / file / secretsmanager_secret_arn
          secretsmanager_secret_arn = "arn:aws:secretsmanager:eu-central-1:123:secret:reg"
          # kms_key_arn = "arn:aws:kms:..." # optional, SM source only
        }
        # email = "" # optional
      }
    }
  }
}
```

### Validation

| Rule | Where |
|---|---|
| Keys match `^[A-Z][A-Z0-9_]*$` | `environment` |
| Values are strings; JSON-valued settings are passed as JSON strings | `environment` |
| Reserved keys rejected: `ECS_CLUSTER`, `ECS_ENGINE_AUTH_TYPE`, `ECS_ENGINE_AUTH_DATA` | `environment` |
| No newlines or carriage returns in `environment` values (line-based file format) | `environment` |
| `type` is `docker` or `dockercfg` | `registry_auth` |
| At least one registry entry | `registry_auth` |
| Exactly one of `password.plaintext` / `password.file` / `password.secretsmanager_secret_arn` per registry | `registry_auth` |
| `password.kms_key_arn` only with the `secretsmanager_secret_arn` source | `registry_auth` |

## 3. Rendering

The node group's user-data appends to `/etc/ecs/ecs.config` deterministically:
`ECS_CLUSTER` first, then module defaults merged into `environment`
(`environment` wins) sorted by key, then the two auth lines:

```
ECS_CLUSTER=<cluster>                     # module-owned, always first
<every environment entry (incl. overridable module defaults), sorted by key>
ECS_ENGINE_AUTH_TYPE=<type>               # only when registry_auth is set
ECS_ENGINE_AUTH_DATA=<json>               # only when registry_auth is set
```

- `ECS_CLUSTER` is never overridable.
- Every line is written with `printf '%s\n' '<single-quoted, escaped>'` -
  no shell interpolation of values, no injection vector.
- After the config is fully written (including boot-time secrets, §5), the
  agent is started by a first-boot systemd unit - the native
  terraform-null-cloudinit `systemd_units` mechanism. The module writes
  `terraform-ecs-agent-start.service` (oneshot, not enabled) with
  `After=cloud-final.service docker.service` and
  `ExecStart=systemctl enable --now ecs`. The unit only enables/starts the
  packaged `ecs` unit (AL2/AL2023) - it never writes to it or its drop-ins,
  so unit configuration a user may have written is never overridden. The
  enable part persists across reboots, which covers custom AMIs whose agent
  unit is not pre-enabled. The start is blocking on purpose: the unit runs
  after cloud-final, so the ecs start job cannot cycle back into it, and the
  unit's result reflects the agent's actual start outcome (a failed start
  fails the unit instead of vanishing into the ecs service state).
- The unit is queued from runcmd (once per instance, Final stage) with
  `systemctl start terraform-ecs-agent-start --no-block`. The `--no-block`
  is the deadlock guard: the unit is ordered `After=cloud-final.service`,
  which is the very unit running runcmd, so a blocking start would wait for
  cloud-final, which waits for runcmd. With `--no-block` the job is queued,
  cloud-final completes, and systemd runs the unit, which starts the agent
  with the fresh config.
- The unit is deliberately not enabled: runcmd runs once per instance, so
  the start happens exactly once, on first boot. Reboots go through the
  packaged `ecs` unit alone - no second start, no config rewrite (the
  config script is a once-per-instance `shell_scripts` part).
- All three additions are appended after any user-supplied entries of the
  same kind (`shell_scripts`, `systemd_units`, `commands`): separate
  cloud-init parts, user parts run first and are never modified, and the
  script only appends module-owned lines to `/etc/ecs/ecs.config`, so
  neither side overwrites the other.

## 4. registry_auth

`ECS_ENGINE_AUTH_DATA` is a JSON object keyed by registry address in both
types - no `auths` wrapper (the ECS agent only accepts the unwrapped
format). Multiple registries per type. The only difference is the per-registry
credential encoding:

```
type = "docker":
ECS_ENGINE_AUTH_DATA={"<registry>": {"username": ..., "password": ..., "email": ...}, ...}

type = "dockercfg":
ECS_ENGINE_AUTH_DATA={"<registry>": {"auth": base64("<username>:<password>"), "email": ...}, ...}
```

- `email` is optional; omitted from the JSON when empty.
- For `dockercfg`, `auth` is base64 of `username:password` - computed with
  `base64encode()` at render time for plaintext, jq `@base64` at boot for
  file/Secrets Manager sources.
- ECS agent feature, EC2 capacity only (Fargate uses task-level
  `repositoryCredentials` instead). AWS does not recommend credentials in
  user data at all - the plaintext path is an explicit opt-in
  compatibility path for that reason.

Per-registry password source (`password` object, mutually exclusive):

| Source | Secret in state | Secret in user-data |
|---|---|---|
| `password.plaintext` (explicit opt-in) | yes | yes |
| `password.file` (file written by an external secret agent) | no | path only |
| `password.secretsmanager_secret_arn` | no | ARN only |

`password.kms_key_arn` (optional, SM source only): when the module creates
the instance role, adds `kms:Decrypt` on that key. Required when the secret
is encrypted with a customer-managed KMS key.

## 5. Boot ordering (non-plaintext sources)

- `password.file`: user-data polls the path (bounded retries) until the
  file exists, then reads it. A user-managed secret agent must write the
  file before the ECS agent start (§3) - within the retry budget.
- `password.secretsmanager_secret_arn`: user-data calls
  `aws secretsmanager get-secret-value` with the instance role, then reads
  the payload.

Retry budget: `ECS_REGISTRY_AUTH_WAIT_RETRIES` (default 30) x
`ECS_REGISTRY_AUTH_WAIT_INTERVAL` (default 5s) - overridable per instance
through the environment. A file that never appears fails user-data with a
non-zero exit.

The boot script assembles `ECS_ENGINE_AUTH_DATA` with `jq`, appends the
auth lines to `/etc/ecs/ecs.config`; the first-boot unit then starts the
ECS agent (§3). Secrets never enter the launch template, Terraform state,
or cloud-init logs - only the path or ARN does.

`awscli-2` and `jq` are preinstalled on the AL2023 ECS-optimized AMIs;
custom AMIs must provide them.

## 6. IAM

Optional `iam` on each node group / service entry - create-or-use:

```hcl
iam = {
  # Use an existing profile/role, OR
  use_existing = { instance_profile_name = "existing-profile" }

  # Create with extension points:
  create = {
    name                    = "optional"
    permission_boundary_arn = "arn:..."
    managed_policy_arns     = ["arn:..."]
    inline_policies         = { name = [{ sid, effect, actions, resources }] }
    least_privilege = {
      secretsmanager_secret_arns = ["arn:..."]
      kms_key_arns               = ["arn:..."]
      ssm_parameter_arns         = ["arn:..."]
      ecr_registry_arns          = ["arn:..."]
      route53_zone_arns          = ["arn:..."]
    }
  }
}
```

- Omitted `iam` keeps today's behavior: root's shared instance role/profile
  (`create_instance_iam_role`), root's shared task execution role
  (`create_task_execution_role`), no task role creation.
- Created roles keep the base managed policies
  (`AmazonEC2ContainerServiceforEC2Role` / `AmazonSSMManagedInstanceCore` /
  `AmazonECSTaskExecutionRolePolicy`) plus the extension points above.
- A node group with `registry_auth` on the Secrets Manager source
  auto-wires `secretsmanager:GetSecretValue` on the secret ARN (+
  `kms:Decrypt` on the wrapping key when given).
- No cluster-wide task role as the only model - per-service roles supported.

## 7. Migration

- Omitted `ecs_agent_config` / `iam` = today's behavior unchanged
  (the three hardcoded agent lines, shared instance role).
- `ECS_CLUSTER` or the auth keys in `environment` = validation error.
- `ECS_ENABLE_CONTAINER_METADATA` / `ECS_ENABLE_SPOT_INSTANCE_DRAINING` in
  `environment` override the module defaults.

## 8. Implementation plan

Single branch (per project decision), in phases:

| Phase | Content |
|---|---|
| 1 | This spec |
| 2 | User-data renderer + validation (passthrough, reserved keys, all auth sources) |
| 3 | Boot script (file/SM resolution) + instance-role composable IAM |
| 4 | Local validation/rendering/boot-script tests |

## 9. Tests (local only)

- Validation: reserved keys, invalid key shape, newline in value, zero
  registries, two password sources set, no source set, `kms_key_arn` with a
  non-SM source.
- Rendering: sorted lines, defaults overridable, `ECS_CLUSTER` first,
  start unit present (right name, oneshot, no [Install]), runcmd queues it
  non-blocking after `daemon-reload`, shell quoting round-trip (quotes, `$`,
  backticks in values), both auth types.
- Boot script (mocked `aws` CLI): file source resolved, SM source resolved,
  missing file fails after the retry budget, assembled JSON matches the
  expected shape, no systemctl invocation in the script.
- Live (eu-central-1, full QA stack): clean first boot - cloud-init done,
  agent active, container instance registered; boot-script fixes found live
  (blocking restart deadlock, KMS key policy, mixed password sources) are
  covered by the mechanisms above.
- IAM: create vs use-existing, boundary applied, SM least-privilege
  scoping.
