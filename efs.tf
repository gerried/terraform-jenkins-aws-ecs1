
resource "aws_efs_file_system" "jenkins" {
  creation_token = "${var.component_name}-jenkins-data"

  tags = {
    Name = "${var.component_name}-jenkins-data"
  }
}

resource "aws_efs_mount_target" "jenkins_data_mount_targets" {
  depends_on = [aws_efs_file_system.jenkins]
  count      = length(local.private_subnet)

  file_system_id  = aws_efs_file_system.jenkins.id
  subnet_id       = element(local.private_subnet, count.index)
  security_groups = [aws_security_group.efs.id] # 
}

data "aws_iam_policy_document" "fargate_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["ecs-tasks.amazonaws.com", "ecs.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "fargate_role" {
  name = "${var.component_name}-fargate"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.fargate_role.json
}


resource "aws_efs_file_system_policy" "policy" {
  file_system_id = aws_efs_file_system.jenkins.id

  bypass_policy_lockout_safety_check = true
  policy                             = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "AccessThroughMountTarget",
    "Statement": [
        {
            "Sid": "AccessThroughMountTarget",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Resource": "*",
            "Action": [
                 "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientWrite",
                "elasticfilesystem:ClientMount"
            ],
            "Condition": {
                "Bool": {
                  "elasticfilesystem:AccessedViaMountTarget": "true"
                }
            }
        },
        {
            "Sid": "FargateAccess",
            "Effect": "Allow",
            "Principal": { "AWS": "*" },
            "Action": [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "true"
                },
                "StringEquals": {
                    "elasticfilesystem:AccessPointArn" : "${aws_efs_access_point.fargate.arn}"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_efs_access_point" "fargate" {
  file_system_id = aws_efs_file_system.jenkins.id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/opt/data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 755
    }
  }
}





