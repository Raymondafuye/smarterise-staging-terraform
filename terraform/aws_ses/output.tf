output "ses_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.ses_domain.arn
}

output "dkim_tokens" {
  description = "DKIM tokens for the domain"
  value       = aws_ses_domain_dkim.ses_dkim.dkim_tokens
}

output "mail_from_domain" {
  description = "Mail-from domain configured for the SES identity"
  value       = aws_ses_domain_mail_from.ses_mail_from.mail_from_domain
}

output "ses_configuration_set" {
  description = "Name of the SES configuration set"
  value       = aws_ses_configuration_set.ses_config.name
}
