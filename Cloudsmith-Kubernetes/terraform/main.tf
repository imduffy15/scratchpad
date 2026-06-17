# ---------------------------------------------------------------------------
# Cloudsmith side of the integration, managed as code.
#
#   * a pull-through repository with Docker upstreams (Docker Hub, GHCR, GCR,
#     ECR, ACR) so one repo proxies/caches them all
#   * a SHARED service account used by the cluster-wide (static OIDC) path
#   * per-namespace service accounts for the dynamic-mapping path, generated at
#     scale with for_each over var.dynamic_namespaces
#   * two OIDC providers:
#       - STATIC  catch-all  -> the shared service (works for any namespace)
#       - DYNAMIC mapping     -> routes the namespace/subject claim to the
#                                matching per-namespace service (and rejects
#                                mismatches, preventing privilege escalation)
#
# See terraform/README.md and ../docs/OIDC-MODES.md for the full explanation.
# ---------------------------------------------------------------------------

data "cloudsmith_organization" "org" {
  slug = var.organization
}

# --- Repository + Docker upstreams -----------------------------------------

resource "cloudsmith_repository" "repo" {
  count     = var.create_repository ? 1 : 0
  name      = var.repository
  slug      = var.repository
  namespace = data.cloudsmith_organization.org.slug_perm
}

data "cloudsmith_repository" "repo" {
  count      = var.create_repository ? 0 : 1
  namespace  = data.cloudsmith_organization.org.slug_perm
  identifier = var.repository
}

locals {
  repository_slug      = var.create_repository ? cloudsmith_repository.repo[0].slug : data.cloudsmith_repository.repo[0].slug
  repository_slug_perm = var.create_repository ? cloudsmith_repository.repo[0].slug_perm : data.cloudsmith_repository.repo[0].slug_perm

  # Per-namespace service slug + the Kubernetes subject that must map to it.
  per_ns_service_name = { for ns in var.dynamic_namespaces : ns => "ns-${ns}" }
  per_ns_subject      = { for ns in var.dynamic_namespaces : ns => "system:serviceaccount:${ns}:${var.per_namespace_sa_name}" }
}

# Docker upstreams: make the repo proxy/cache Docker Hub, GHCR, GCR, ECR, ACR…
# Cloudsmith tries them in priority order when resolving a pulled image path.
resource "cloudsmith_repository_upstream" "docker" {
  for_each = var.docker_upstreams

  name          = each.key
  namespace     = data.cloudsmith_organization.org.slug_perm
  repository    = local.repository_slug_perm
  upstream_type = "docker"
  upstream_url  = each.value.upstream_url
  mode          = each.value.mode
  priority      = each.value.priority
  auth_mode     = each.value.auth_mode
  auth_username = each.value.auth_username
  auth_secret   = each.value.auth_secret
}

# --- Service accounts -------------------------------------------------------

# Shared identity used by the cluster-wide static (catch-all) OIDC path.
resource "cloudsmith_service" "shared" {
  name         = var.service_name
  organization = data.cloudsmith_organization.org.slug_perm
  role         = "Member"
}

# One identity per namespace for the dynamic-mapping path. Scale this to
# hundreds of namespaces just by extending var.dynamic_namespaces.
#
# The name is already slug-safe ("ns-<namespace>") so Cloudsmith derives the slug
# "ns-<namespace>" — which is exactly the `serviceSlug` the per-namespace ESO
# generator requests (see scale/generate-namespaces.sh) and the service the
# dynamic mapping routes that namespace's token to.
resource "cloudsmith_service" "per_namespace" {
  for_each = toset(var.dynamic_namespaces)

  name         = local.per_ns_service_name[each.key]
  organization = data.cloudsmith_organization.org.slug_perm
  role         = "Member"
}

# --- Repository privileges (Read = pull) -----------------------------------

resource "cloudsmith_repository_privileges" "pull" {
  organization = data.cloudsmith_organization.org.slug
  repository   = local.repository_slug

  # shared service
  service {
    privilege = "Read"
    slug      = cloudsmith_service.shared.slug
  }

  # every per-namespace service
  dynamic "service" {
    for_each = cloudsmith_service.per_namespace
    content {
      privilege = "Read"
      slug      = service.value.slug
    }
  }
}

# --- Per-team PRIVATE repositories + asymmetric privileges ------------------
# Each team gets its own private repo for first-party images. ONLY that team's
# per-namespace service can Read it — this is what makes a cross-team pull fail
# (e.g. namespace team-b cannot pull docker.cloudsmith.io/<org>/team-a/...).
# Every team service still has Read on the shared `default` repo above, so all
# of them can pull the upstream-proxied public images.
#
# NOTE: each entry must also be in var.dynamic_namespaces (so its per-namespace
# service exists). The defaults keep them in sync.
resource "cloudsmith_repository" "team" {
  for_each = toset(var.team_repositories)

  name        = each.key
  slug        = each.key
  namespace   = data.cloudsmith_organization.org.slug_perm
  description = "Private first-party repository for team ${each.key}"
}

resource "cloudsmith_repository_privileges" "team" {
  for_each = cloudsmith_repository.team

  organization = data.cloudsmith_organization.org.slug
  repository   = each.value.slug

  # Only this team's service can read its private repo.
  service {
    privilege = "Read"
    slug      = cloudsmith_service.per_namespace[each.key].slug
  }
}

# --- OIDC: static catch-all -------------------------------------------------
# Trusts the central ESO ServiceAccount subject and maps it to the shared
# service. This single provider serves every namespace via the
# ClusterExternalSecret + ClusterGenerator path — no per-namespace config.
resource "cloudsmith_oidc" "static" {
  namespace        = data.cloudsmith_organization.org.slug
  name             = "${var.oidc_name}-static"
  enabled          = true
  provider_url     = var.cluster_issuer_url
  service_accounts = [cloudsmith_service.shared.slug]

  claims = {
    aud = var.audience
    sub = var.service_account_subject
  }
}

# --- OIDC: dynamic per-namespace mapping ------------------------------------
# One provider that routes on the Kubernetes subject claim. Each app namespace
# runs ESO with its OWN ServiceAccount (var.per_namespace_sa_name); its subject
# maps to that namespace's service. A namespace requesting another namespace's
# service is rejected — anti-privilege-escalation, as in the reference demo:
#   https://github.com/cloudsmith-iduffy/cloudsmith-oidc-dynamic-mapping-demo
#
# mapping_claim defaults to "sub" (always present in K8s SA tokens). If your
# Cloudsmith plan supports nested-claim routing you can set it to the namespace
# claim instead (see var.mapping_claim).
resource "cloudsmith_oidc" "dynamic" {
  count = length(var.dynamic_namespaces) > 0 ? 1 : 0

  namespace     = data.cloudsmith_organization.org.slug
  name          = "${var.oidc_name}-dynamic"
  enabled       = true
  provider_url  = var.cluster_issuer_url
  mapping_claim = var.mapping_claim

  claims = {
    aud = var.audience
  }

  dynamic "dynamic_mappings" {
    for_each = toset(var.dynamic_namespaces)
    content {
      # claim_value matches mapping_claim: the full subject by default, or the
      # bare namespace name when mapping_claim routes on the namespace claim.
      claim_value     = var.mapping_claim == "sub" ? local.per_ns_subject[dynamic_mappings.key] : dynamic_mappings.key
      service_account = cloudsmith_service.per_namespace[dynamic_mappings.key].slug
    }
  }
}
