# AWSCodeDeployTest
AWS CodeDeploy 사용을 위한 인프라 작업 레포지토리입니다.

- Terraform을 사용해 인프라를 구축합니다.
- Terraform v1.5.6 사용
- AWS profile 사용

### terraform.tfvars 파일 구성
- cidr_block_myIP
- region
- codedeploy_tag_key
- codedeploy_tag_value
- cidr_block

## 동작 순서
```
# 초기 setting
terraform init

# 생성
terraform apply

# 삭제
terraform destroy
```