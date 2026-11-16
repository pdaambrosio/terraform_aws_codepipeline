resource "aws_s3_bucket" "ec2CodePipelineBucket" {
  bucket        = "ec2codepipelinebucket-${var.environment}"
  acl           = "private"
  force_destroy = true
}

resource "aws_codepipeline" "ec2CodePipeline" {
  name     = "ec2CodePipeline-${var.environment}"
  role_arn = aws_iam_role.ec2CodePipelineRole.arn
  depends_on = [aws_instance.webapps]

  artifact_store {
    location = aws_s3_bucket.ec2CodePipelineBucket.bucket
    type     = "S3"
}

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["prod"]

      configuration = {
        Owner                = var.git_repository_owner
        Repo                 = var.git_repository_name
        Branch               = var.git_repository_branch
        PollForSourceChanges = false
        OAuthToken           = var.git_token
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["prod"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.ec2CodeDeployApp.name
        DeploymentGroupName = aws_codedeploy_deployment_group.ec2CodeDeployAppGroup.deployment_group_name
      }
    }
  }
}