terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudsmith = {
      source = "cloudsmith-io/cloudsmith"
      # Check the registry for the latest:
      # https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest
      version = ">= 0.0.50"
    }
  }
}

provider "cloudsmith" {
  # Reads var.cloudsmith_api_key; you can also leave this unset and export
  # CLOUDSMITH_API_KEY in the environment.
  api_key = var.cloudsmith_api_key
}
