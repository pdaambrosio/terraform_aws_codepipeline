resource "aws_vpc" "webapps" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Group = "WebApps"
  }
}

# resource "aws_subnet" "webapps-prod" {

#   vpc_id                  = aws_vpc.webapps.id
#   cidr_block              = "10.1.0.0/20"
#   map_public_ip_on_launch = "true"
#   depends_on = [aws_vpc.webapps]

#   tags = {
#     Group       = "WebApps"
#     Application = var.environment
#   }
# }

resource "aws_subnet" "webapps-staging" {

  vpc_id                  = aws_vpc.webapps.id
  cidr_block              = "10.0.0.0/20"
  map_public_ip_on_launch = "true"
  depends_on = [aws_vpc.webapps]

  tags = {
    Group       = "WebApps"
    Application = var.environment
  }
}

resource "aws_route_table_association" "webapp-staging_route" {
  subnet_id      = aws_subnet.webapps-staging.id
  route_table_id = aws_route_table.route_webapps.id
  depends_on = [aws_route_table.route_webapps]
}

resource "aws_route_table" "route_webapps" {
  vpc_id = aws_vpc.webapps.id
  depends_on = [aws_internet_gateway.webapps]

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webapps.id
  }
}

resource "aws_internet_gateway" "webapps" {
  vpc_id = aws_vpc.webapps.id
  depends_on = [aws_vpc.webapps]

  tags = {
    Group = "Web Apps"
  }
}

resource "aws_security_group" "staging" {
  name        = "traffic staging"
  description = "HTTP and SSH"
  vpc_id      = aws_vpc.webapps.id
  depends_on = [aws_vpc.webapps]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["189.110.201.109/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}