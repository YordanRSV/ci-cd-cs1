resource "aws_sns_topic" "soar_alerts" {
  name = "soar-alerts"
}

#lambda exec role

resource "aws_iam_role" "lambda_exec" {
    name = "soar-lambda-exec-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow",
            Principal = {
                Service = "lambda.amazonaws.com"
            },
            Action = "sts:AssumeRole"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
    role = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
    role = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

#SOAR Lambda Function

resource "aws_lambda_function" "soar_function" {
    function_name = "soar-orchestrator"
    handler = "soar.handler"
    runtime = "python3.10"
    role = aws_iam_role.lambda_exec.arn
    filename = "soar.zip"

    vpc_config {
      subnet_ids = [aws_subnet.web.id, aws_subnet.db_a.id]
      security_group_ids = [aws_security_group.web_sg.id]

    }

    environment {
        variables = {
            SNS_TOPIC = aws_sns_topic.soar_alerts.arn
        }
    }
}

#SOAR SNS Subscription

resource "aws_sns_topic_subscription" "soar_lambda_sub" {
    topic_arn = aws_sns_topic.soar_alerts.arn
    protocol = "lambda"
    endpoint = aws_lambda_function.soar_function.arn
}

#lambda sns permission

resource "aws_lambda_permission" "allow_sns" {
    statement_id = "AllowExecutionFromSNS"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.soar_function.function_name
    principal = "sns.amazonaws.com"
    source_arn = aws_sns_topic.soar_alerts.arn
}

#lambda ses permission

resource "aws_iam_role_policy" "lambda_ses_policy" {
    name = "lambda-ses-policy"
    role = aws_iam_role.lambda_exec.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
                "ses:SendEmail",
                "ses:SendRawEmail"
            ]
            Resource = "*"
        }]
    })
}

# CloudWatch alarms that publish to SOAR SNS
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
    alarm_name          = "alb-5xx-errors"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 1
    metric_name         = "HTTPCode_Target_5XX_Count"
    namespace           = "AWS/ApplicationELB"
    period              = 300
    statistic           = "Sum"
    threshold           = 5

    dimensions = {
        TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
        LoadBalancer = aws_lb.app_lb.arn_suffix
    }

    alarm_actions = [aws_sns_topic.soar_alerts.arn]
    ok_actions    = [aws_sns_topic.soar_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
    alarm_name          = "rds-low-free-storage"
    comparison_operator = "LessThanThreshold"
    evaluation_periods  = 1
    metric_name         = "FreeStorageSpace"
    namespace           = "AWS/RDS"
    period              = 300
    statistic           = "Average"
    threshold           = 100000000

    dimensions = {
        DBInstanceIdentifier = aws_db_instance.db.id
    }

    alarm_actions = [aws_sns_topic.soar_alerts.arn]
    ok_actions    = [aws_sns_topic.soar_alerts.arn]
}
