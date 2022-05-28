resource "aws_ecr_repository" "ecr_repository" {
  name                 = lookup(var.ecr_repos, var.environment_code)
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = merge(local.common_tags, {
    Name = "ecr-repo"
    env  = var.environment_code
  })
}

resource "aws_iam_policy" "ecr_get_authorization_token_policy" {
  name        = "ecr-get-authorization-token"
  description = "Allow fetching of authorization token for ECR repo"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EcrGetAuthorizationToken",
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_pull_allowed_policy" {
  name        = "ecr-pull-allowed-policy"
  description = "Allow pull from ECR policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowPull",
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        "Resource" : aws_ecr_repository.ecr_repository.arn
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_pull_push_allowed_policy" {
  name        = "ecr-pull-push-allowed-policy"
  description = "Allow pull & push to ecr policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowPullPush",
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource" : aws_ecr_repository.ecr_repository.arn
      }
    ]
  })
}
