variable "konnect_pat" {
  description = "Konnect personal access token (kpat_...)"
  type        = string
  sensitive   = true
}

variable "konnect_server_url" {
  description = "Konnect API server URL (region-specific)"
  type        = string
  default     = "https://eu.api.konghq.com"
}

# 3 Control Planes, each with its own env/team/region - deliberately
# realistic-but-fake values to demonstrate a shared-Agent, multi-CP
# topology (see main.tf's resource comment and
# datadog/datadog-values.yaml for why these labels live here, per-CP,
# and not as Datadog Agent-global tags). Each key here (cp1/cp2/cp3) must
# match a deck/kong-otel-<key>.yaml file and a k8s DataPlane identity of
# the same name - see k8s/manifests/ and Taskfile.yaml's dp:up loop.
variable "control_planes" {
  description = "Map of Control Planes to create, each with its own labels"
  type = map(object({
    name        = string
    description = string
    env         = string
    team        = string
    region      = string
  }))
  default = {
    cp1 = {
      name        = "konnect-observability-demo-cp1"
      description = "Konnect observability demo - Control Plane 1 (prod/checkout, eu-west-1)"
      env         = "prod"
      team        = "checkout"
      region      = "eu-west-1"
    }
    cp2 = {
      name        = "konnect-observability-demo-cp2"
      description = "Konnect observability demo - Control Plane 2 (staging/payments, eu-west-1)"
      env         = "staging"
      team        = "payments"
      region      = "eu-west-1"
    }
    cp3 = {
      name        = "konnect-observability-demo-cp3"
      description = "Konnect observability demo - Control Plane 3 (dev/platform, us-east-1)"
      env         = "dev"
      team        = "platform"
      region      = "us-east-1"
    }
  }
}
