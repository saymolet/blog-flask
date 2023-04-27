resource "google_service_account" "jenkins" {
  account_id   = var.jenkins_service_account_id
  display_name = "Jenkins Service Account"
}

resource "google_service_account" "agent" {
  account_id   = var.agent_service_account_id
  display_name = "Jenkins Service Account"
}

resource "google_service_account" "gke_flask" {
  account_id   = var.gke_service_account_id
  display_name = "GKE Service Account"
}
