
terraform {
  required_version = ">=1.1.5"

  backend "s3" {
    bucket         = "kojitechs-deploy-vpcchildmodule.tf-12"
    dynamodb_table = "terraform-lock"
    key            = "path/env/jenkins_stables"
    region         = "us-east-1"
    encrypt        = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = local.required_tags
  }
}

locals {
  required_tags = {
    line_of_business        = "hospital"
    ado                     = "max"
    tier                    = "WEB"
    operational_environment = upper(terraform.workspace)
    tech_poc_primary        = "udu.udu25@gmail.com"
    tech_poc_secondary      = "udu.udu25@gmail.com"
    application             = "http"
    builder                 = "udu.udu25@gmail.com"
    application_owner       = "kojitechs.com"
    vpc                     = "WEB"
    cell_name               = "WEB"
    component_name          = var.component_name
  }
  azs            = data.aws_availability_zones.available.names
  vpc_id         = module.networking.vpc_id
  public_subnet  = module.networking.public_subnets
  private_subnet = module.networking.private_subnets
  account_id     = data.aws_caller_identity.current.account_id
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# module "networking" {
#   source = "git::https://github.com/gerried/operational_environment_network"

#   vpc_cidr         = ["10.0.0.0/16"]
#   pub_subnet_cidr  = ["10.0.0.0/24", "10.0.2.0/24"]
#   pub_subnet_az    = local.azs
#   priv_subnet_cidr = ["10.0.1.0/24", "10.0.3.0/24"]
#   priv_subnet_az   = local.azs
# }

module "networking" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.component_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.3.0/24", "10.0.5.0/24"]
  public_subnets  = ["10.0.0.0/24", "10.0.2.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true
  enable_dns_hostnames = true

  enable_flow_log = true
  create_flow_log_cloudwatch_iam_role = true
  create_flow_log_cloudwatch_log_group = true


}

resource "aws_cloudwatch_log_group" "ecs_task_logs" {
  name = "/ecs/jenkins_build_agent/${var.container_name}"

  tags = {
    Name = "ecs/jenkins_build_agent/${var.container_name}"
  }
}

resource "aws_ecs_task_definition" "jenkins" {
  family = "${var.container_name}-task-def"

  requires_compatibilities = [
    "FARGATE",
  ]
  execution_role_arn = aws_iam_role.iam_for_ecs.arn
  task_role_arn      = aws_iam_role.iam_for_ecs.arn
  network_mode       = "awsvpc"
  cpu                = 1024 # 8 Gi
  memory             = 2048 # 4 Gi
  container_definitions = jsonencode([
    {
      name = var.container_name
      image = format("%s.dkr.ecr.us-east-1.amazonaws.com/%s:%s",
        local.account_id,
        var.image_name,
        var.image_version
      )
      essential = true
      mountPoints = [
        {
          containerPath = "/var/jenkins_home"
          sourceVolume  = "${var.component_name}-jenkins-agent"
          readOnly = false
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ecs_task_logs.name}",
          awslogs-region        = "${data.aws_region.current.name}",
          awslogs-stream-prefix = "${aws_cloudwatch_log_group.ecs_task_logs.name}-jenkins-build-agent"
        }
      },
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        },
        {
          containerPort = var.worker_nodePort
          hostPort      = var.worker_nodePort
        }
      ]
    }
  ])

  volume {
    name = "${var.component_name}-jenkins-agent"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.jenkins.id
      root_directory          = "/opt/data"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.fargate.id
        iam             = "ENABLED"
      }
    }
  }
}

resource "aws_ecs_cluster" "jenkins" {
  name = upper("buld-agnet")

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "jenkins" {

  name             = upper("${var.component_name}-service")
  cluster          = "BULD-AGNET" # aws_ecs_cluster.jenkins.id
  task_definition  = aws_ecs_task_definition.jenkins.arn
  desired_count    = 1
  platform_version = "1.4.0"
  launch_type      = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.jenkins_agnet.id]
    subnets          = local.private_subnet
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jenkins_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }
}
