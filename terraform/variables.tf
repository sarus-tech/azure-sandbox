variable "prefix" {
  # "The prefix which should be used for all resources in this example"
  description = "test-vl-sarus"
  default = "sarus-sandbox-terraform"
}

variable "location" {
  # "The Azure Region in which all resources in this example should be created."
  description =  "West Europe"
  default = "West Europe"
}
variable "SARUS_RELEASES_USERNAME" {
  description =  "Username to access Sarus releases project"
}

variable "SARUS_RELEASES_PASSWORD" {
  description =  "Password to access Sarus releases project"
}
