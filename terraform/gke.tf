########################### GKE ###########################
resource "random_id" "gke_cluster_suffix" {
  byte_length = 4
}

resource "google_service_account" "gke_flask" {
  account_id   = var.gke_service_account_id
  display_name = "GKE Service Account"
}

resource "google_project_iam_binding" "artifactRegistryReader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  members = [
    google_service_account.gke_flask.member
  ]
}

resource "google_container_cluster" "primary" {
  name     = "flask-blog-cluster-${random_id.gke_cluster_suffix.hex}"
  location = var.compute_zone
  release_channel {
    channel = "REGULAR"
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "flask_nodes" {
  name       = "flask-blog-node-pool-${random_id.gke_cluster_suffix.hex}"
  location   = var.gke_zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count  = 1
    max_node_count  = 4
    location_policy = "BALANCED"
  }

  node_config {
    machine_type = var.gke_machine_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_flask.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  depends_on = [google_service_account.gke_flask]
}
########################### GKE ###########################