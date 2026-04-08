terraform {
    backend "s3" {
        bucket = "pdaley-terraform-states"
        key = "kubernetes_deployment/compute/terraform.tfstate"
        region = "us-east-2"
        profile = "vscode"
    }
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
      bucket = "pdaley-terraform-states"
      key = "receipt_corrector/networking/terraform.tfstate"
      region = "us-east-2"
      profile = "vscode"
  }
}