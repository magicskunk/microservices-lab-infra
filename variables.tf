variable "project_name" {
  type    = string
  default = "magicskunk"
}

variable "environment_code" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type = map(any)
}

variable "ecr_repos" {
  type = map(any)
}

variable "availability_zones_count" {
  description = "The number of AZs."
  type        = number
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.1.0.0/22"
}

variable "subnet_cidr_bits" {
  description = "The number of subnet bits for the CIDR. For example, specifying a value 8 for this parameter will create a CIDR with a mask of /24."
  type        = number
  default     = 4 # vpc_cidr (10.1.0.0/22) + 4 = 26 -> 2^6 = 64 addresses
}

locals {
  common_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment_code
  }
}
