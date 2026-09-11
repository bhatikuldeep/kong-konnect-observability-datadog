output "control_plane_ids" {
  description = "Map of CP key (cp1/cp2/cp3) to Konnect Control Plane ID"
  value       = { for k, v in konnect_gateway_control_plane.this : k => v.id }
}

output "control_plane_names" {
  description = "Map of CP key (cp1/cp2/cp3) to Konnect Control Plane name"
  value       = { for k, v in konnect_gateway_control_plane.this : k => v.name }
}
