terraform {
  required_version = ">= 1.11"

  required_providers {
    ionoscloud = {
      source  = "ionos-cloud/ionoscloud"
      version = ">= 6.7.0"
    }
  }
}
