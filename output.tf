output "public_dns" {
  value = module.prod.public_dns_webapps
}

output "alb_dns" {
  value = "${module.prod.alb_dns_webapps}"
}