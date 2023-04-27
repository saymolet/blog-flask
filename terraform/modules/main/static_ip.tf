# reserve a static external IP
resource "google_compute_address" "jenkins-external-ip" {
  name = "jenkins-external-ip"
}

resource "google_compute_address" "agent-internal-ip" {
  name         = "agent-internal-ip"
  address_type = "INTERNAL"
}
