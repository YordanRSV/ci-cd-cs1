output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.web.id, aws_subnet.db_a.id, aws_subnet.db_b.id]
}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

output "alb_arn" {
  value = aws_lb.app_lb.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.app_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app_service.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.db.address
} 