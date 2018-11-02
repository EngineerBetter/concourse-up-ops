provider "google" {
  project = "concourse-up"
  region = "us-east1"
}

// route for nat
resource "google_compute_route" "nat" {
  name                   = "nat-route"
  dest_range             = "0.0.0.0/0"
  network                = "${google_compute_network.bosh.name}"
  next_hop_instance      = "${google_compute_instance.nat-instance.name}"
  next_hop_instance_zone = "us-east1-c"
  priority               = 800
  tags                   = ["no-ip"]
  project                = "concourse-up"
}

// nat
resource "google_compute_instance" "nat-instance" {
  name         = "nat-instance"
  machine_type = "n1-standard-1"
  zone         = "us-east1-c"
  project      = "concourse-up"

  tags = ["nat", "internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1404-trusty-v20180122"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.private.name}"
    subnetwork_project = "concourse-up"
    access_config {
      // Ephemeral IP
    }
  }

  can_ip_forward = true

  metadata_startup_script = <<EOT
#!/bin/bash
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
EOT
}
resource "google_compute_network" "bosh" {
  name                    = "bosh-network"
  project                 = "concourse-up"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "public" {
  name          = "bosh-us-east1-subnet-public"
  ip_cidr_range = "10.0.0.0/24"
  network       = "${google_compute_network.bosh.self_link}"
  project       = "concourse-up"
}
resource "google_compute_subnetwork" "private" {
  name          = "bosh-us-east1-subnet-private"
  ip_cidr_range = "10.0.1.0/24"
  network       = "${google_compute_network.bosh.self_link}"
  project       = "concourse-up"
}
resource "google_service_account" "bosh" {
  account_id   = "boshaccount"
  display_name = "bosh"
}
resource "google_service_account_key" "bosh" {
  service_account_id = "${google_service_account.bosh.name}"
  public_key_type = "TYPE_X509_PEM_FILE"
}

resource "google_project_iam_member" "bosh" {
  project = "concourse-up"
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.bosh.email}"
}
resource "google_compute_address" "atc_ip" {
  name = "atc-ip"
}

resource "google_compute_address" "director" {
  name = "director"
}

output "private_subnet_id" {
    value = "${google_compute_subnetwork.private.name}"
}

output "public_subnet_id" {
    value = "${google_compute_subnetwork.public.name}"
}

output "vpc_id" {
    value = "${google_compute_network.bosh.name}"
}

output "nat_gateway_ip" {
    value = "${google_compute_instance.nat-instance.network_interface.0.access_config.0.nat_ip}"
}

output "source_access_ip" {
  value = ""
}

output "director_key_pair" {
  value = "${base64decode(google_service_account_key.bosh.private_key)}"
}

output "director_public_ip" {
  value = "${google_compute_address.director.address}"
}

output "atc_public_ip" {
  value = ""
}

output "director_security_group_id" {
  value = ""
}

output "vms_security_group_id" {
  value = ""
}

output "atc_security_group_id" {
  value = ""
}



output "blobstore_bucket" {
  value = ""
}

output "blobstore_user_access_key_id" {
  value = ""
}

output "blobstore_user_secret_access_key" {
  value     = ""
  sensitive = true
}

output "bosh_user_access_key_id" {
  value = ""
}

output "bosh_user_secret_access_key" {
  value     = ""
  sensitive = true
}

output "bosh_db_port" {
  value = ""
}

output "bosh_db_address" {
  value = ""
}
