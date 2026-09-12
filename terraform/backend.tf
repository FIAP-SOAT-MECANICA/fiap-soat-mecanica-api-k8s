# Configuracao parcial: bucket, key e region vem de backend.hcl (ignorado pelo Git). Ver README.
terraform {
  backend "s3" {}
}
