output "ec2_EIP" {
  value = aws_eip.instance_eip.public_ip  // EC2에 접속할 Public IP 출력
}

output "iam_access_key_id" {
  description = "The access key ID"
  value       = aws_iam_access_key.gitaction_user_key.id  // Git action에 추가할 AC
}

output "secret" {
  description = "The access key ID"
  value = aws_iam_access_key.gitaction_user_key.secret  // Git action에 추가할 SK
  sensitive = true
}

output "s3" {
  description = "s3 bucket name"
  value = aws_s3_bucket.cicd_bucket.id
}

output "aws_codedeploy_app" {
  description = "codedeploy app name"
  value = aws_codedeploy_app.tf_codedeploy.name
}

output "aws_codedeploy_group" {
  description = "codedeploy group name"
  value = aws_codedeploy_deployment_group.tf_cd_group.deployment_group_name
}