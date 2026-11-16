
variable "region" {
}

variable "environment" {
}

variable "instance_count" {
  default = "1"
}

variable "git_repository_owner" {
}

variable "git_repository_name" {
}

variable "git_repository_branch" {
}

variable "git_token" {
}

variable "instance_tags" {
  type    = list(string)
  default = ["webapp01","webapp02"]

}