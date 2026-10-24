variable "subscription_id" {
  type        = string
  description = "Subscription to deploy into (set by the pipeline through TF_VAR_subscription_id)."
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "name_prefix" {
  type    = string
  default = "basiclab"
}

variable "address_space" {
  type    = list(string)
  default = ["10.30.0.0/16"]
}

variable "subnet_prefix" {
  type    = string
  default = "10.30.1.0/24"
}
