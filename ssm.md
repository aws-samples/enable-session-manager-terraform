## AWS Systems Manager Session Manager

[Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) is a fully managed AWS Systems Manager capability. With Session Manager, you can manage your Amazon Elastic Compute Cloud (Amazon EC2) instances, edge devices, and on-premises servers and virtual machines (VMs). You can use either an interactive one-click browser-based shell or the AWS Command Line Interface (AWS CLI). Session Manager provides secure and auditable node management without the need to open inbound ports, maintain bastion hosts, or manage SSH keys. Session Manager also gives teams the ability to centralize logging for connections made to your nodes or the actions that were taken on them. 

![ssm_flow](ssm-flow.png)

#### Setting up Session Manager

The process for [setting up Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started.html) is simple, so long as your team is using an EC2 AMI that has the SSM agent preinstalled.  If your are using in AMI that does not have the SSM agent preinstalled, you can install it following [these instructions](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-manual-agent-install.html). Below is the Terraform code required to create an AWS Role for an EC2 Instance Profile, create an EC2 instance and attach that profile, and send SSM Session manager logs to a CloudWatch Logs group for analysis. 

#### Enable settings for Session Manager in Systems Manager
* Option 1 (PREFERRED): You can configure your account settings for Session Manager through the AWS Console.  There are major limitations to updating the preferrences in Terraform, so customers should follow the steps to complete this in the console. If leveraging the S3 bucket and CloudWatch log group created in this module, configure those portions of the preferences after deployment. 

Enable settings through the console: 
1. In the AWS Console, navigate to "AWS Systems Manager".
2. On the left navigation pane, select "Session Manager".
3. Select the "Configure Preferences" tab and click "edit".
4. Check the box labeled "CloudWatch Logging" and select the CloudWatch Logs group you want to send session logs to. (If you are creating a new group as 
part of this Terraform template, you will need to perform this step after running Terraform apply)
5. Click "Save".

* Option 2: Enable settings in Terraform: 
*NOTE:*  If you are not centralizing the logs in both S3 and CloudWatch Logs, you can modify the settings as needed. 

```json
resource "aws_ssm_document" "session_manager_prefs" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = <<DOC
{
    "schemaVersion": "1.0",
    "description": "SSM document to house preferences for session manager",
    "sessionType": "Standard_Stream",
    "inputs": {
        "s3BucketName": "${aws_s3_bucket.ssm_s3_bucket.id}",
        "s3KeyPrefix": "AWSLogs/${data.aws_caller_identity.current.account_id}/ssm_session_logs",
        "s3EncryptionEnabled": false,
        "cloudWatchLogGroupName": "${aws_cloudwatch_log_group.ssm_logs.name}",
        "cloudWatchEncryptionEnabled": false,
        "runAsEnabled": false,
        "kmsKeyId": "${var.ssm_kms_key_id}",
        "cloudWatchStreamingEnabled": true,
        "idleSessionTimeout": "20"
    }
}
DOC
}
```
#### Add Providers to the Module
In order for Terraform to interact with AWS, you need to configure AWS as a [provider](https://www.terraform.io/language/providers) for your Terraform module.  
```json
terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    }
  }
}
```

#### Declare the required variables for your Terraform
These variables can and should be tailored to each teams use case.  The policy ARN's will remain the same, as those are the AWS managed policies that give the Instance Profile SSM and CloudWatch access.

```json
variable "tags" {
    default = {
        AppID = "some_string"
        DataType = "Sensitive"
    }
    description = "Tags that should be included in every S3 bucket"
    type = map(string)
}

variable "vpc_id" {
  type = string
  description = "The ID of the VPC to deploy the infrastructure."
  default = ""
}

variable "subnet_id" {
  type = string
  description = "ID of subnet to deploy the instance in."
  default = ""
}

variable "ssm_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

variable "cloudwatch_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

variable "ami" {
  type    = string
  description = "AMI for the EC2:"
  default = "ami-0f9fc25dd2506cf6d"
}

variable "instance_type" {
  type    = string
  description = "Type of instance to be created:"
  default = "t2.micro"
}

variable "ssm_role" {
    type = string
    description = "The name of the role to be assigned to the instance profile:"
    default = "ssm-ec2-role"
}

variable "team" {
    type = string
    description = "Name of your team to be appended to the SSM Instance Profile:"
    default = ""
}

variable "ec2_kms_key_id" {
  type = string 
  description = "Arn of the KMS key to encrypt the EBS volume on the EC2:"
  default = ""
}

variable "security_group" {
    description = "Name of the security group to attach to the instance"
    type = string
    default = "https-allow"
}

variable "s3_bucket" {
  type = string
  description = "Name of the S3 bucket for logs"
  default = ""
}

variable "s3_log_bucket_id" {
  type = string
  description = "Name of the S3 logging bucket"
  default = ""
}

```
#### Declare your Data Sources
You also need to declare data resources in order to export configuration details of your AWS resources.  Note: In the ```aws_vpc``` data resource, input your VPC ID in the ```vpc_id``` variable. 
```json
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_vpc" "desired_vpc" {
  id = var.vpc_id
}
```
#### Create the AWS Role and grant EC2 access to assume the role

This will be the role used as the Instance Profile.  This Terrafrom creates the role and gives the EC2 service permission to assume to role to perform functions in the account. The variables can be modified to fit your use case and role naming convention. 

```json
resource "aws_iam_role" "ssm_role" {
  name = "${var.ssm_role}-${var.team}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    ssmdemo = "true"
  }
}
```

#### Create a Policy to allow EC2 to place objects in a specified bucket
```json
resource "aws_iam_policy" "ec2_policy" {
  name        = "ssm_logs_policy_${data.aws_region.current.name}_${data.aws_caller_identity.current.account_id}"
  description = "Policy allowing put and get operations for ec2 to place session logs in specified bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
          
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.ssm_s3_bucket.arn}/*"
      },
    ]
  })
}
```
#### Create KMS Policy for Role
Create a policy that allows the EC2 instance role to use the EC2 KMS key to encrypt and decrypt data with that key.

```json
data "aws_iam_policy_document" "kms_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:decrypt",
      "kms:encrypt"
      ]
    resources = [var.ec2_kms_key_id]
  }
}

resource "aws_iam_policy" "kms_policy" {
  policy = data.aws_iam_policy_document.kms_policy.json
  name = "kms-ssm-allow"
}
```

#### Attach AWS policies to the newly created role

You need to grant the role access to SSM and CloudWatch to be able to communicate with Session Manager and send log data to CloudWatch. These two policy attachment statements attach AWS managed policies for SSM and CloudWatch. 

```json
resource "aws_iam_policy_attachment" "s3_attach" {
  name = "ssm-attach"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = aws_iam_policy.ec2_policy.arn
  
}
resource "aws_iam_policy_attachment" "ssm-attach" {
  name       = "managed-ssm-policy-attach"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = var.ssm_policy_arn
}

resource "aws_iam_policy_attachment" "cloudwatch-attach" {
  name       = "managed-cloudwatch-policy-attach"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = var.cloudwatch_policy_arn
}

resource "aws_iam_policy_attachment" "kms-attach" {
  name       = "inline-kms-policy-attach"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = aws_iam_policy.kms_policy.arn
}
```

#### Create an AWS Instance Profile from the role

Next, you need to create the actual Instance Profile from the role you just created to be attached to the EC2 instance. 

```json
resource "aws_iam_instance_profile" "ssm_profile" {
    name = "ssm-demo-profile-${var.team}"
    role = aws_iam_role.ssm_role.name
}
```

#### Create the Instance and security group

The next step will be creating the EC2 instance and security group.  By default, Terraform will assign the default security group to your instance if one is not specified.  As a best practice, access should be granted on a least privledge basis.  Session Manager inititates a connection through HTTPS and requires outbound HTTPS access. In order for Session Manager to function, you need to create a security group with outbound HTTPS to 0.0.0.0/0.  *Note: The variables for instance type and AMI can be modified to fit your unique use case*. 

```json
resource "aws_instance" "ssm_instance" {
  ami           = var.ami
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.http_allow.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  monitoring = true
  subnet_id = var.subnet_id
  tags = merge(
      var.tags, 
      {
          Name = "cloud-security-ec2"
      }
  )

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens = "required"
    http_endpoint = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags = "disabled"
  }
}
```
```json
resource "aws_security_group" "http_allow" {
    name = var.security_group
    description = "Security group to allow traffic over HTTPS 443"
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "allow outbound traffic over 443"
    }
    vpc_id = var.vpc_id
    
}
```

#### Create KMS Key and permissions
Create a Key that will be used to encrypt your CloudWatch Log Group
```json
data "aws_iam_policy_document" "ssm_kms_access" {
    statement {
      sid = "KMSPolicyAllowIAMManageAccess"
      principals {
          type = "AWS"
          identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
      actions = ["kms:*"]
      resources = ["*"]
    }
    statement {
      sid = "AllowCloudWatchLogsKMS"
      principals {
          type = "Service"
          identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
      }
      actions = [
      "kms:Decrypt*",
      "kms:Describe*",
      "kms:Encrypt*",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
      ]
      resources = ["*"]
    }
}

resource "aws_kms_key" "ssm_access_key" {
	description = "Key used to grant access for ssm logs"
	policy = data.aws_iam_policy_document.ssm_kms_access.json
	enable_key_rotation = true 
	deletion_window_in_days = 30
}
```
#### Create the CloudWatch Logs group

Next, you need to create a CloudWatch Logs group to send the session logs to.  Please Note: It is a security best practice to encrypt all log files at rest.  Teams should follow the approved encryption pattern to enable these logs in CloudWatch. 

```json
resource "aws_cloudwatch_log_group" "ssm_logs" {
    name_prefix = "ssm-log-group-"
    retention_in_days = 30
    kms_key_id = aws_kms_key.ssm_access_key.arn
}
```
#### Create the S3 bucket to store session logs

You'll also create an S3 bucket to store the session logs.  In this Terraform, encyrption is enabled via SSE-S3 using AES 256. 

```json
resource "aws_s3_bucket" "ssm_s3_bucket" {
  bucket              = "secure-ssm-s3"
  object_lock_enabled = true
  tags = {
    name     = "ssm-logs"
    DataType = "SENSITIVE"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encrypt" {
  bucket = aws_s3_bucket.ssm_s3_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}
```
#### Managing Infrastructure changes in Terraform
Once you've modified the variables to reflect your specifications, you can push the changes to your AWS account.  In order to do this, you need to first navigate to the directory where the module resides via command line. From there you can: 

Run ```terraform plan``` to give a breakdown of all the infrastructure changes you'll be making in the account. 

Once you validate that the changes in the plan are what you expect to happen to the infrastructure, run ```terraform apply``` to apply all the changes in your account. 

If the infrastructure is no longer needed in the account, you can delete the Terraform-based components by running ```terraform destroy```.

After completing these steps, you should be able to log into your EC2 instance via AWS Systems Manager Session Manager and have your session logs centralized in an AWS CloudWatch Logs group. You can do this by logging into the AWS Console and selecting "connect" on your newly created instance, or through the AWS CLI.  

To use the AWS CLI to run session commands, the Session Manager plugin must also be installed on your local machine. For information, see (Optional) [Install the Session Manager plugin for the AWS CLI.](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

The CLI command to connect is: 
```
aws ssm start-session \
      --target <instance-id>
```
