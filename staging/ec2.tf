data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "webapps" {
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  key_name        = "MyWebServers"
  count           = var.environment == "prod" ? 2 : 1
  user_data       = file("app.sh")
  subnet_id              = aws_subnet.webapps-staging.id
  vpc_security_group_ids = ["${aws_security_group.staging.id}"]
  iam_instance_profile   = aws_iam_instance_profile.EC2InstanceRole-profile.name

  tags = {
    Name = "${element(var.instance_tags, count.index)}"
    Application = var.environment
  }

}
