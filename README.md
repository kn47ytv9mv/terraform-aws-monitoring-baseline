# terraform-aws-monitoring-baseline

Terraform module for a curated set of CloudWatch alarms across the
resources this family builds — a starting monitoring posture, wired to
one SNS topic.

## Cost

CloudWatch bills per alarm-month, with a small free tier. This module
creates between one and three alarms per resource supplied, so the cost
scales with how much is handed to it. Disabling an alarm via its
`enable_*` variable removes it and its cost. See AWS's
[CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) page
for current rates.

## Design

Every alarm is a plain metric alarm on a metric AWS already publishes —
nothing here requires enabling a paid metric stream first. Resources
are supplied as maps keyed by a short name that appears in the alarm's
own name, so `rds_instances = { app = { identifier = "app-db" } }`
produces `app-rds-cpu-high`.

Set `alarm_actions` to an SNS topic from
[`terraform-aws-sns-topic`](https://github.com/kn47ytv9mv/terraform-aws-sns-topic).
**Without it every alarm this module creates changes state silently and
notifies nobody** — which is the most common way a monitoring setup
looks complete and does nothing. Setting `ok_actions` to the same topic
is worth doing so an operator learns the problem cleared.

This module implements its own `aws_cloudwatch_metric_alarm` resources
rather than calling
[`terraform-aws-cloudwatch-metric-alarm`](https://github.com/kn47ytv9mv/terraform-aws-cloudwatch-metric-alarm)
internally — this family keeps single-purpose modules standalone; only
a parent composition config wires leaf modules together. Reach for that
module directly for an alarm outside this curated set.

### What it watches

| Resource | Alarms |
|---|---|
| `rds_instances` | CPU high, free storage low, connections high |
| `rds_clusters` | CPU high, connections high |
| `load_balancers` (application) | Target 5XX, unhealthy hosts, p99 response time |
| `load_balancers` (network) | Unhealthy hosts |
| `autoscaling_groups` | CPU high |
| `lambda_functions` | Errors, throttles |
| `dynamodb_tables` | Read throttles, write throttles |
| `elasticache_replication_groups` | CPU high, memory high, evictions |
| `ecs_services` | CPU high, memory high |

### Choices worth knowing about

- **Load balancers take `arn_suffix`, not `arn`.** CloudWatch's
  `LoadBalancer` dimension is the suffix (`app/web/1111`); the full ARN
  matches nothing and the alarm sits in `INSUFFICIENT_DATA` forever.
  The load balancer modules expose an `arn_suffix` output for this.
- **Count metrics use `treat_missing_data = "notBreaching"`; gauges use
  `"missing"`.** Lambda errors, throttles, 5XX counts, and evictions
  are only published when they happen, so treating no data as missing
  would leave the alarm stuck in ALARM forever after a single event.
  CPU and memory are published continuously and keep AWS's own
  behavior.
- **Response time is evaluated at p99, not average.** An average over
  five minutes hides exactly the slow requests worth paging on.
- **`evaluation_periods` defaults to 2**, so a single bad datapoint
  does not wake anyone.
- **`rds_connections_high_threshold` needs tuning.** The right value
  depends entirely on the instance class's own connection limit; the
  default suits a small instance and will be wrong for a large one.
- **`rds_free_storage_low_threshold` is in bytes.** It defaults to 10
  GiB. A plausible-looking value like `10` alarms on ten bytes and
  never fires.

## Usage

```hcl
module "alerts" {
  source = "kn47ytv9mv/sns-topic/aws"

  name = "alerts"

  subscriptions = [
    { protocol = "email", endpoint = "ops@example.com" },
  ]
}

module "monitoring" {
  source = "kn47ytv9mv/monitoring-baseline/aws"

  name_prefix   = "production"
  alarm_actions = [module.alerts.arn]
  ok_actions    = [module.alerts.arn]

  rds_instances = {
    app = { identifier = module.database.identifier }
  }

  load_balancers = {
    web = { arn_suffix = module.alb.arn_suffix }
  }

  autoscaling_groups = {
    web = { name = module.group.name }
  }
}
```

Or directly from this repository, tuning thresholds and dropping an
alarm that does not suit the workload:

```hcl
module "monitoring" {
  source = "github.com/kn47ytv9mv/terraform-aws-monitoring-baseline"

  alarm_actions = [module.alerts.arn]

  rds_instances = {
    app = { identifier = "app-db" }
  }

  rds_cpu_high_threshold      = 95
  enable_rds_connections_high = false

  lambda_functions = {
    processor = { function_name = "processor" }
  }
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| alarm_actions | ARNs notified when any alarm enters ALARM, typically one SNS topic. Without it, alarms notify nobody. | `null` | no |
| ok_actions | ARNs notified when an alarm returns to OK. | `null` | no |
| name_prefix | Prefix for every alarm name, before the resource key and metric. | `null` | no |
| rds_instances | RDS instances to monitor, keyed by a name used in the alarm names. | `{}` | no |
| rds_clusters | Aurora clusters to monitor, keyed by a name used in the alarm names. | `{}` | no |
| load_balancers | Load balancers to monitor. `arn_suffix`, not the full ARN. `type` is `'application'` or `'network'`. | `{}` | no |
| autoscaling_groups | Autoscaling groups to monitor, keyed by a name used in the alarm names. | `{}` | no |
| lambda_functions | Lambda functions to monitor, keyed by a name used in the alarm names. | `{}` | no |
| dynamodb_tables | DynamoDB tables to monitor, keyed by a name used in the alarm names. | `{}` | no |
| elasticache_replication_groups | ElastiCache replication groups to monitor. | `{}` | no |
| ecs_services | ECS services to monitor. Both cluster and service names are required. | `{}` | no |
| enable_rds_cpu_high | Alarm when an RDS instance's CPU stays above the threshold. | `true` | no |
| rds_cpu_high_threshold | Percent CPU an RDS instance must exceed to alarm. | `80` | no |
| enable_rds_free_storage_low | Alarm when an RDS instance's free storage falls below the threshold. | `true` | no |
| rds_free_storage_low_threshold | Bytes of free storage before alarming. Defaults to 10 GiB. | `10737418240` | no |
| enable_rds_connections_high | Alarm when an RDS instance's connection count exceeds the threshold. | `true` | no |
| rds_connections_high_threshold | Connections before alarming. Tune to the instance class. | `100` | no |
| enable_rds_cluster_cpu_high | Alarm when an Aurora cluster's CPU stays above the threshold. | `true` | no |
| enable_rds_cluster_connections_high | Alarm when an Aurora cluster's connection count exceeds the threshold. | `true` | no |
| enable_alb_target_5xx | Alarm on target 5XX responses from an application load balancer. | `true` | no |
| alb_target_5xx_threshold | 5XX responses in one period before alarming. | `10` | no |
| enable_alb_unhealthy_hosts | Alarm when an application load balancer reports any unhealthy target. | `true` | no |
| enable_alb_response_time_high | Alarm when p99 target response time exceeds the threshold. | `true` | no |
| alb_response_time_high_threshold | Seconds of p99 response time before alarming. | `2` | no |
| enable_nlb_unhealthy_hosts | Alarm when a network load balancer reports any unhealthy target. | `true` | no |
| enable_asg_cpu_high | Alarm when an autoscaling group's average CPU stays above the threshold. | `true` | no |
| asg_cpu_high_threshold | Percent average CPU before alarming. | `80` | no |
| enable_lambda_errors | Alarm when a Lambda function records errors. | `true` | no |
| lambda_errors_threshold | Errors in one period before alarming. | `1` | no |
| enable_lambda_throttles | Alarm when a Lambda function is throttled. | `true` | no |
| enable_dynamodb_read_throttles | Alarm when a DynamoDB table throttles reads. | `true` | no |
| enable_dynamodb_write_throttles | Alarm when a DynamoDB table throttles writes. | `true` | no |
| enable_elasticache_cpu_high | Alarm when an ElastiCache node's CPU stays above the threshold. | `true` | no |
| elasticache_cpu_high_threshold | Percent CPU before alarming. | `80` | no |
| enable_elasticache_memory_high | Alarm when memory usage exceeds the threshold, past which eviction discards live data. | `true` | no |
| elasticache_memory_high_threshold | Percent memory in use before alarming. | `80` | no |
| enable_elasticache_evictions | Alarm when the cache evicts more than the threshold, meaning it is full. | `true` | no |
| elasticache_evictions_threshold | Evictions in one period before alarming. | `100` | no |
| enable_ecs_cpu_high | Alarm when an ECS service's CPU stays above the threshold. | `true` | no |
| ecs_cpu_high_threshold | Percent CPU before alarming. | `80` | no |
| enable_ecs_memory_high | Alarm when an ECS service's memory stays above the threshold. | `true` | no |
| ecs_memory_high_threshold | Percent memory before alarming. | `80` | no |
| period | Seconds each datapoint covers, for every alarm. | `300` | no |
| evaluation_periods | Periods that must breach before an alarm fires. | `2` | no |
| tags | A map of tags to assign to every alarm. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| alarm_arns | Map of alarm key to its ARN, one entry per alarm created. |
| alarm_names | Map of alarm key to its full name, including `name_prefix`. |
| alarm_count | Total number of alarms created. |

## License

MIT — see [LICENSE.md](LICENSE.md).
