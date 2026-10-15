variable "settings" {
  description = "ECS account default settings (name => value). Account-wide and per-Region - this is an explicit opt-in. Writable names: containerInsights, awsvpcTrunking, defaultLogDriverMode, dualStackIPv6, fargateFIPSMode, fargateTaskRetirementWaitPeriod, fargateEventWindows. Excluded as immutable or AWS-managed: serviceLongArnFormat / taskLongArnFormat / containerInstanceLongArnFormat (long-ARN opt-out closed 2021-04-01), tagResourceAuthorization (no longer disableable since 2024-03-07), guardDutyActivate (read-only, controlled by GuardDuty)."
  type        = map(string)
  default     = {}

  validation {
    condition = can(element([for _ in [1] : 1 if alltrue([
      for n in keys(var.settings) : contains([
        "containerInsights", "awsvpcTrunking", "defaultLogDriverMode",
        "dualStackIPv6", "fargateFIPSMode", "fargateTaskRetirementWaitPeriod", "fargateEventWindows",
      ], n)
    ])], 0))
    error_message = "settings may only contain: containerInsights, awsvpcTrunking, defaultLogDriverMode, dualStackIPv6, fargateFIPSMode, fargateTaskRetirementWaitPeriod, fargateEventWindows."
  }

  validation {
    condition = can(element([for _ in [1] : 1 if alltrue([
      for n, v in var.settings : contains({
        containerInsights               = ["disabled", "enabled", "enhanced"]
        awsvpcTrunking                  = ["enabled", "disabled"]
        defaultLogDriverMode            = ["blocking", "non-blocking"]
        dualStackIPv6                   = ["enabled", "disabled"]
        fargateFIPSMode                 = ["enabled", "disabled"]
        fargateTaskRetirementWaitPeriod = ["0", "7", "14"]
        fargateEventWindows             = ["enabled"]
      }[n], v)
    ])], 0))
    error_message = "Invalid value for an account setting - containerInsights: disabled|enabled|enhanced, awsvpcTrunking/dualStackIPv6/fargateFIPSMode: enabled|disabled, defaultLogDriverMode: blocking|non-blocking, fargateTaskRetirementWaitPeriod: 0|7|14, fargateEventWindows: enabled."
  }
}
