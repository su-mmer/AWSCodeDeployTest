# ------ provider 정의 ------ #
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  cloud {
    organization = "hee"

    workspaces {
      name = "AWSCodeDeployTest"
    }
  }
}

provider "aws" {
  profile = "my-terraform"  // 로컬 aws profile에 등록한 이름
  region = "${var.region}"

  default_tags {
    tags = {
      Name = "${var.name}"
    }
  }
}

# ------ AWS VPC ------ #
resource "aws_vpc" "tfcd-vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = "${var.name}-vpc"
  }
}

// subnet
resource "aws_subnet" "public-2a" {
  vpc_id            = aws_vpc.tfcd-vpc.id
  cidr_block        = "10.0.180.0/28"
  availability_zone = "${var.region}a"

  tags = {
    Name = "${var.name}-subnet"
  }
}

# igw
resource "aws_internet_gateway" "tfcd_igw" {
  vpc_id = aws_vpc.tfcd-vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# routing table 생성 - public subnet, igw 연결
resource "aws_route_table" "tfcd_route" {
  vpc_id = aws_vpc.tfcd-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tfcd_igw.id
  }

  tags = {
    Name = "${var.name}-public_rt"
  }
}

# routing table에 public subnet 추가
resource "aws_route_table_association" "routing_a" {
  subnet_id      = aws_subnet.public-2a.id
  route_table_id = aws_route_table.tfcd_route.id
}

# ------ Security Group ------ #
resource "aws_security_group" "ec2-default" {
  vpc_id = aws_vpc.tfcd-vpc.id
  name        = "ec2-default"
  description = "ec2 security group"

  tags = {
    Name = "${var.name}-ec2"
  }
}

# 보안그룹에 들어갈 규칙 생성
# resource "aws_security_group_rule" "ingress" {  // 인바운드 트래픽
#   for_each          = var.inbound_rules  // 
#   type              = "ingress"  // inbound 트래픽
#   from_port         = each.value.from_port  // 시작 포트
#   to_port           = each.value.to_port  // 마지막 포트
#   protocol          = each.value.protocol  // 프로토콜 방식
#   cidr_blocks       = [each.value.cidr_block]  // 허용 IP 범위
#   description       = each.value.description  // 설명
#   security_group_id = aws_security_group.security_group.id  // 생성한 보안그룹에 보안그룹의 id를 이용해 규칙과 연결
# }

resource "aws_security_group_rule" "sg_ec2_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.ec2-default.id
}

resource "aws_security_group_rule" "sg_ec2_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.ec2-default.id
}

resource "aws_security_group_rule" "sg_ec2_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "TCP"
  cidr_blocks = [ "${var.cidr_block_myIP}" ]
  security_group_id        = aws_security_group.ec2-default.id
}

resource "aws_security_group_rule" "sg_ec2_tomcat" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.ec2-default.id
}

resource "aws_security_group_rule" "sg_ec2_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.ec2-default.id
}

# ------ AWS IAM ------ #
# EC2 S3 접근 권한을 위한 IAM 생성
// s3 접근 정책 불러오기
data "aws_iam_policy" "IAM_S3FullAccess" {
  name = "AmazonS3FullAccess"
}
// IAM 역할 생성
resource "aws_iam_role" "ec2_iam_role" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
// IAM role 과 policy 연결
resource "aws_iam_role_policy_attachment" "ec2_iam_role-attach" {
  role       = aws_iam_role.ec2_iam_role.name
  policy_arn = data.aws_iam_policy.IAM_S3FullAccess.arn
}
// IAM instance profile 생성, IAM role과 연결
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.ec2_iam_role.name
}
// IAM instance profile에 연결할 policy 불러오기
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# CodeDeploy를 위한 IAM 생성
// CodeDeploy를 위한 정책 불러오기
data "aws_iam_policy" "IAM_CodeDeploy" {
  name = "AWSCodeDeployRole"
}

data "aws_iam_policy_document" "cd_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

// IAM 역할 생성
resource "aws_iam_role" "codedeploy_iam_role" {
  name               = "${var.name}-cd-role"
  assume_role_policy = data.aws_iam_policy_document.cd_assume_role.json
}
// IAM role 과 policy 연결
resource "aws_iam_role_policy_attachment" "cd_iam_role_attach" {
  role       = aws_iam_role.codedeploy_iam_role.name
  policy_arn = data.aws_iam_policy.IAM_CodeDeploy.arn
}

# GitAction을 위한 IAM 사용자 생성
// GitAction을 위한 정책 불러오기
data "aws_iam_policy" "policy_s3_Git" {
  name = "AmazonS3FullAccess"
}

data "aws_iam_policy" "policy_cd_Git" {
  name = "AWSCodeDeployFullAccess"
}

// IAM 사용자 생성
resource "aws_iam_user" "gitaction_user" {
  name = "${var.name}-git-user"

  tags = {
    Name = "${var.name}-git-user"
  }
}
// 사용자 key 생성
resource "aws_iam_access_key" "gitaction_user_key" {
  user = aws_iam_user.gitaction_user.name
}
// IAM role 과 policy 연결
resource "aws_iam_user_policy_attachment" "git-s3-attach" {
  user       = aws_iam_user.gitaction_user.name
  policy_arn = data.aws_iam_policy.policy_s3_Git.arn
}

resource "aws_iam_user_policy_attachment" "git-cd-attach" {
  user       = aws_iam_user.gitaction_user.name
  policy_arn = data.aws_iam_policy.policy_cd_Git.arn
}

# ------ EC2 생성 ------ #
// EC2 접근을 위한 pem key
data "aws_key_pair" "mykey" {
  key_name = "hhkey"
  include_public_key = true
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "image-id"
    values = ["ami-086cae3329a3f7d75"]  # ubuntu 22.04
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
// EC2에 붙일 EIP 생성
resource "aws_eip" "instance_eip" {
  instance = aws_instance.myinstance.id

  tags = {
    Name = "${var.name}-ec2"
  }
}
// EC2 생성
resource "aws_instance" "myinstance" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public-2a.id
  vpc_security_group_ids = [ aws_security_group.ec2-default.id ]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.id  #! 가능?
  key_name = data.aws_key_pair.mykey.key_name

user_data = <<-EOF
  #!/bin/bash
  sudo apt update
  sudo apt-get install -y openjdk-11-jdk
  sudo apt install ruby-full -y
  sudo apt install wget
  cd /home/ubuntu
  wget https://aws-codedeploy-ap-northeast-2.s3.ap-northeast-2.amazonaws.com/latest/install
  sudo chmod +x ./install
  sudo ./install auto
  EOF

  tags = {
    Name = "${var.name}-instance"
    "${var.codedeploy_tag_key}" = "${var.codedeploy_tag_value}"
  }
}

# ------ S3 ------ #
// private bucket
resource "aws_s3_bucket" "cicd_bucket" {
  bucket = "${var.name}-cicd-bucket-hh"
  force_destroy = true

  tags = {
    Name   = "${var.name}-s3"
  }
}

# ------ Code Deploy 생성 ------ #
resource "aws_codedeploy_app" "tf_codedeploy" {
  compute_platform = "Server"
  name             = "${var.name}-app"
}

resource "aws_codedeploy_deployment_group" "tf_cd_group" {
  app_name              = aws_codedeploy_app.tf_codedeploy.name
  deployment_group_name = "${var.name}-group"
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  service_role_arn      = aws_iam_role.codedeploy_iam_role.arn

  ec2_tag_filter {
    key   = "${var.codedeploy_tag_key}"
    type  = "KEY_AND_VALUE"
    value = "${var.codedeploy_tag_value}"
  }

  auto_rollback_configuration {  // 배포 실패 시 롤백
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}
