variable "aws_region" {
    description = "AWS region"
    type = string
    default = "us-east-2"
}

variable "aws_profile" {
    description = "AWS CLI/SDK profile to use for authentication"
    type = string
    default = "default"
}

variable "instance_type" {
    description = "EC2 instance type"
    type = string
    default = "t2.micro"
}

variable "key_name" {
    description = "Name of EC2 key pair to create/use"
    type = string
    default = "my-jenkins-project-key"
}

variable "public_key_path" {
    description = "Path to public key file for key pair"
    type = string
    default = "C:/Users/Michael/Desktop/my-jenkins-key.pub"
}

variable "artifacts_bucket_name" {
    description = "Name of the S3 bucket for Jenkins artifacts"
    type = string
    default = "jenkins-project-bucket-2468101214161820"
}