terraform {
  backend "s3" {
    bucket = "terraform-test-bucket-oooo"
    key    = "terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "test2"
  }
}
