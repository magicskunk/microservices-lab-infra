resource "aws_iam_openid_connect_provider" "default" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]
}

resource "aws_iam_role" "github_actions_role" {
  name        = "github-actions-role"
  description = "Allow github actions to interact with AWS via OIDC"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = "RoleForGitHubActions",
        Effect    = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.default.arn
        },
        Action    = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_role-ecr_get_authorization_token_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.ecr_get_authorization_token_policy.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_role-ecr_pull_push_allowed_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.ecr_pull_push_allowed_policy.arn
}


