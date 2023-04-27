resource "google_project_iam_custom_role" "custom_computeMetadataWriter" {
  role_id = "computeMetadataWriter"
  title   = "Compute Metadata Writer"
  permissions = [
    "compute.instances.get",
    "compute.instances.list",
    "compute.instances.setMetadata",
  ]
}

resource "google_service_account_iam_binding" "admin-account-iam" {
  service_account_id = google_service_account.jenkins.name
  role               = "roles/iam.serviceAccountUser"

  members = [
    google_service_account.jenkins.member,
  ]
}

resource "google_project_iam_binding" "computeMetadataWriter" {
  project = var.project_id
  role    = google_project_iam_custom_role.custom_computeMetadataWriter.id
  members = [
    google_service_account.jenkins.member,
  ]
}

resource "google_project_iam_binding" "kubernetesEngineDeveloper" {
  project = var.project_id
  role    = "roles/container.developer"
  members = [
    google_service_account.agent.member,
  ]
}

resource "google_project_iam_binding" "artifactRegistryReader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  members = [
    google_service_account.gke_flask.member
  ]
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
