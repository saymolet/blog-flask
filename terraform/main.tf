# This terraform file will create next resources: 
# *static IP for Jenkins VM
# *service account for Jenkins VM (with kubernetesEngineDeveloper, custom_computeMetadataWriter roles)
# *service account for GKE Nodes (with artifactRegistryReader role)
# *GKE Node Pool and GKE Cluster
# *Artifact Registry repository

provider "google" {
  project = var.project_id
  region  = var.compute_region
  zone    = var.compute_zone
}

########################## JENKINS ##########################
#-------------------- SUFFIX --------------------------
resource "random_id" "jenkins_name_suffix" {
  byte_length = 4
}

resource "random_id" "agent_name_suffix" {
  byte_length = 4
}
#-------------------- SUFFIX --------------------------

#-------------------- FIREWALLS --------------------------
resource "google_compute_firewall" "deny_agent_ingress" {
  name    = "deny-agent-ingress"
  network = "default"

  deny {
    protocol = "tcp"
  }

  deny {
    protocol = "udp"
  }

  target_tags = ["deny-agent-ingress"]
  source_ranges = ["0.0.0.0/0"]
  # lower than allow_all_from_jenkins
  priority = 1005
}

resource "google_compute_firewall" "agent_firewall" {
  name    = "allow-all-from-jenkins"
  network = "default"

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }  

  allow {
    protocol = "icmp"
  }  

  target_tags = ["agent"]
  source_tags = ["http-server"]
  priority = 1000
}
#-------------------- FIREWALLS --------------------------

#-------------------- STATIC IPs --------------------------
# reserve a static external IP
resource "google_compute_address" "jenkins-external-ip" {
  name = "jenkins-external-ip"
}

resource "google_compute_address" "agent-internal-ip" {
  name = "agent-internal-ip"
  address_type = "INTERNAL"
}
#-------------------- STATIC IPs --------------------------

#-------------------- SERVICE ACCOUNTS --------------------------
# jenkins service account
resource "google_service_account" "jenkins" {
  account_id   = var.jenkins_service_account_id
  display_name = "Jenkins Service Account"
}

resource "google_service_account" "agent" {
  account_id   = var.agent_service_account_id
  display_name = "Jenkins Service Account"
}

resource "google_service_account_iam_binding" "admin-account-iam" {
  service_account_id = google_service_account.jenkins.name
  role               = "roles/iam.serviceAccountUser"

  members = [
    google_service_account.jenkins.member,
  ]
}

resource "google_project_iam_custom_role" "custom_computeMetadataWriter" {
  role_id     = "computeMetadataWriter"
  title       = "Compute Metadata Writer"
  permissions = [
    "compute.instances.get", 
    "compute.instances.list",
    "compute.instances.setMetadata",
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
#-------------------- SERVICE ACCOUNTS --------------------------

# define what image to use in GCP Compute Engine
data "google_compute_image" "ubuntu_image" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

# compute config
resource "google_compute_instance" "jenkins_instance" {
  name         = "jenkins-${random_id.jenkins_name_suffix.hex}"
  machine_type = var.jenkins_machine_type
  zone         = var.compute_zone
  # allow ingress 80 tcp
  tags = ["http-server"]

  # startup script 
  metadata_startup_script = file("${path.module}/jenkins.sh")
  # we will pass arguments through custom metadata key-value pairs
  metadata = {
    PROJECT_ID   = var.project_id
    CLUSTER_ZONE = var.compute_zone
    CLUSTER_NAME = google_container_cluster.primary.name
    ARTIFACT_NAME   = google_artifact_registry_repository.flask-blog-repo.name
    ARTIFACT_REGION = var.artifact_region
    JENKINS_INSTANCE_NAME = "jenkins-${random_id.jenkins_name_suffix.hex}"
    AGENT_IP = google_compute_address.agent-internal-ip.address
  }

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
  metadata_startup_script = file("${path.module}/agent_config.sh")

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
    network = "default"
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

########################### JENKINS ###########################

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
