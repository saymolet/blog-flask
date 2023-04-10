variable "project_id" {
  type    = string
  default = "exemplary-torch-377814"
}

# ------------- JENKINS -------------
variable "compute_region" {
  type    = string
  default = "europe-west3"
}

variable "compute_zone" {
  type    = string
  default = "europe-west3-a"
}

variable "jenkins_machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "jenkins_service_account_id" {
  type        = string
  default     = "jenkins"
  description = "Name of the Service Account"
}

# ------------- JENKINS -------------

# ------------- GKE -------------

variable "gke_service_account_id" {
  type        = string
  default     = "gke-flask"
  description = "Name of the Service Account"
}

variable "gke_zone" {
  type    = string
  default = "europe-west3-a"
}

# ------------- GKE -------------

# ------------- ARTIFACT -------------
variable "artifact_region" {
  type    = string
  default = "europe-west3"
}

# ------------- ARTIFACT -------------