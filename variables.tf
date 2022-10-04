variable "component_name" {
  type    = string
  default = "jenkins-agent"
}

variable "container_name" {
  type    = string
  default = "master-agent"
}

variable "image_name" {
  type    = string
  default = "jenkins-release-image"
}

variable "image_version" {
  type    = string
  default = "latest"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "worker_nodePort" {
  type    = number
  default = 50000
}

variable "dns_zone_name" {
  type = string
}

variable "subject_alternative_names" {
  type = list(any)
}