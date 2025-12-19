# 🔧 Lambda Trigger Configuration Guide

## Overview

This project now uses a **centralized trigger configuration system** that makes it easy to enable/disable different Lambda triggers without modifying Terraform code.

## File Structure

```
serverless-AiMl/
├── config/
│   ├── triggers.yaml          ← Main configuration file (EDIT THIS)
│   └── triggers.json          ← Exported format (auto-generated)
├── common/
│   └── trigger_config.py      ← Python parser utility
├── infra/
│   └── triggers_conditional.tf ← Dynamic Terraform (reads config)
└── demo_triggers.py           ← Interactive demo
```

## Supported Triggers

| Trigger | Enabled? | Use Case |
|---------|----------|----------|
| **API Gateway** | ✅ Yes | HTTP endpoints (GET/POST/etc) |
| **SQS** | ❌ No | Async message queues |
| **S3** | ❌ No | File upload notifications |
| **EventBridge** | ❌ No | Scheduled execution (cron/rate) |
| **DynamoDB** | ❌ No | Stream processing |
| **SNS** | ❌ No | Topic notifications |

## How to Enable/Disable Triggers

### Step 1: Edit Configuration

```bash
nano config/triggers.yaml
```

### Step 2: Change the `enabled` Flag

**Example: Enable SQS**

```yaml
# BEFORE (disabled)
sqs:
  enabled: false
  queue_name: "ray-converter-queue"
  batch_size: 10

# AFTER (enabled)
sqs:
  enabled: true      # ← Change this
  queue_name: "ray-converter-queue"
  batch_size: 10
```

### Step 3: Validate

```bash
python common/trigger_config.py
```

Output:
```
✅ Enabled Triggers:
  • API GATEWAY
    Route: POST /ray
  • SQS
    Queue: ray-converter-queue
    Batch Size: 10
```

### Step 4: Apply to AWS

```bash
cd infra
terraform plan    # Review changes
terraform apply   # Deploy to AWS
```

## Common Scenarios

### Scenario 1: Add HTTP API Endpoint (Already Enabled)

Already configured! Your Lambda is accessible at:
```
POST https://api-endpoint.com/ray
```

### Scenario 2: Enable SQS Processing

1. Edit `config/triggers.yaml`:
```yaml
sqs:
  enabled: true
  queue_name: "ray-converter-queue"
  batch_size: 10
  batch_window: 5
```

2. Deploy:
```bash
cd infra && terraform apply
```

3. Send messages:
```bash
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456/ray-converter-queue \
  --message-body '{"ray": {"x": 10, "y": 20}}'
```

### Scenario 3: Enable Scheduled Execution

1. Edit `config/triggers.yaml`:
```yaml
eventbridge:
  enabled: true
  schedule: "rate(30 minutes)"  # or "cron(0 12 * * ? *)"
```

2. Deploy:
```bash
cd infra && terraform apply
```

Now Lambda runs every 30 minutes automatically!

### Scenario 4: Enable S3 File Uploads

1. Edit `config/triggers.yaml`:
```yaml
s3:
  enabled: true
  bucket_name: "ray-converter-input"
  events: ["s3:ObjectCreated:*"]
  key_prefix: "input/"
  key_suffix: ".json"
```

2. Deploy:
```bash
cd infra && terraform apply
```

3. Upload files:
```bash
aws s3 cp ray_data.json s3://ray-converter-input/input/ray_data.json
```

Lambda triggers automatically!

## Useful Commands

```bash
# View current trigger configuration
python common/trigger_config.py

# Run interactive demo
python demo_triggers.py

# Export to JSON format
python -c "from common.trigger_config import TriggerConfig; TriggerConfig().export_to_json()"

# Validate configuration
python -c "from common.trigger_config import TriggerConfig; TriggerConfig().validate_config()"

# View Terraform plan (DRY RUN)
cd infra && terraform plan

# Apply changes to AWS
cd infra && terraform apply

# Destroy all resources (CAUTION!)
cd infra && terraform destroy
```

## Configuration Schema

```yaml
functions:
  ray_converter:                 # Function name
    name: ray-converter
    runtime: python3.11
    timeout: 30
    memory_size: 128
    
    # HTTP API Trigger
    api_gateway:
      enabled: true
      route: "POST /ray"
      cors:
        enabled: true
        allow_origins: ["*"]
        allow_methods: ["GET", "POST", "PUT", "DELETE"]
    
    # SQS Queue Trigger
    sqs:
      enabled: false
      queue_name: "ray-converter-queue"
      batch_size: 10
      batch_window: 5
    
    # S3 Bucket Trigger
    s3:
      enabled: false
      bucket_name: "ray-converter-input"
      events: ["s3:ObjectCreated:*"]
      key_prefix: "input/"
      key_suffix: ".json"
    
    # Scheduled Execution (EventBridge)
    eventbridge:
      enabled: false
      schedule: "rate(1 hour)"
    
    # DynamoDB Stream Trigger
    dynamodb:
      enabled: false
      table_name: "ray-events"
      stream_view_type: "NEW_AND_OLD_IMAGES"
      batch_size: 100
    
    # SNS Topic Trigger
    sns:
      enabled: false
      topic_name: "ray-conversion-topic"
```

## Terraform Integration

The Terraform code in `infra/triggers_conditional.tf` reads your configuration and creates:

- ✅ `aws_apigatewayv2_*` resources (if API Gateway enabled)
- ✅ `aws_sqs_queue` + event source mapping (if SQS enabled)
- ✅ `aws_s3_bucket` + bucket notification (if S3 enabled)
- ✅ `aws_cloudwatch_event_*` resources (if EventBridge enabled)
- ✅ `aws_lambda_event_source_mapping` (if DynamoDB enabled)
- ✅ SNS permissions and subscriptions (if SNS enabled)

## Troubleshooting

**Q: I enabled a trigger but it's not showing in AWS**

A: Run `terraform apply` after editing the config:
```bash
cd infra && terraform apply
```

**Q: Can I enable multiple triggers at once?**

A: Yes! Just set `enabled: true` for all triggers you want:
```yaml
api_gateway:
  enabled: true
sqs:
  enabled: true
s3:
  enabled: true
```

**Q: How do I see what Terraform will create?**

A: Use the plan command:
```bash
cd infra && terraform plan
```

**Q: I made a mistake, how do I disable a trigger?**

A: Set `enabled: false` and re-apply:
```yaml
sqs:
  enabled: false  # ← Change to false
```

Then:
```bash
cd infra && terraform apply
```

---

For more help, see the main [README.md](README.md)
