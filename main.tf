# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Create an IAM user
resource "aws_iam_user" "user" {
  name = "my-user"
}

# Attach the AdministratorAccess policy to the user
resource "aws_iam_user_policy_attachment" "user_admin_policy" {
  user       = aws_iam_user.user.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

