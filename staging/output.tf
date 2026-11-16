output "public_dns_webapps" {
  value = "${aws_instance.webapps[*].public_dns}"
}


output "alb_dns_webapps" {
  value = aws_lb.lb-staging.dns_name
}