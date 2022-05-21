variable "product_name" {
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
