# module "staging" {
#   source                = "./staging"
#   environment           = var.environment
#   region                = var.region
#   git_repository_owner  = var.git_repository_owner
#   git_repository_name   = var.git_repository_name
#   git_repository_branch = var.git_repository_branch
#   git_token             = var.git_token
# }

module "prod" {
  source                = "./prod"
  environment           = var.environment
  region                = var.region
  git_repository_owner  = var.git_repository_owner
  git_repository_name   = var.git_repository_name
  git_repository_branch = var.git_repository_branch
  git_token             = var.git_token
}