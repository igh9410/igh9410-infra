terraform {
  backend "gcs" {
    bucket = "igh9410-terraform"
    prefix = "gramnuri/dev"
  }
}