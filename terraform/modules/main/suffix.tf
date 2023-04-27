resource "random_id" "jenkins_name_suffix" {
  byte_length = 4
}

resource "random_id" "agent_name_suffix" {
  byte_length = 4
}

resource "random_id" "gke_cluster_suffix" {
  byte_length = 4
}

resource "random_id" "artifact_registry_suffix" {
  byte_length = 4
}
