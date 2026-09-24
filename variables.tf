variable "alarm_actions" {
  default     = null
  description = "ARNs notified when any alarm this module creates enters ALARM — typically one SNS topic from terraform-aws-sns-topic. Leaving this null creates alarms that change state silently and notify nobody, which is rarely the intent."
}

variable "ok_actions" {
  default     = null
  description = "ARNs notified when an alarm returns to OK. Setting this to the same topic as alarm_actions is worth doing, so an operator learns the problem cleared without going to look."
}

variable "name_prefix" {
  default     = null
  description = "Prefix for every alarm name this module creates, before the resource key and metric (e.g. 'production' yields 'production-app-rds-cpu-high'). If null, names begin with the resource key."
}

variable "rds_instances" {
  default     = {}
  description = "RDS instances to monitor, keyed by a name used in the alarm names. identifier is the instance's own identifier, from terraform-aws-db-instance's identifier output."
  type = map(object({
    identifier = string
  }))
}

variable "rds_clusters" {
  default     = {}
  description = "Aurora clusters to monitor, keyed by a name used in the alarm names. cluster_identifier comes from terraform-aws-rds-cluster's cluster_identifier output."
  type = map(object({
    cluster_identifier = string
  }))
}

variable "load_balancers" {
  default     = {}
  description = "Load balancers to monitor, keyed by a name used in the alarm names. arn_suffix comes from the load balancer module's arn_suffix output — the plain ARN does not work as a CloudWatch dimension. type is 'application' or 'network', which selects the metric namespace and the alarms that apply."
  type = map(object({
    arn_suffix = string
    type       = optional(string, "application")
  }))

  validation {
    condition     = alltrue([for l in var.load_balancers : contains(["application", "network"], l.type)])
    error_message = "A load balancer's type must be either 'application' or 'network'."
  }
}

variable "autoscaling_groups" {
  default     = {}
  description = "Autoscaling groups to monitor, keyed by a name used in the alarm names. name comes from terraform-aws-autoscaling-group's name output."
  type = map(object({
    name = string
  }))
}

variable "lambda_functions" {
  default     = {}
  description = "Lambda functions to monitor, keyed by a name used in the alarm names. function_name comes from terraform-aws-lambda-function's function_name output."
  type = map(object({
    function_name = string
  }))
}

variable "dynamodb_tables" {
  default     = {}
  description = "DynamoDB tables to monitor, keyed by a name used in the alarm names. table_name comes from terraform-aws-dynamodb-table's name output."
  type = map(object({
    table_name = string
  }))
}

variable "elasticache_replication_groups" {
  default     = {}
  description = "ElastiCache replication groups to monitor, keyed by a name used in the alarm names. replication_group_id comes from terraform-aws-elasticache-replication-group's id output."
  type = map(object({
    replication_group_id = string
  }))
}

variable "ecs_services" {
  default     = {}
  description = "ECS services to monitor, keyed by a name used in the alarm names. Both the cluster and service names are needed, since ECS service metrics are dimensioned on the pair."
  type = map(object({
    cluster_name = string
    service_name = string
  }))
}

variable "enable_rds_cpu_high" {
  default     = true
  description = "Alarm when an RDS instance's CPU stays above rds_cpu_high_threshold."
}

variable "rds_cpu_high_threshold" {
  default     = 80
  description = "Percent CPU an RDS instance must exceed to alarm."
}

variable "enable_rds_free_storage_low" {
  default     = true
  description = "Alarm when an RDS instance's free storage falls below rds_free_storage_low_threshold. The single most valuable database alarm — a full disk takes the database down hard and without warning."
}

variable "rds_free_storage_low_threshold" {
  default     = 10737418240
  description = "Bytes of free storage an RDS instance must fall below to alarm. Defaults to 10 GiB. CloudWatch reports this metric in bytes, so a plausible-looking value like 10 alarms on 10 bytes and never fires."
}

variable "enable_rds_connections_high" {
  default     = true
  description = "Alarm when an RDS instance's connection count exceeds rds_connections_high_threshold. The right threshold depends entirely on the instance class's own connection limit, so this is disabled in effect until tuned."
}

variable "rds_connections_high_threshold" {
  default     = 100
  description = "Connections an RDS instance must exceed to alarm. Tune this to the instance class — the default suits a small instance and will be wrong for a large one."
}

variable "enable_rds_cluster_cpu_high" {
  default     = true
  description = "Alarm when an Aurora cluster's CPU stays above rds_cpu_high_threshold."
}

variable "enable_rds_cluster_connections_high" {
  default     = true
  description = "Alarm when an Aurora cluster's connection count exceeds rds_connections_high_threshold."
}

variable "enable_alb_target_5xx" {
  default     = true
  description = "Alarm when an application load balancer's targets return more than alb_target_5xx_threshold 5XX responses in a period. Only applies to load_balancers entries of type 'application'."
}

variable "alb_target_5xx_threshold" {
  default     = 10
  description = "5XX responses from targets in one period before alarming."
}

variable "enable_alb_unhealthy_hosts" {
  default     = true
  description = "Alarm when an application load balancer reports any unhealthy target."
}

variable "enable_alb_response_time_high" {
  default     = true
  description = "Alarm when an application load balancer's target response time exceeds alb_response_time_high_threshold. Evaluated at p99 rather than average, since an average hides exactly the slow requests worth knowing about."
}

variable "alb_response_time_high_threshold" {
  default     = 2
  description = "Seconds of p99 target response time before alarming."
}

variable "enable_nlb_unhealthy_hosts" {
  default     = true
  description = "Alarm when a network load balancer reports any unhealthy target. Only applies to load_balancers entries of type 'network'."
}

variable "enable_asg_cpu_high" {
  default     = true
  description = "Alarm when an autoscaling group's average CPU stays above asg_cpu_high_threshold."
}

variable "asg_cpu_high_threshold" {
  default     = 80
  description = "Percent average CPU across an autoscaling group before alarming."
}

variable "enable_lambda_errors" {
  default     = true
  description = "Alarm when a Lambda function records more than lambda_errors_threshold errors in a period."
}

variable "lambda_errors_threshold" {
  default     = 1
  description = "Errors in one period before alarming. Defaults to 1 — any error is worth seeing on a function that is expected to succeed."
}

variable "enable_lambda_throttles" {
  default     = true
  description = "Alarm when a Lambda function is throttled, meaning invocations were rejected for want of concurrency."
}

variable "enable_dynamodb_read_throttles" {
  default     = true
  description = "Alarm when a DynamoDB table throttles reads. Expected occasionally under provisioned billing; under on-demand it means the table is scaling slower than traffic is arriving."
}

variable "enable_dynamodb_write_throttles" {
  default     = true
  description = "Alarm when a DynamoDB table throttles writes."
}

variable "enable_elasticache_cpu_high" {
  default     = true
  description = "Alarm when an ElastiCache node's CPU stays above elasticache_cpu_high_threshold."
}

variable "elasticache_cpu_high_threshold" {
  default     = 80
  description = "Percent CPU an ElastiCache node must exceed to alarm."
}

variable "enable_elasticache_memory_high" {
  default     = true
  description = "Alarm when an ElastiCache group's memory usage exceeds elasticache_memory_high_threshold. Past this point the eviction policy starts discarding data that was expected to still be there."
}

variable "elasticache_memory_high_threshold" {
  default     = 80
  description = "Percent of available memory in use before alarming."
}

variable "enable_elasticache_evictions" {
  default     = true
  description = "Alarm when an ElastiCache group evicts more than elasticache_evictions_threshold keys in a period, meaning it is full and discarding live data."
}

variable "elasticache_evictions_threshold" {
  default     = 100
  description = "Evictions in one period before alarming."
}

variable "enable_ecs_cpu_high" {
  default     = true
  description = "Alarm when an ECS service's CPU utilization stays above ecs_cpu_high_threshold."
}

variable "ecs_cpu_high_threshold" {
  default     = 80
  description = "Percent CPU utilization an ECS service must exceed to alarm."
}

variable "enable_ecs_memory_high" {
  default     = true
  description = "Alarm when an ECS service's memory utilization stays above ecs_memory_high_threshold. A task exceeding its memory reservation is killed and restarted, so this is the alarm that explains mysterious restarts."
}

variable "ecs_memory_high_threshold" {
  default     = 80
  description = "Percent memory utilization an ECS service must exceed to alarm."
}

variable "period" {
  default     = 300
  description = "Seconds each datapoint covers, for every alarm this module creates."
}

variable "evaluation_periods" {
  default     = 2
  description = "Periods that must breach before an alarm fires, for every alarm this module creates. Defaults to 2 rather than 1, so a single bad datapoint does not page anyone."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to every alarm this module creates."
}
