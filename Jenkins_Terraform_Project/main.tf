resource "aws_instance" "Jenkins_Project_Instance" {
    ami = data.aws_ami.Amazon_Linux_AMI_Lookup.id
    instance_type = var.instance_type

    key_name = aws_key_pair.Jenkins_Instance_SSH_Key.key_name

    vpc_security_group_ids = [aws_security_group.ssh_sg.id]

    iam_instance_profile = aws_iam_instance_profile.jenkins_instance_profile.name

    tags = {
        Name = "Jenkins_Project_Instance"
    }

    user_data = <<-EOF
    #!/bin/bash
    set -xe
    dnf update -y
    dnf install -y java-17-amazon-corretto curl
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    curl -o /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    dnf install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins
    EOF
}

resource "aws_key_pair" "Jenkins_Instance_SSH_Key" {
    key_name = var.key_name
    public_key = file(var.public_key_path)
}

data "aws_ami" "Amazon_Linux_AMI_Lookup" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["al2023-ami-*-x86_64"]
    }
}

data "aws_vpc" "default" {
    default = true
}

resource "aws_security_group" "ssh_sg" {
    name = "Jenkins_Sg"
    description = "Allow SSH and HTTP traffic"
    vpc_id = data.aws_vpc.default.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_s3_bucket" "jenkins_artifacts" {
    bucket = var.artifacts_bucket_name
    tags = {
        Name = "jenkins-artifacts-bucket"
    }
}

resource "aws_s3_bucket_public_access_block" "jenkins_artifacts_block" {
    bucket = aws_s3_bucket.jenkins_artifacts.id

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "jenkins_artifacts_encrypt" {
    bucket = aws_s3_bucket.jenkins_artifacts.id

    rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
    }
}

data "aws_iam_policy_document" "jenkins_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "jenkins_role" {
    name = "jenkins-ec2-role"
    assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json
}

data "aws_iam_policy_document" "jenkins_s3_policy_doc" {
    statement {
        actions = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
        ]
        resources = [
            "${aws_s3_bucket.jenkins_artifacts.arn}/*"
        ]
    }

    statement {
        actions = [
            "s3:ListBucket"
        ]
        resources = [
            aws_s3_bucket.jenkins_artifacts.arn
        ]
    }
}

resource "aws_iam_policy" "jenkins_s3_policy" {
    name = "jenkins-s3-artifacts-policy"
    policy = data.aws_iam_policy_document.jenkins_s3_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "jenkins_s3_attach" {
    role = aws_iam_role.jenkins_role.name
    policy_arn = aws_iam_policy.jenkins_s3_policy.arn
}

resource "aws_iam_instance_profile" "jenkins_instance_profile" {
    name = "jenkins-ec2-instance-profile"
    role = aws_iam_role.jenkins_role.name
}

output "jenkins_instance_public_ip" {
  description = "Public IP of the Jenkins EC2 instance"
  value       = aws_instance.Jenkins_Project_Instance.public_ip
}

output "jenkins_url" {
  description = "URL to access Jenkins once the server is ready"
  value       = "http://${aws_instance.Jenkins_Project_Instance.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i C:/Users/Michael/Desktop/my-jenkins-key ec2-user@${aws_instance.Jenkins_Project_Instance.public_ip}"
}