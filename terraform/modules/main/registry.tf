resource "google_artifact_registry_repository" "flask-blog-repo" {
  location      = var.artifact_region
  repository_id = "flask-blog-repo-${random_id.artifact_registry_suffix.hex}"
  description   = "Docker repository for flask-blog images"
  format        = "DOCKER"
}
