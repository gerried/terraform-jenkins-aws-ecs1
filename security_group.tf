
resource "aws_security_group" "alb_sg" {
  name        = "${var.component_name}-alb"
  description = "Allow http and https inbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    description = "https from to anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http from to anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.component_name}-alb"
  }
}

resource "aws_security_group" "efs" {
  name        = "${var.component_name}-efs"
  description = "Allow jenkins agent inbound traffic on 2049"
  vpc_id      = local.vpc_id

    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.component_name}-efs"
  }
}

resource "aws_security_group_rule" "efs_ingress_rule_for_jenkins_agent" {
  security_group_id        = aws_security_group.efs.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_agnet.id
}

resource "aws_security_group" "jenkins_agnet" {
  name        = "${var.component_name}-jenkinsagnet"
  description = "Allow jenkins agent inbound traffic on 2049"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.component_name}-jenkinsagnet"
  }
}

resource "aws_security_group_rule" "jenkins_agent_allow_alb_sg" {
  security_group_id        = aws_security_group.jenkins_agnet.id
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "jenkins_worker_nodes_allow_alb_sg" {
  security_group_id        = aws_security_group.jenkins_agnet.id
  type                     = "ingress"
  from_port                = var.worker_nodePort
  to_port                  = var.worker_nodePort
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
}