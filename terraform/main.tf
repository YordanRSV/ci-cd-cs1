provider "aws" {
    region = "eu-central-1"
}

# VPC

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = { Name = "yordan-vpc"}
}

# the public subnet
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  //map_customer_owned_ip_on_launch = true
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "eu-central-1b"
  tags              = { Name = "public-subnet-b" }
}

#private subnet for web and db
resource "aws_subnet" "web" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-central-1a"
  tags = { Name = "web-subnet"}
}

resource "aws_subnet" "db_a" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "eu-central-1a"
}

resource "aws_subnet" "db_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.4.0/24"
    availability_zone = "eu-central-1b"
    tags = { Name = "db-subnet-b"}
}

#internait gw

resource "aws_internet_gateway" "igw" {
  vpc_id=aws_vpc.main.id
  tags = { Name = "main-igw" }
}

#nat for private sb

resource "aws_eip" "nat" {

}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public.id
}

#route table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

#Route table associations

resource "aws_route_table_association" "public_assoc" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "web_assoc" {
  subnet_id = aws_subnet.web.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_a_assoc" {
  subnet_id = aws_subnet.db_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_b_assoc" {
  subnet_id = aws_subnet.db_b.id
  route_table_id = aws_route_table.private.id
}

#Groups

resource "aws_security_group" "web_sg" {
  name = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 80
    to_port = 80
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

resource "aws_security_group" "db_sg" {
  name = "db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#RDS PostgreSQL

resource "aws_db_instance" "db" {
  identifier = "yordan-db"
  engine = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  db_name = "yordandb"
  username = var.db_username
  password = var.db_password
  skip_final_snapshot = true
  publicly_accessible = false
  storage_encrypted = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name = aws_db_subnet_group.db_subnets.name
}

resource "aws_db_subnet_group" "db_subnets" {
  name = "yordan-db-subnets"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]
}

#ECR Repository

resource "aws_ecr_repository" "app" {
  name = "yordan-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

#ECS Cluster

resource "aws_ecs_cluster" "app_cluster" {
  name = "yordan-app-cluster"
}

#IAM

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement =[{
        Action = "sts:AssumeRole"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app_task" {
  family = "yordan-app-task"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name = "yordan-app"
    image = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    portMappings = [{
        containerPort = 80
        hostPort = 80
    }]
  }])
}

resource "aws_ecs_service" "app_service" {
  name = "yordan-app-service"
  cluster = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.id
  launch_type = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = [aws_subnet.web.id]
    security_groups = [aws_security_group.web_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name = "yordan-app"
    container_port = 80
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_policy]

}

#Load Balancer
resource "aws_lb" "app_lb" {
  name = "yordan-app-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.web_sg.id]
  subnets = [aws_subnet.public.id, aws_subnet.public_b.id]
  tags = { Name = "LoadBalancer-App" }
}

resource "aws_lb_target_group" "app_tg" {
  name = "yordan-app-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
    matcher = "200"
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}