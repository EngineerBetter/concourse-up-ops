variable "zone" {
  type = "string"
	default = "<% .Zone %>"
}
variable "tags" {
  type = "string"
	default = "<% .Tags %>"
}
variable "project" {
  type = "string"
	default = "<% .Project %>"
}
variable "gcpcredentialsjson" {
  type = "string"
	default = "<% .GCPCredentialsJSON %>"
}
variable "externalip" {
  type = "string"
	default = "<% .ExternalIP %>"
}

variable "deployment" {
  type = "string"
	default = "<% .Deployment %>"
}
variable "region" {
  type = "string"
	default = "<% .Region %>"
}

variable "db_tier" {
  type = "string"
	default = "<% .DBTier %>"
}
variable "db_name" {
  type = "string"
	default = "<% .DBName %>"
}

variable "db_username" {
  type = "string"
	default = "<% .DBUsername %>"
}
variable "db_password" {
  type = "string"
	default = "<% .DBPassword %>"
}

provider "google" {
    credentials = "<% .GCPCredentialsJSON %>"
    project = "<% .Project %>"
    region = "us-east1"
}


terraform {
	backend "gcs" {
		bucket = "<% .ConfigBucket %>"
		region = "<% .Region %>"
	}
}

// route for nat
resource "google_compute_route" "nat" {
  name                   = "${var.deployment}-nat-route"
  dest_range             = "0.0.0.0/0"
  network                = "${google_compute_network.bosh.name}"
  next_hop_instance      = "${google_compute_instance.nat-instance.name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 800
  tags                   = ["no-ip"]
  project                = "${var.project}"
}

// nat
resource "google_compute_instance" "nat-instance" {
  name         = "${var.deployment}-nat-instance"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
  project      = "${var.project}"

  tags = ["nat", "internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1404-trusty-v20180122"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.private.name}"
    subnetwork_project = "${var.project}"
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
  name                    = "${var.deployment}-bosh-network"
  project                 = "${var.project}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "public" {
  name          = "${var.deployment}-bosh-${var.region}-subnet-public"
  ip_cidr_range = "10.0.0.0/24"
  network       = "${google_compute_network.bosh.self_link}"
  project       = "${var.project}"
}
resource "google_compute_subnetwork" "private" {
  name          = "${var.deployment}-bosh-${var.region}-subnet-private"
  ip_cidr_range = "10.0.1.0/24"
  network       = "${google_compute_network.bosh.self_link}"
  project       = "${var.project}"
}
resource "google_service_account" "bosh" {
  account_id   = "${var.deployment}-boshaccount"
  display_name = "bosh"
}
resource "google_service_account_key" "bosh" {
  service_account_id = "${google_service_account.bosh.name}"
  public_key_type = "TYPE_X509_PEM_FILE"
}

resource "google_project_iam_member" "bosh" {
  project = "${var.project}"
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.bosh.email}"
}
resource "google_compute_address" "atc_ip" {
  name = "${var.deployment}-atc-ip"
}

resource "google_compute_address" "director" {
  name = "${var.deployment}-director-ip"
}

resource "google_sql_database_instance" "director" {
  name = "${var.db_name}"
  database_version = "POSTGRES_9_6"
  region       = "${var.region}"

  settings {
    tier = "${var.db_tier}"
  }
}

resource "google_sql_database" "director" {
  name      = "udb"
  instance  = "${google_sql_database_instance.director.name}"
}

resource "google_sql_user" "director" {
  name     = "${var.db_username}"
  instance = "${google_sql_database_instance.director.name}"
  host     = "*"
  password = "${var.db_password}"
}
output "network" {
value = "${google_compute_network.bosh.name}"
}

output "private_subnetwork_name" {
value = "${google_compute_subnetwork.private.name}"
}
output "public_subnetwork_name" {
value = "${google_compute_subnetwork.public.name}"
}

output "public_subnetwork_cidr" {
value = "${google_compute_subnetwork.public.ip_cidr_range}"
}
output "private_subnetwork_cidr" {
value = "${google_compute_subnetwork.private.ip_cidr_range}"
}

output "private_subnetwor_internal_gw" {
value = "${google_compute_subnetwork.private.gateway_address}"
}
output "public_subnetwor_internal_gw" {
value = "${google_compute_subnetwork.public.gateway_address}"
}

output "atc_public_ip" {
value = "${google_compute_address.atc_ip.address}"
}

output "director_account_creds" {
  value = "${base64decode(google_service_account_key.bosh.private_key)}"
}

output "director_public_ip" {
  value = "${google_compute_address.director.address}"
}
output "db_address_self_link" {
  value = "${google_sql_database_instance.director.self_link}"
}

output "db_first_address" {
  value = "${google_sql_database_instance.director.first_ip_address}"
}

output "db_address_ip" {
  value = "${google_sql_database_instance.director.ip_address.0.ip_address}"
}
