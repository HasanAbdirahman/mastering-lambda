variable "region" {
  default = "ap-south-1"
}

variable "vpc_id" {
  description = "VPC where EC2 runs"
}

variable "quarantine_sg_name" {
  default = "quarantine-sg"
}

variable "lambda_name" {
  default = "guardduty-auto-remediator"
}
