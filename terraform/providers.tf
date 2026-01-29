
provider "aws" {
  region = "eu-west-2"
  # AWS credentials should be provided via environment variables:
  # export AWS_ACCESS_KEY_ID="your-access-key"
  # export AWS_SECRET_ACCESS_KEY="your-secret-key"
  # Or use AWS CLI profiles: aws configure
}
