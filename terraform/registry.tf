########################### ARTIFACT REGISTRY ###########################
resource "random_id" "artifact_registry_suffix" {
  byte_length = 4
}

resource "google_artifact_registry_repository" "flask-blog-repo" {
  location      = var.artifact_region
  repository_id = "flask-blog-repo-${random_id.artifact_registry_suffix.hex}"
  description   = "Docker repository for flask-blog images"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_binding" "binding" {
  project    = google_artifact_registry_repository.flask-blog-repo.project
  location   = google_artifact_registry_repository.flask-blog-repo.location
  repository = google_artifact_registry_repository.flask-blog-repo.name
  role       = "roles/artifactregistry.writer"
  members = [
    google_service_account.agent.member,
  ]
}
########################### ARTIFACT REGISTRY ###########################