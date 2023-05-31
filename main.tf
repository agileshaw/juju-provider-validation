terraform {
  required_providers {
    juju = {
      version = "~> 0.7.0"
      source  = "juju/juju"
    }
  }
}

provider "juju" {}

# Variables
variable "customer" {
  type = string
}

variable "cloud-name" {
  type = string
}

variable "juju-user" {
  type = string
}

variable "juju-password" {
  type = string
}

variable "controller-url" {
  type = string
}

variable "ssh-key" {
  type = string
}

variable "test-user-password" {
  type = string
}


# Models
resource "juju_model" "development" {
  name = "development"
  config = {
    automatically-retry-hooks = false
  }
}

resource "juju_model" "offer" {
  name = "offer"
  cloud {
    name = "maas_cloud"
  }
}


# Applications
resource "juju_application" "ubuntu" {
  name = "ubuntu-billing"

  charm {
    name = "ubuntu"
    channel = "latest/candidate"
    series = "jammy"
    revision = 23
  }

  units = 3
  model = juju_model.development.name
}

resource "juju_application" "ubuntu2" {
  name = "ubuntu"

  charm {
    name = "ubuntu"
    channel = "latest/stable"
    revision = 24
  }

  placement = juju_machine.test_machine.machine_id

  model = juju_model.development.name
}

resource "juju_application" "pje" {
  name = "prometheus-juju-exporter"

  charm {
    name = "prometheus-juju-exporter"
    channel = "latest/edge"
    series = "jammy"
  }

  config = {
    customer = var.customer
    cloud-name = var.cloud-name
    controller-url = var.controller-url
    juju-user = var.juju-user
    juju-password = var.juju-password
  }

  model = juju_model.development.name
  expose {}
  units = 0
}

resource "juju_application" "prometheus" {
  name = "prometheus"

  charm {
    name = "prometheus2"
  }

  model = juju_model.offer.name
  expose {}
}


// Integrations (relations and offers)
resource "juju_integration" "this" {
  model = juju_model.development.name

  application {
    name     = juju_application.ubuntu.name
  }

  application {
    name     = juju_application.pje.name
  }
}

resource "juju_offer" "scrape" {
  model            = juju_model.offer.name
  application_name = juju_application.prometheus.name
  endpoint         = "scrape"
}

resource "juju_integration" "cmr" {
  model = juju_model.development.name

  application {
    name     = juju_application.pje.name
    endpoint = "prometheus-scrape"
  }

  application {
    offer_url = juju_offer.scrape.url
  }
}


// Machines
resource "juju_machine" "test_machine" {
  model       = juju_model.development.name
  series      = "bionic"
  name        = "test_machine"
  constraints = "tags=my-machine-tag"
  disks       = "5G"
}


// SSH Keys
resource "juju_ssh_key" "mykey" {
  model   = juju_model.development.name
  payload = var.ssh-key
}


// Users
resource "juju_user" "myuser" {
  name   = "test-user"
  password = var.test-user-password
}

# // Access models
resource "juju_access_model" "myaccess" {
  model  = juju_model.development.name
  access = "write"
  users  = [juju_user.myuser.name]
}
