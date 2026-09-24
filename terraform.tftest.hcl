mock_provider "aws" {}

run "invalid_load_balancer_type_is_rejected" {
  command = plan

  variables {
    load_balancers = {
      web = { arn_suffix = "app/web/1111", type = "gateway" }
    }
  }

  expect_failures = [var.load_balancers]
}

run "nothing_to_monitor_creates_no_alarms" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.resource) == 0
    error_message = "Supplying no resources should create no alarms at all."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.latency) == 0
    error_message = "Supplying no load balancers should create no latency alarms."
  }
}

run "one_rds_instance_creates_its_three_alarms" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.resource) == 3
    error_message = "An RDS instance should get its CPU, free storage, and connections alarms."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["app-rds-cpu-high"].dimensions["DBInstanceIdentifier"] == "app-db"
    error_message = "An RDS alarm must carry the DBInstanceIdentifier dimension, or it never leaves INSUFFICIENT_DATA."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["app-rds-free-storage-low"].comparison_operator == "LessThanThreshold"
    error_message = "A free-storage alarm fires when storage falls below the threshold, not above it."
  }
}

run "disabling_one_alarm_removes_only_that_alarm" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
    enable_rds_connections_high = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.resource) == 2
    error_message = "Disabling one alarm type should leave the other two in place."
  }

  assert {
    condition     = !contains(keys(aws_cloudwatch_metric_alarm.resource), "app-rds-connections-high")
    error_message = "The disabled alarm's key should not appear among the created alarms."
  }
}

run "load_balancer_type_selects_the_right_alarms" {
  command = plan

  variables {
    load_balancers = {
      web = { arn_suffix = "app/web/1111", type = "application" }
      tcp = { arn_suffix = "net/tcp/2222", type = "network" }
    }
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.resource) == 3
    error_message = "An application load balancer should get its 5XX and unhealthy-host alarms, and a network one only its unhealthy-host alarm."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.latency) == 1
    error_message = "Only the application load balancer should get a latency alarm."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["tcp-nlb-unhealthy-hosts"].namespace == "AWS/NetworkELB"
    error_message = "A network load balancer's alarms belong in the AWS/NetworkELB namespace."
  }

  assert {
    condition     = !contains(keys(aws_cloudwatch_metric_alarm.resource), "tcp-alb-target-5xx")
    error_message = "A network load balancer has no HTTP status metrics and should get no 5XX alarm."
  }
}

run "latency_alarm_uses_p99_not_average" {
  command = plan

  variables {
    load_balancers = {
      web = { arn_suffix = "app/web/1111" }
    }
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.latency["web-alb-response-time-high"].extended_statistic == "p99"
    error_message = "Latency should be evaluated at p99, since an average hides the slow requests worth alarming on."
  }
}

run "count_metrics_treat_missing_data_as_not_breaching" {
  command = plan

  variables {
    lambda_functions = {
      proc = { function_name = "processor" }
    }
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["proc-lambda-errors"].treat_missing_data == "notBreaching"
    error_message = "An error-count alarm must treat missing data as not breaching, or it fires once and never returns to OK."
  }
}

run "gauge_metrics_treat_missing_data_as_missing" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["app-rds-cpu-high"].treat_missing_data == "missing"
    error_message = "A continuously published gauge should keep AWS's own missing-data behavior."
  }
}

run "name_prefix_applies_to_every_alarm" {
  command = plan

  variables {
    name_prefix = "production"
    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["app-rds-cpu-high"].alarm_name == "production-app-rds-cpu-high"
    error_message = "name_prefix should prefix every alarm name."
  }
}

run "actions_reach_every_alarm" {
  command = plan

  variables {
    alarm_actions = ["arn:aws:sns:us-east-1:123456789012:alerts"]
    ok_actions    = ["arn:aws:sns:us-east-1:123456789012:alerts"]

    rds_instances = {
      app = { identifier = "app-db" }
    }
    load_balancers = {
      web = { arn_suffix = "app/web/1111" }
    }
  }

  assert {
    condition     = one(aws_cloudwatch_metric_alarm.resource["app-rds-cpu-high"].alarm_actions) == "arn:aws:sns:us-east-1:123456789012:alerts"
    error_message = "alarm_actions should reach every alarm, or the alarm notifies nobody."
  }

  assert {
    condition     = one(aws_cloudwatch_metric_alarm.latency["web-alb-response-time-high"].alarm_actions) == "arn:aws:sns:us-east-1:123456789012:alerts"
    error_message = "alarm_actions should reach the separately declared latency alarms too."
  }
}

run "thresholds_are_tunable" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
    rds_cpu_high_threshold = 95
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["app-rds-cpu-high"].threshold == 95
    error_message = "A tuned threshold should reach the alarm."
  }
}

run "ecs_alarms_carry_both_dimensions" {
  command = plan

  variables {
    ecs_services = {
      api = { cluster_name = "prod", service_name = "api" }
    }
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["api-ecs-cpu-high"].dimensions["ClusterName"] == "prod"
    error_message = "An ECS service alarm is dimensioned on the cluster and service pair, and needs both."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource["api-ecs-cpu-high"].dimensions["ServiceName"] == "api"
    error_message = "An ECS service alarm needs its ServiceName dimension."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    alarm_actions = ["arn:aws:sns:us-east-1:123456789012:alerts"]
    ok_actions    = ["arn:aws:sns:us-east-1:123456789012:alerts"]
    name_prefix   = "production"

    rds_instances = {
      app = { identifier = "app-db" }
    }

    load_balancers = {
      web = { arn_suffix = "app/web/1111" }
    }

    autoscaling_groups = {
      web = { name = "web" }
    }
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.resource) + length(aws_cloudwatch_metric_alarm.latency) == 7
    error_message = "The README example should produce three RDS, two ALB, one ALB latency, and one ASG alarm."
  }
}

run "readme_tuned_example" {
  command = plan

  variables {
    alarm_actions = ["arn:aws:sns:us-east-1:123456789012:alerts"]

    rds_instances = {
      app = { identifier = "app-db" }
    }

    rds_cpu_high_threshold      = 95
    enable_rds_connections_high = false

    lambda_functions = {
      processor = { function_name = "processor" }
    }
  }
}
