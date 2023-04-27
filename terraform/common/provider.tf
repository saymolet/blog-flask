terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}


provider "google" {
  project = var.project_id
  region  = var.compute_region
  zone    = var.compute_zone
}
