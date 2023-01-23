data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_vpc" "desired_vpc" {
  id = var.vpc_id
}

# NOTES: Must configure preferences in Systems manager Console after deploying- use the resources created to fill in KMS ID and CloudWatch Logs Group
variable "private_subnet"{
  type        = bool
  description = "Conditional variable to determine if the EC2 instance is deployed in a private subnet. Set to TRUE if it is."
  default     = false
}


variable "tags" {    
  description = "Common tags that should be used on specific resources"
  type        = map(string)
}

variable "ssm_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

variable "cloudwatch_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"

}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to deploy the infrastructure."
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "ID of subnet to deploy the instance in."
  default     = ""
}


variable "ami" {
  type        = string
  description = "AMI for the EC2:"
  default     = ""
}

variable "instance_type" {
  type        = string
  description = "Type of instance to be created:"
  default     = ""
}

variable "ssm_role" {
  type        = string
  description = "The name of the role to be assigned to the instance profile:"
  default     = ""
}

variable "team" {
  type        = string
  description = "Name of your team to be appended to the SSM Instance Profile:"
  default     = ""
}

variable "security_group" {
  description = "Name of the security group to attach to the instance"
  type        = string
  default     = ""
}

variable "s3_bucket" {
  type        = string
  description = "Name of the S3 bucket for S3 server side logging of session manager sessions"
  default     = ""
}

variable "s3_log_bucket_id" {
  type        = string
  description = "Name of the S3 logging bucket to deliver S3 server logs to. BUCKET MUST BE EXISTING!"
  default     = ""
}

