#
# ONLY EDIT THIS FILE IN github.com/rafalmasiarek/terraform-null-tagger
# All other instances of this file should be a copy of this one.
#
# Copy this file from
# https://github.com/rafalmasiarek/terraform-null-tagger/blob/main/exports/tagger.tf
# and place it in your module to wire up standardized tagging:
#
#   curl -sL https://raw.githubusercontent.com/rafalmasiarek/terraform-null-tagger/main/exports/tagger.tf -o tagger.tf
#
# Requires a local map named `taggable` (map(object)), defined elsewhere
# in this module - one entry per resource that needs tags:
#
#   { name       = string
#     service    = optional(any, {})          # see terraform-null-tagger's `service` variable
#     attributes = optional(list(string), [])  # extra name_prefix segments
#     created_at = optional(string)            # RFC3339, e.g. time_static.created.rfc3339
#     extra_tags = optional(any, {}) }         # arbitrary custom tags
#
# use_tagger = false bypasses all of this and uses var.tags directly. The
# tagger provider must still be declared in required_providers regardless -
# Terraform checks provider availability at init time independently of
# for_each = {}.
#
# tagger_additional_services lets a caller add service data this module
# doesn't compute itself, keyed by the same key used in local.taggable:
#
#   tagger_additional_services = {
#     "subnet-public-a" = { network = { nat_gateway_id = aws_nat_gateway.example.id } }
#   }
#

variable "use_tagger" {
  description = "Compute and apply standardized tags via terraform-null-tagger. When false, use var.tags as-is instead."
  type        = bool
  default     = true
}

variable "tagger_context" {
  description = "module.tagger.context from the root stack's base terraform-null-tagger call."
  type        = any
  default     = null
}

variable "tags" {
  description = "Custom tags for the resource(s)."
  type        = map(string)
  default     = {}
}

variable "tagger_additional_services" {
  description = "Extra terraform-null-tagger `service` data per taggable resource, keyed by the same key as local.taggable (e.g. \"subnet-public-a\"). Merged on top of what this module computes automatically - lets a caller tag something this module doesn't know about, without waiting for a new module release."
  type        = any
  default     = {}
}

variable "origin_module" {
  description = "Sub-module identifier stamped into the tagger:origin:module tag so resources created by different sub-modules of one origin repo can be told apart. Set per sub-module (e.g. \"cluster\" at root, \"service\", \"addons\", \"node-group\")."
  type        = string
  default     = null
}

data "tagger_origin" "self" {
  count       = var.use_tagger ? 1 : 0
  module_path = path.module
}

module "tagger" {
  for_each = var.use_tagger ? local.taggable : {}
  source   = "rafalmasiarek/tagger/null"
  version  = ">= 0.7.0"
  context  = var.tagger_context
  name     = each.value.name

  origin_source  = data.tagger_origin.self[0].source
  origin_version = data.tagger_origin.self[0].version
  # Root always identifies as "cluster"; sub-modules override via their own
  # tagger.tf copy + the origin_module arg passed at the module call site.
  origin_module = coalesce(var.origin_module, "cluster")

  service    = merge(try(each.value.service, {}), try(var.tagger_additional_services[each.key], {}))
  attributes = try(each.value.attributes, null)
  created_at = try(each.value.created_at, null)
  extra_tags = try(each.value.extra_tags, {})
}

locals {
  # var.tags fills in keys tagger doesn't already produce - tagger's own
  # tags always win on conflict.
  tagger_tags = {
    for k in keys(local.taggable) :
    k => var.use_tagger ? merge(var.tags, module.tagger[k].tags) : var.tags
  }
}
