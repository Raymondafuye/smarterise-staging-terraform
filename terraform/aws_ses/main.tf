resource "aws_ses_domain_identity" "ses_domain" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "ses_dkim" {
  domain = aws_ses_domain_identity.ses_domain.domain
}

resource "aws_ses_domain_mail_from" "ses_mail_from" {
  domain              = aws_ses_domain_identity.ses_domain.domain
  mail_from_domain    = "mail.${var.domain_name}"
  behavior_on_mx_failure = "UseDefaultValue"
}

resource "aws_ses_email_identity" "email1" {
  email = var.email1
}

resource "aws_ses_email_identity" "email2" {
  email = var.email2
}

resource "aws_ses_email_identity" "email3" {
  email = var.email3
}

resource "aws_ses_configuration_set" "ses_config" {
  name = var.configuration_set_name
}
