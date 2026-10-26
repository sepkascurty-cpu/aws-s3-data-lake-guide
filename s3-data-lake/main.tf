# AWS S3 Data Lake — Bronze / Silver / Gold zones
# Region, bucket name, and account-specific values are variables on purpose:
# check pricing and permissions before you apply anything.
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "AWS region for the lake (keep lake, catalog, and consumers in one region)"
  type        = string
  default     = "ap-southeast-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for the data lake"
  type        = string
  default     = "my-data-lake-example-CHANGE-ME"
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "lake" {
  bucket = var.bucket_name
}

# Block Public Access: all four settings, no exceptions.
resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle: nothing sits in Standard forever by accident.
resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    id     = "bronze-cool-down"
    status = "Enabled"
    filter { prefix = "bronze/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "silver-cool-down"
    status = "Enabled"
    filter { prefix = "silver/" }
    transition {
      days          = 60
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "gold-cool-down"
    status = "Enabled"
    filter { prefix = "gold/" }
    transition {
      days          = 180
      storage_class = "STANDARD_IA"
    }
  }
}

# Glue catalog database: the single source of truth for tables.
resource "aws_glue_catalog_database" "lake" {
  name = "data_lake"
}

# Crawler: discovers Bronze files and registers them in the catalog.
resource "aws_glue_crawler" "bronze" {
  database_name = aws_glue_catalog_database.lake.name
  name          = "bronze-crawler"
  role_arn      = aws_iam_role.glue.arn

  s3_target {
    path = "s3://${aws_s3_bucket.lake.bucket}/bronze/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}

# Minimal Glue IAM role (scope it down further for production).
resource "aws_iam_role" "glue" {
  name = "glue-data-lake-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Athena workgroup + results bucket prefix, so queries stay auditable.
resource "aws_athena_workgroup" "lake" {
  name = "data-lake-workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.lake.bucket}/athena-results/"
    }
    enforce_workgroup_configuration = true
  }
}

output "bucket" {
  value = aws_s3_bucket.lake.bucket
}

output "glue_database" {
  value = aws_glue_catalog_database.lake.name
}
