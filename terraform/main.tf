terraform {
  required_version = ">= 1.5"
  required_providers {
    konnect = {
      source  = "kong/konnect"
      version = "~> 2.0"
    }
  }
}

provider "konnect" {
  personal_access_token = var.konnect_pat
  server_url             = var.konnect_server_url
}

# Multiple Control Planes, one Terraform apply - each gets its own
# env/team/region labels (Konnect-native, visible in Konnect's own UI).
# Each CP's decK config (deck/kong-otel-<key>.yaml) mirrors these same
# values into resource_attributes, so Konnect and Datadog never disagree
# about a CP's env/team/region - see datadog/datadog-values.yaml for why
# these live per-CP and NOT as Datadog Agent-global tags (shared-Agent,
# multi-CP topology; Agent-global env would double-tag telemetry rather
# than override, per Datadog's own Unified Service Tagging docs).
resource "konnect_gateway_control_plane" "this" {
  for_each = var.control_planes

  name         = each.value.name
  description  = each.value.description
  cluster_type = "CLUSTER_TYPE_HYBRID"

  labels = {
    env    = each.value.env
    team   = each.value.team
    region = each.value.region
  }
}
