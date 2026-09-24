locals {
  prefix = var.name_prefix != null ? "${var.name_prefix}-" : ""

  application_load_balancers = { for k, v in var.load_balancers : k => v if v.type == "application" }
  network_load_balancers     = { for k, v in var.load_balancers : k => v if v.type == "network" }

  rds_instance_alarms = merge(
    var.enable_rds_cpu_high ? {
      for k, v in var.rds_instances : "${k}-rds-cpu-high" => {
        namespace           = "AWS/RDS"
        metric_name         = "CPUUtilization"
        dimensions          = { DBInstanceIdentifier = v.identifier }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.rds_cpu_high_threshold
        treat_missing_data  = "missing"
        description         = "RDS instance ${v.identifier} CPU above ${var.rds_cpu_high_threshold}%."
      }
    } : {},
    var.enable_rds_free_storage_low ? {
      for k, v in var.rds_instances : "${k}-rds-free-storage-low" => {
        namespace           = "AWS/RDS"
        metric_name         = "FreeStorageSpace"
        dimensions          = { DBInstanceIdentifier = v.identifier }
        statistic           = "Average"
        comparison_operator = "LessThanThreshold"
        threshold           = var.rds_free_storage_low_threshold
        treat_missing_data  = "missing"
        description         = "RDS instance ${v.identifier} free storage below ${var.rds_free_storage_low_threshold} bytes."
      }
    } : {},
    var.enable_rds_connections_high ? {
      for k, v in var.rds_instances : "${k}-rds-connections-high" => {
        namespace           = "AWS/RDS"
        metric_name         = "DatabaseConnections"
        dimensions          = { DBInstanceIdentifier = v.identifier }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.rds_connections_high_threshold
        treat_missing_data  = "missing"
        description         = "RDS instance ${v.identifier} connections above ${var.rds_connections_high_threshold}."
      }
    } : {},
  )

  rds_cluster_alarms = merge(
    var.enable_rds_cluster_cpu_high ? {
      for k, v in var.rds_clusters : "${k}-aurora-cpu-high" => {
        namespace           = "AWS/RDS"
        metric_name         = "CPUUtilization"
        dimensions          = { DBClusterIdentifier = v.cluster_identifier }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.rds_cpu_high_threshold
        treat_missing_data  = "missing"
        description         = "Aurora cluster ${v.cluster_identifier} CPU above ${var.rds_cpu_high_threshold}%."
      }
    } : {},
    var.enable_rds_cluster_connections_high ? {
      for k, v in var.rds_clusters : "${k}-aurora-connections-high" => {
        namespace           = "AWS/RDS"
        metric_name         = "DatabaseConnections"
        dimensions          = { DBClusterIdentifier = v.cluster_identifier }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.rds_connections_high_threshold
        treat_missing_data  = "missing"
        description         = "Aurora cluster ${v.cluster_identifier} connections above ${var.rds_connections_high_threshold}."
      }
    } : {},
  )

  alb_alarms = merge(
    var.enable_alb_target_5xx ? {
      for k, v in local.application_load_balancers : "${k}-alb-target-5xx" => {
        namespace           = "AWS/ApplicationELB"
        metric_name         = "HTTPCode_Target_5XX_Count"
        dimensions          = { LoadBalancer = v.arn_suffix }
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.alb_target_5xx_threshold
        treat_missing_data  = "notBreaching"
        description         = "Load balancer ${v.arn_suffix} targets returned more than ${var.alb_target_5xx_threshold} 5XX responses."
      }
    } : {},
    var.enable_alb_unhealthy_hosts ? {
      for k, v in local.application_load_balancers : "${k}-alb-unhealthy-hosts" => {
        namespace           = "AWS/ApplicationELB"
        metric_name         = "UnHealthyHostCount"
        dimensions          = { LoadBalancer = v.arn_suffix }
        statistic           = "Maximum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
        description         = "Load balancer ${v.arn_suffix} has unhealthy targets."
      }
    } : {},
  )

  alb_latency_alarms = var.enable_alb_response_time_high ? {
    for k, v in local.application_load_balancers : "${k}-alb-response-time-high" => {
      namespace           = "AWS/ApplicationELB"
      metric_name         = "TargetResponseTime"
      dimensions          = { LoadBalancer = v.arn_suffix }
      comparison_operator = "GreaterThanThreshold"
      threshold           = var.alb_response_time_high_threshold
      treat_missing_data  = "notBreaching"
      description         = "Load balancer ${v.arn_suffix} p99 response time above ${var.alb_response_time_high_threshold}s."
    }
  } : {}

  nlb_alarms = var.enable_nlb_unhealthy_hosts ? {
    for k, v in local.network_load_balancers : "${k}-nlb-unhealthy-hosts" => {
      namespace           = "AWS/NetworkELB"
      metric_name         = "UnHealthyHostCount"
      dimensions          = { LoadBalancer = v.arn_suffix }
      statistic           = "Maximum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      treat_missing_data  = "notBreaching"
      description         = "Network load balancer ${v.arn_suffix} has unhealthy targets."
    }
  } : {}

  asg_alarms = var.enable_asg_cpu_high ? {
    for k, v in var.autoscaling_groups : "${k}-asg-cpu-high" => {
      namespace           = "AWS/EC2"
      metric_name         = "CPUUtilization"
      dimensions          = { AutoScalingGroupName = v.name }
      statistic           = "Average"
      comparison_operator = "GreaterThanThreshold"
      threshold           = var.asg_cpu_high_threshold
      treat_missing_data  = "missing"
      description         = "Autoscaling group ${v.name} average CPU above ${var.asg_cpu_high_threshold}%."
    }
  } : {}

  lambda_alarms = merge(
    var.enable_lambda_errors ? {
      for k, v in var.lambda_functions : "${k}-lambda-errors" => {
        namespace           = "AWS/Lambda"
        metric_name         = "Errors"
        dimensions          = { FunctionName = v.function_name }
        statistic           = "Sum"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = var.lambda_errors_threshold
        treat_missing_data  = "notBreaching"
        description         = "Lambda function ${v.function_name} recorded errors."
      }
    } : {},
    var.enable_lambda_throttles ? {
      for k, v in var.lambda_functions : "${k}-lambda-throttles" => {
        namespace           = "AWS/Lambda"
        metric_name         = "Throttles"
        dimensions          = { FunctionName = v.function_name }
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
        description         = "Lambda function ${v.function_name} was throttled for want of concurrency."
      }
    } : {},
  )

  dynamodb_alarms = merge(
    var.enable_dynamodb_read_throttles ? {
      for k, v in var.dynamodb_tables : "${k}-dynamodb-read-throttles" => {
        namespace           = "AWS/DynamoDB"
        metric_name         = "ReadThrottleEvents"
        dimensions          = { TableName = v.table_name }
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
        description         = "DynamoDB table ${v.table_name} throttled reads."
      }
    } : {},
    var.enable_dynamodb_write_throttles ? {
      for k, v in var.dynamodb_tables : "${k}-dynamodb-write-throttles" => {
        namespace           = "AWS/DynamoDB"
        metric_name         = "WriteThrottleEvents"
        dimensions          = { TableName = v.table_name }
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
        description         = "DynamoDB table ${v.table_name} throttled writes."
      }
    } : {},
  )

  elasticache_alarms = merge(
    var.enable_elasticache_cpu_high ? {
      for k, v in var.elasticache_replication_groups : "${k}-cache-cpu-high" => {
        namespace           = "AWS/ElastiCache"
        metric_name         = "CPUUtilization"
        dimensions          = { ReplicationGroupId = v.replication_group_id }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.elasticache_cpu_high_threshold
        treat_missing_data  = "missing"
        description         = "Cache ${v.replication_group_id} CPU above ${var.elasticache_cpu_high_threshold}%."
      }
    } : {},
    var.enable_elasticache_memory_high ? {
      for k, v in var.elasticache_replication_groups : "${k}-cache-memory-high" => {
        namespace           = "AWS/ElastiCache"
        metric_name         = "DatabaseMemoryUsagePercentage"
        dimensions          = { ReplicationGroupId = v.replication_group_id }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.elasticache_memory_high_threshold
        treat_missing_data  = "missing"
        description         = "Cache ${v.replication_group_id} memory above ${var.elasticache_memory_high_threshold}%."
      }
    } : {},
    var.enable_elasticache_evictions ? {
      for k, v in var.elasticache_replication_groups : "${k}-cache-evictions" => {
        namespace           = "AWS/ElastiCache"
        metric_name         = "Evictions"
        dimensions          = { ReplicationGroupId = v.replication_group_id }
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.elasticache_evictions_threshold
        treat_missing_data  = "notBreaching"
        description         = "Cache ${v.replication_group_id} evicted more than ${var.elasticache_evictions_threshold} keys, meaning it is full."
      }
    } : {},
  )

  ecs_alarms = merge(
    var.enable_ecs_cpu_high ? {
      for k, v in var.ecs_services : "${k}-ecs-cpu-high" => {
        namespace           = "AWS/ECS"
        metric_name         = "CPUUtilization"
        dimensions          = { ClusterName = v.cluster_name, ServiceName = v.service_name }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.ecs_cpu_high_threshold
        treat_missing_data  = "missing"
        description         = "ECS service ${v.service_name} CPU above ${var.ecs_cpu_high_threshold}%."
      }
    } : {},
    var.enable_ecs_memory_high ? {
      for k, v in var.ecs_services : "${k}-ecs-memory-high" => {
        namespace           = "AWS/ECS"
        metric_name         = "MemoryUtilization"
        dimensions          = { ClusterName = v.cluster_name, ServiceName = v.service_name }
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.ecs_memory_high_threshold
        treat_missing_data  = "missing"
        description         = "ECS service ${v.service_name} memory above ${var.ecs_memory_high_threshold}%."
      }
    } : {},
  )

  alarms = merge(
    local.rds_instance_alarms,
    local.rds_cluster_alarms,
    local.alb_alarms,
    local.nlb_alarms,
    local.asg_alarms,
    local.lambda_alarms,
    local.dynamodb_alarms,
    local.elasticache_alarms,
    local.ecs_alarms,
  )
}

resource "aws_cloudwatch_metric_alarm" "resource" {
  for_each = local.alarms

  alarm_name        = "${local.prefix}${each.key}"
  alarm_description = each.value.description

  namespace   = each.value.namespace
  metric_name = each.value.metric_name
  dimensions  = each.value.dimensions
  statistic   = each.value.statistic

  comparison_operator = each.value.comparison_operator
  threshold           = each.value.threshold
  treat_missing_data  = each.value.treat_missing_data

  period             = var.period
  evaluation_periods = var.evaluation_periods

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "latency" {
  for_each = local.alb_latency_alarms

  alarm_name        = "${local.prefix}${each.key}"
  alarm_description = each.value.description

  namespace          = each.value.namespace
  metric_name        = each.value.metric_name
  dimensions         = each.value.dimensions
  extended_statistic = "p99"

  comparison_operator = each.value.comparison_operator
  threshold           = each.value.threshold
  treat_missing_data  = each.value.treat_missing_data

  period             = var.period
  evaluation_periods = var.evaluation_periods

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = var.tags
}

output "alarm_arns" {
  description = "Map of alarm key to its ARN, one entry per alarm this module created."
  value = merge(
    { for k, a in aws_cloudwatch_metric_alarm.resource : k => a.arn },
    { for k, a in aws_cloudwatch_metric_alarm.latency : k => a.arn },
  )
}

output "alarm_names" {
  description = "Map of alarm key to its full name, including name_prefix."
  value = merge(
    { for k, a in aws_cloudwatch_metric_alarm.resource : k => a.alarm_name },
    { for k, a in aws_cloudwatch_metric_alarm.latency : k => a.alarm_name },
  )
}

output "alarm_count" {
  description = "Total number of alarms created, useful for confirming a configuration change actually added or removed what was intended."
  value       = length(aws_cloudwatch_metric_alarm.resource) + length(aws_cloudwatch_metric_alarm.latency)
}
