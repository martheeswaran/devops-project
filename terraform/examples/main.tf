terraform {
  required_version = "= 0.11.8"
}

provider "aws" {
  version = ">= 1.17.0"
  region  = "${var.region}"
}
