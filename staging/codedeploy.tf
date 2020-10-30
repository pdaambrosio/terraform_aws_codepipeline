resource "aws_codedeploy_app" "ec2CodeDeployApp" {
  name = "ec2CodeDeployApp-${var.environment}"
}

resource "aws_codedeploy_deployment_group" "ec2CodeDeployAppGroup" {
  app_name               = aws_codedeploy_app.ec2CodeDeployApp.name
  deployment_group_name  = "ec2CodeDeployAppGroup-${var.environment}"
  service_role_arn       = aws_iam_role.CodeDeployRole.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Application"
      type  = "KEY_AND_VALUE"
      value = var.environment
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}