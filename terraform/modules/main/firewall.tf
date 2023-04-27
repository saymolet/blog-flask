resource "google_compute_firewall" "deny_agent_ingress" {
  name    = "deny-agent-ingress"
  network = "default"

  deny {
    protocol = "tcp"
  }

  deny {
    protocol = "udp"
  }

  target_tags   = ["deny-agent-ingress"]
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
  priority    = 1000
}
