resource "aws_lb" "lb-staging" {
  name               = "lb-${var.environment}"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.webapps-staging.id]
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "grp-staging-80" {
  name     = "grp-staging-80"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.webapps.id
  depends_on = [aws_lb.lb-staging]
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb-staging.arn
  port = 80
  protocol = "TCP"

    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grp-staging-80.arn
  }
  depends_on = [aws_lb_target_group.grp-staging-80]
}

resource "aws_lb_target_group_attachment" "attch-instances-staging" {
  count            = var.environment == "prod" ? 2 : 1
  target_group_arn = aws_lb_target_group.grp-staging-80.arn
  target_id        = aws_instance.webapps.*.id[count.index]
  port             = 80
  depends_on       = [aws_lb_listener.front_end]
}