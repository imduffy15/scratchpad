output "org_slug" {
  description = "Cloudsmith org slug -> ESO generator `orgSlug`."
  value       = var.organization
}

output "repository_slug" {
  description = "Cloudsmith repository slug -> registry path docker.cloudsmith.io/<org>/<repo>."
  value       = local.repository_slug
}

output "shared_service_slug" {
  description = "Shared Cloudsmith service slug -> ESO generator `serviceSlug` for the static catch-all path."
  value       = cloudsmith_service.shared.slug
}

output "per_namespace_service_slugs" {
  description = "namespace -> Cloudsmith service slug for the dynamic-mapping path (each namespace's ESO uses its own slug)."
  value       = { for ns, svc in cloudsmith_service.per_namespace : ns => svc.slug }
}

output "docker_upstreams" {
  description = "Configured Docker upstreams (name -> url @ priority) on the repository."
  value       = { for k, u in cloudsmith_repository_upstream.docker : k => "${u.upstream_url} (priority ${u.priority}, ${u.mode})" }
}

output "oidc_static_slug" {
  description = "Slug of the static catch-all OIDC provider."
  value       = cloudsmith_oidc.static.slug
}

output "oidc_dynamic_slug" {
  description = "Slug of the dynamic-mapping OIDC provider (null if no dynamic_namespaces)."
  value       = length(cloudsmith_oidc.dynamic) > 0 ? cloudsmith_oidc.dynamic[0].slug : null
}

# Copy/paste this to stamp the slugs into the Kubernetes manifests.
output "configure_command" {
  description = "Run this (or `mise run configure`) to update the manifests with the created slugs."
  value       = "./scripts/configure.sh --org ${var.organization} --repo ${local.repository_slug} --service ${cloudsmith_service.shared.slug}"
}
