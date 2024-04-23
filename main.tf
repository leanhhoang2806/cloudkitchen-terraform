variable "db_username" {}
variable "db_password" {}
variable "s3_env_path" {}
variable "POSTGRES_DATABASE_URL_CONNECTION_STRING" {}
variable "AUTH0_ISSUER" {}
variable "API_IDENTIFIER" {}
variable "STRIPE_API_KEY" {}
variable "S3_ONLY_AWS_ACCESS_KEY_ID" {}
variable "S3_ONLY_AWS_SECRET_ACCESS_KEY" {}
variable "AWS_ACCESS_KEY_ID" {}
variable "AWS_SECRET_ACCESS_KEY" {}

provider "aws" {
  region = "us-east-1" # Update with your desired region
}
resource "aws_iam_user" "popo24_user" {
  name = "popo24_user"

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_ecr_full_access" {
  name       = "ecs_task_execution_role_policy_ecr_full_access"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  lifecycle {
    ignore_changes = [
      users,
    ]
  }
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_ecs_task_execution_role_policy" {
  name       = "ecs_task_execution_role_policy_ecs_task_execution_role_policy"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_ecr_public_full_access" {
  name       = "ecs_task_execution_role_policy_ecr_public_full_access"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicFullAccess"

}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_s3_full_access" {
  name       = "ecs_task_execution_role_policy_s3_full_access"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  lifecycle {
    ignore_changes = [
      users,
    ]
  }
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_elb_full_access" {
  name       = "ecs_task_execution_role_policy_elb_full_access"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_s3_bucket" "popo24_public_read_images" {
  bucket = "popo24-public-read-images" # Bucket name

  tags = {
    Name = "popo24-public-read-images"
  }
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.popo24_public_read_images.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.popo24_public_read_images.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_policy" "popo24_public_read_images_policy" {
  bucket = aws_s3_bucket.popo24_public_read_images.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource = [
          "${aws_s3_bucket.popo24_public_read_images.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_security_group" "LoadBalancer-sg" {
  name        = "LoadBalancer-sg"
  description = "Security group for load balancer"

  # Allow HTTPS and HTTP traffic from the internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ElasticContainerService-sg" {
  name        = "ElasticContainerService-sg"
  description = "Security group for Elastic Container Security"

  # Allow traffic only from LoadBalancer-sg security group
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.LoadBalancer-sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "FromAnyWhereToPostgresDB" {
  name        = "FromAnyWhereToPostgresDB"
  description = "Security group to allow all traffic to PostgreSQL RDS instance"

  # Allow all inbound traffic to PostgreSQL port (default: 5432) from any source
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "custom_pg_parameter_group" {
  name        = "custom-pg-parameter-group"
  family      = "postgres16"
  description = "Custom parameter group for PostgreSQL RDS instance"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Add any additional parameters here if needed
}

resource "aws_db_instance" "postgres_instance" {
  identifier             = "popo24-db" # This is where you specify the name
  allocated_storage      = 20          # Storage in GB
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro" # Make sure it falls within the Free Tier
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.custom_pg_parameter_group.name
  vpc_security_group_ids = [aws_security_group.FromAnyWhereToPostgresDB.id]
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name = "My PostgreSQL RDS Instance"
  }
}


resource "aws_ecr_repository" "popo24_ecr" {
  name = "popo24_ecr"
}


resource "aws_ecs_task_definition" "popo24_task_definition" {
  family                   = "popo24-ecs-task"
  cpu                      = 1024
  memory                   = 2048
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "popo24-container"
      image     = "${aws_ecr_repository.popo24_ecr.repository_url}:latest"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 8000,
          hostPort      = 8000,
          protocol      = "tcp",
          appProtocol   = "http"
        }
      ],
      environment = [
        {
          name  = "S3_ONLY_AWS_ACCESS_KEY_ID",
          value = var.S3_ONLY_AWS_ACCESS_KEY_ID
        },
        {
          name  = "S3_ONLY_AWS_SECRET_ACCESS_KEY",
          value = var.S3_ONLY_AWS_SECRET_ACCESS_KEY
        },
        {
          name  = "POSTGRES_DATABASE_URL_CONNECTION_STRING",
          value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres_instance.address}:5432/popo_24"
        },
        {
          name  = "AUTH0_ISSUER",
          value = var.AUTH0_ISSUER
        },
        {
          name  = "API_IDENTIFIER",
          value = var.API_IDENTIFIER
        },
        {
          name  = "STRIPE_API_KEY",
          value = var.STRIPE_API_KEY
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/popo24-ecs-task"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}


resource "aws_ecs_cluster" "popo24_cluster" {
  name = "popo24-cluster"
}


data "aws_vpc" "current" {
  default = true
}

resource "aws_ecs_service" "popo24_ecs_service" {
  name            = "popo24-ecs"
  cluster         = aws_ecs_cluster.popo24_cluster.id
  task_definition = aws_ecs_task_definition.popo24_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Adjust as needed
  network_configuration {
    subnets = [
      "subnet-0e071f0feb21b6507", # Manually provided subnet
      "subnet-0a47da0de09037732",
      "subnet-0439863a3b4c3d5d0",
      "subnet-03c335ec5cfeb0e00",
      "subnet-0519201d2028a7ffd",
      "subnet-0af6cc7117f41d57d"
    ]
    security_groups  = [aws_security_group.ElasticContainerService-sg.id]
    assign_public_ip = true # set to true for debugging purposes only
  }


  load_balancer {
    target_group_arn = aws_lb_target_group.popo24_target_group.arn
    container_name   = "popo24-container" // Replace with your container name
    container_port   = 8000               // Replace with your container port
  }

}

resource "aws_lb_target_group" "popo24_target_group" {
  name     = "popo24-target-group"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.current.id

  target_type = "ip" # Set the target type to "ip" for Fargate launch type

  health_check {
    path                = "/api/v1/health"
    protocol            = "HTTP"
    port                = 8000
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }
}


resource "aws_lb" "popo24_alb" {
  name               = "popo24-alb"
  load_balancer_type = "application"
  subnets = [
    "subnet-0e071f0feb21b6507",
    "subnet-0a47da0de09037732",
    "subnet-0439863a3b4c3d5d0",
    "subnet-03c335ec5cfeb0e00",
    "subnet-0519201d2028a7ffd",
    "subnet-0af6cc7117f41d57d"
  ]
  security_groups = [aws_security_group.LoadBalancer-sg.id]
}

resource "aws_lb_listener" "popo24_alb_listener" {
  load_balancer_arn = aws_lb.popo24_alb.arn
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.popo24_target_group.arn
  }
}

