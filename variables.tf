# resource 태그에 사용할 변수
variable "name" {
  type        = string
  default     = "terraform-example"
  description = "All resources name incloud this value"
}

# vpc cidr
variable "cidr_block" {
  type    = string
  description = "for vpc cidr"
}

# resource 생성될 기본 region
variable "region" {
  type        = string
  description = "resources create this region"
}

# EC2 보안그룹 ssh 소스 지정을 위한 변수
variable "cidr_block_myIP" {
  type = string
  description = "sg를 위한 내 IP"
}

# codedeploy 변수
variable "codedeploy_tag_key" {
  type = string
  description = "codedeploy에서 태그 매칭에 사용할 key"
}

variable "codedeploy_tag_value" {
  type = string
  description = "codedeploy에서 태그 매칭에 사용할 value"
}

