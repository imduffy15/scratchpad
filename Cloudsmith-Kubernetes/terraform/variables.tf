variable "cloudsmith_api_key" {
  description = "Cloudsmith API key with permission to manage services, OIDC and repository privileges. Prefer exporting TF_VAR_cloudsmith_api_key or CLOUDSMITH_API_KEY rather than committing it."
  type        = string
  sensitive   = true
  default     = null
}

variable "organization" {
  description = "Cloudsmith organisation slug (becomes ESO `orgSlug` and the Cloudsmith registry path)."
  type        = string
  default     = "iduffy-demo"
}

variable "repository" {
  description = "Cloudsmith repository slug that images are pulled from (becomes the registry path docker.cloudsmith.io/<org>/<repo>)."
  type        = string
  default     = "default"
}

variable "docker_upstreams" {
  description = <<-EOT
    Docker upstreams configured on the repository. Cloudsmith resolves a pulled
    image path against these upstreams in `priority` order (1..n), so a single
    repo (docker.cloudsmith.io/<org>/<repo>) transparently proxies/caches images
    from Docker Hub, GHCR, GCR, ECR, ACR, etc.

    The defaults target the PUBLIC endpoints (good for public images). For
    PRIVATE registries, override upstream_url with the registry-specific host
    and set auth_mode/auth_username/auth_secret, e.g.:
      ecr = { upstream_url = "https://<acct>.dkr.ecr.<region>.amazonaws.com",
              priority = 4, auth_mode = "Token", auth_secret = "<ecr-token>" }
      acr = { upstream_url = "https://<name>.azurecr.io",
              priority = 5, auth_mode = "Username and Password",
              auth_username = "<sp-id>", auth_secret = "<sp-secret>" }
      gcr = { upstream_url = "https://<region>-docker.pkg.dev",
              priority = 3, auth_mode = "Token", auth_secret = "<token>" }
  EOT
  type = map(object({
    upstream_url  = string
    priority      = number
    mode          = optional(string, "Cache and Proxy")
    auth_mode     = optional(string, "None")
    auth_username = optional(string)
    auth_secret   = optional(string)
  }))
  default = {
    dockerhub = { upstream_url = "https://index.docker.io", priority = 1 }
    ghcr      = { upstream_url = "https://ghcr.io", priority = 2 }
    gcr       = { upstream_url = "https://gcr.io", priority = 3 }
    ecr       = { upstream_url = "https://public.ecr.aws", priority = 4 }
    acr       = { upstream_url = "https://mcr.microsoft.com", priority = 5 }
  }
}

variable "create_repository" {
  description = "Whether Terraform should create the repository. Set false if it already exists (a data source is used instead)."
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Human-readable name for the Cloudsmith service account used by the cluster."
  type        = string
  default     = "Kubernetes Image Pull"
}

variable "oidc_name" {
  description = "Name for the Cloudsmith OIDC provider configuration."
  type        = string
  default     = "kubernetes"
}

variable "cluster_issuer_url" {
  description = <<-EOT
    Your Kubernetes cluster's OIDC issuer URL. Cloudsmith uses this to discover
    the cluster's OpenID configuration and JWKS to validate ServiceAccount tokens.
    Get it with:
      kubectl get --raw /.well-known/openid-configuration | jq -r .issuer
  EOT
  type        = string
}

variable "service_account_subject" {
  description = "The `sub` claim the STATIC catch-all provider requires, i.e. the central ESO ServiceAccount."
  type        = string
  default     = "system:serviceaccount:external-secrets:cloudsmith-token-sa"
}

variable "dynamic_namespaces" {
  description = <<-EOT
    Namespaces that get their OWN Cloudsmith service via the dynamic-mapping OIDC
    provider (per-namespace identity + entitlement isolation). Leave empty to use
    only the static catch-all. Scale to hundreds by listing them all (or generate
    the list — see scale/generate-namespaces.sh which can emit a tfvars file).
  EOT
  type        = list(string)
  default     = ["team-a", "team-b"]
}

variable "per_namespace_sa_name" {
  description = "Name of the per-namespace Kubernetes ServiceAccount used by the dynamic path (its subject is routed by Cloudsmith)."
  type        = string
  default     = "cloudsmith-pull"
}

variable "mapping_claim" {
  description = "OIDC claim the dynamic provider routes on. 'sub' is always present in K8s SA tokens; set to a namespace claim only if your Cloudsmith plan supports nested-claim routing."
  type        = string
  default     = "sub"
}

variable "audience" {
  description = "The `aud` claim the ServiceAccount token must carry (matches ESO generator `audiences`)."
  type        = string
  default     = "https://api.cloudsmith.io"
}
