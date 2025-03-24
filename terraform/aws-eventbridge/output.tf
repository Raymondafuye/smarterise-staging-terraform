output "eventbridge_rule_arn" {
  value = aws_cloudwatch_event_rule.ftp_schedule.arn
}
