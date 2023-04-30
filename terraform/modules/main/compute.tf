resource "google_compute_instance" "jenkins_instance" {
  name         = "jenkins-${random_id.jenkins_name_suffix.hex}"
  machine_type = var.jenkins_machine_type
  zone         = var.compute_zone
  # allow ingress 80 tcp
  tags = ["http-server", "https-server"]

  metadata_startup_script = templatefile("${path.module}/scripts/jenkins.tmpl",
    {
      PROJECT_ID            = var.project_id
      CLUSTER_ZONE          = var.gke_zone
      CLUSTER_NAME          = google_container_cluster.primary.name
      ARTIFACT_NAME         = google_artifact_registry_repository.flask-blog-repo.name
      ARTIFACT_REGION       = var.artifact_region
      JENKINS_INSTANCE_NAME = "jenkins-${random_id.jenkins_name_suffix.hex}"
      AGENT_IP              = google_compute_address.agent-internal-ip.address
      jenkins_admin_pass    = "$jenkins_admin_pass"
  })  

  boot_disk {
    initialize_params {
      # ubuntu 20.04
      image = data.google_compute_image.ubuntu_image.self_link
      size  = 30
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.jenkins-external-ip.address
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.jenkins.email
    scopes = ["cloud-platform"]
  }

  # do not create vm instance before service account and static ip
  depends_on = [google_service_account.jenkins, google_compute_address.jenkins-external-ip]
}

resource "google_compute_instance" "agent_instance" {
  name         = "agent-${random_id.jenkins_name_suffix.hex}"
  machine_type = var.agent_machine_type
  zone         = var.compute_zone

  # startup script 
  metadata_startup_script = file("${path.module}/scripts/agent_config.sh")

  boot_disk {
    initialize_params {
      # ubuntu 20.04
      image = data.google_compute_image.ubuntu_image.self_link
      size  = 30
    }
  }
  # allow all ingress from jenkins VM
  tags = ["agent", "deny-agent-ingress"]

  network_interface {
    network    = "default"
    network_ip = google_compute_address.agent-internal-ip.address
    access_config {
      # this ensures VM gets ephemeral external ip 
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.agent.email
    scopes = ["cloud-platform"]
  }

  # do not create vm instance before service account and static ip
  depends_on = [google_service_account.agent]
}
