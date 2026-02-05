# Enhanced EventBridge Module for Site-Aware Scheduling

# EventBridge rule for CRITICAL sites (daily FTP backup at 11 PM)
resource "aws_cloudwatch_event_rule" "critical_sites_ftp_backup" {
  name                = "critical-sites-ftp-backup"
  description         = "Daily FTP backup for CRITICAL tier sites"
  schedule_expression = "cron(0 23 * * ? *)"  # 11 PM daily
}

resource "aws_cloudwatch_event_target" "critical_sites_ftp_target" {
  rule      = aws_cloudwatch_event_rule.critical_sites_ftp_backup.name
  target_id = "CriticalSitesFTPTarget"
  arn       = var.ftp_lambda_arn

  input = jsonencode({
    site_tier = "CRITICAL"
    backup_type = "daily"
  })
}

# EventBridge rule for NON_CRITICAL sites (hourly FTP sync)
resource "aws_cloudwatch_event_rule" "non_critical_sites_ftp_sync" {
  name                = "non-critical-sites-ftp-sync"
  description         = "Hourly FTP sync for NON_CRITICAL tier sites"
  schedule_expression = "cron(0 * * * ? *)"  # Every hour
}

resource "aws_cloudwatch_event_target" "non_critical_sites_ftp_target" {
  rule      = aws_cloudwatch_event_rule.non_critical_sites_ftp_sync.name
  target_id = "NonCriticalSitesFTPTarget"
  arn       = var.ftp_lambda_arn

  input = jsonencode({
    site_tier = "NON_CRITICAL"
    sync_type = "hourly"
  })
}

# Lambda permissions for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_critical" {
  statement_id  = "AllowExecutionFromEventBridgeCritical"
  action        = "lambda:InvokeFunction"
  function_name = var.ftp_lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.critical_sites_ftp_backup.arn
}

resource "aws_lambda_permission" "allow_eventbridge_non_critical" {
  statement_id  = "AllowExecutionFromEventBridgeNonCritical"
  action        = "lambda:InvokeFunction"
  function_name = var.ftp_lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.non_critical_sites_ftp_sync.arn
}