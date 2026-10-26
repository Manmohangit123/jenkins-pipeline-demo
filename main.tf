terraform {
  backend "s3" {
    bucket       = "manmohan-tf-state-7k2q9x"
    key          = "jenkins-demo/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_s3_bucket" "demo" {
  bucket = "manmohan-jenkins-demo-5r3t8k"
}

resource "aws_s3_object" "app_py" {
  bucket       = aws_s3_bucket.demo.id
  key          = "python/app.py"
  source       = "${path.module}/app.py"
  etag         = filemd5("${path.module}/app.py")
  content_type = "text/x-python"
}

resource "aws_s3_object" "test_app_py" {
  bucket       = aws_s3_bucket.demo.id
  key          = "python/test_app.py"
  source       = "${path.module}/test_app.py"
  etag         = filemd5("${path.module}/test_app.py")
  content_type = "text/x-python"
}
