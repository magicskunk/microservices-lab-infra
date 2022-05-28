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
  default     = 2
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_bits" {
  description = "The number of subnet bits for the CIDR. For example, specifying a value 8 for this parameter will create a CIDR with a mask of /24."
  type        = number
  default     = 8
}

locals {
  common_tags = {
    "Project"     = project_name
    "Environment" = environment_code
  }
}
