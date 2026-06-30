output "ecr_repository_url" {
  value = aws_ecr_repository.devops_api.repository_url
}
output "instance_public_ip" {
  value = aws_instance.devops_api_server.public_ip
}