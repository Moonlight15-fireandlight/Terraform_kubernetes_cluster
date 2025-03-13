terraform {

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84.0" #actualizo la version de 5.72 a 5.73 con un terraform init -upgrade
      #configuration_aliases = [ aws.case1, aws.case2 ]
    }

  }

  required_version = ">= 1.7.4" #version de terraform

}

provider "aws" {

  region = "us-west-2"
  
}

provider "aws" {

  alias  = "california"
  region = "us-west-1"

}