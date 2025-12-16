resource "aws_cloudwatch_event_rule" "ftp_schedule" {
  name                = "ftp_to_s3_cron"
  schedule_expression = "cron(0 23 * * ? *)" # Runs at 11 PM UTC daily
  #schedule_expression = "rate(10 minutes)"

}

resource "aws_cloudwatch_event_target" "ftp_lambda_target" {
  rule      = aws_cloudwatch_event_rule.ftp_schedule.name
  target_id = "ftp_lambda"
  arn       = var.lambda_arn
}
