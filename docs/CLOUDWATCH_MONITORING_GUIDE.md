````markdown
# 📊 CloudWatch Monitoring & Debugging Guide

This guide explains how to use CloudWatch to monitor, debug, and troubleshoot your Ray Converter Lambda function in production.

---

## 🎯 What's Monitored

Your Lambda function now has **comprehensive CloudWatch monitoring**:

| Component | What's Tracked | Purpose |
|-----------|---|---|
| **Logs** | All function execution details | Real-time debugging |
| **Metrics** | Errors, warnings, success rate | Performance tracking |
| **Alarms** | Error spikes, timeouts, throttles | Proactive alerts |
| **Dashboard** | Visual metrics overview | Quick status check |
| **Insights** | Queryable logs database | Advanced analysis |

---

## 📝 Structured Logging Setup

Your `handler.py` now uses **structured JSON logging** for easy parsing in CloudWatch:

### Log Format Example
```json
{
  "timestamp": "2025-12-19T10:30:45.123456",
  "level": "INFO",
  "message": "Converted data successfully",
  "request_id": "abc123def456",
  "input_keys": ["x", "y", "z"],
  "output_keys": ["standard", "timestamp", "processed_at"],
  "input_size": 45,
  "output_size": 89
}
```

### What Gets Logged

Each request logs:
- **Request ID** - Unique identifier for tracing
- **Event keys** - What fields came in the request
- **Conversion details** - Input/output comparison
- **Error info** - Full exception details with type
- **Performance** - Data sizes and processing info

---

## 🔍 CloudWatch Console Access

### View Logs

```
1. Open AWS Console
   → Lambda → Functions → ray-converter
   → Monitor tab → "View CloudWatch Logs"
   
OR direct link:
   CloudWatch → Log Groups → /aws/lambda/ray-converter
```

### Real-Time Log Streaming

```bash
# View live logs from terminal
aws logs tail /aws/lambda/ray-converter --follow

# View last 100 lines
aws logs tail /aws/lambda/ray-converter --max-items 100

# View specific time range
aws logs filter-log-events \
  --log-group-name /aws/lambda/ray-converter \
  --start-time 1703000000000 \
  --end-time 1703003600000
```

---

## 📊 Metrics & Dashboards

### CloudWatch Dashboard

Your dashboard displays **4 key widgets**:

#### 1. Lambda Performance Metrics
```
• Total Invocations - How many times Lambda was called
• Errors - Failed executions
• Avg Duration - Average execution time in ms
• Throttles - Times Lambda hit concurrency limit
```

**Access Dashboard:**
```
CloudWatch → Dashboards → ray-converter-metrics
```

#### 2. Application Metrics
```
• Errors - From log filter (ERROR in logs)
• Warnings - From log filter (WARN in logs)
• Successful Conversions - Successful processing
```

#### 3. Error Logs
```
• Shows error count over time
• Auto-generated from ERROR log entries
```

#### 4. Concurrency Metrics
```
• Max Concurrent Executions
• Unreserved Concurrent Executions
```

---

## 🚨 Alarms & Notifications

### Active Alarms

Your infrastructure monitors for these issues:

| Alarm Name | Triggers When | Action |
|---|---|---|
| **High Error Rate** | >5 errors in 5 minutes | SNS email (optional) |
| **High Duration** | Avg execution >10 seconds | SNS email (optional) |
| **Lambda Timeout** | Function times out | SNS email (optional) |
| **Lambda Errors** | >3 errors in 5 minutes | SNS email (optional) |
| **Lambda Throttles** | Function is throttled | SNS email (optional) |

### Enable Email Alerts

**Step 1: Update terraform.tfvars**
```terraform
enable_alarms = true
alert_email   = "your-email@example.com"  # Add your email
```

**Step 2: Re-deploy**
```bash
cd infra
terraform apply
```

**Step 3: Confirm subscription**
- Check your email for AWS SNS subscription
- Click "Confirm subscription" link

Now you'll get email alerts when issues occur! 📧

### Check Alarm Status

```bash
# View all alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix ray-converter

# Check specific alarm
aws cloudwatch describe-alarms \
  --alarm-names ray-converter-high-error-rate
```

---

## 🔎 CloudWatch Logs Insights - Advanced Querying

### What is Logs Insights?

CloudWatch Logs Insights lets you **query all your logs like a database**. Search, filter, and analyze logs without manual scanning.

### Access Logs Insights

```
CloudWatch → Log Groups → /aws/lambda/ray-converter
→ Query Logs Insights button (at top)
```

### Pre-Built Query Templates

All these queries are available in your `cloudwatch.tf` outputs. Copy-paste them into Logs Insights:

#### Query 1: Find All Errors

```
fields @timestamp, @message, request_id
| filter @message like /ERROR/
| stats count() as error_count by @message
```

**Use Case:** See what errors happened today

---

#### Query 2: Analyze Response Times

```
fields @duration
| filter @duration > 0
| stats avg(@duration) as avg_ms, 
        max(@duration) as max_ms, 
        pct(@duration, 99) as p99_ms
```

**Use Case:** Performance analysis - is Lambda slow?

---

#### Query 3: Conversion Success Rate

```
fields @message
| filter @message like /Converted|ERROR/
| stats count(*) as total, 
        sum(ispresent(@message, /Converted/)) as successful
| fields total, successful, 
         round((successful / total) * 100) as success_rate_percent
```

**Use Case:** What % of requests succeeded?

---

#### Query 4: Find Slow Requests

```
fields @timestamp, @duration, request_id, @message
| filter @duration > 5000
| sort @duration desc
| limit 20
```

**Use Case:** Debug why some requests take >5 seconds

---

#### Query 5: Errors by Hour

```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() as error_count by bin(1h)
```

**Use Case:** Trend analysis - are errors increasing?

---

#### Query 6: Request Breakdown

```
fields @message, request_id, input_size, output_size
| filter ispresent(@message, /Converted/)
| stats avg(input_size) as avg_input, 
        avg(output_size) as avg_output,
        count() as total_requests
```

**Use Case:** Data flow analysis

---

#### Query 7: Top Error Types

```
fields @message, error_type
| filter @message like /ERROR/
| stats count() as count by error_type
| sort count desc
```

**Use Case:** What types of errors are most common?

---

## 🐛 Production Debugging Workflow

### Scenario 1: Lambda is Throwing Errors

**Step 1:** Check recent alarms
```bash
aws cloudwatch describe-alarms --state-value ALARM
```

**Step 2:** View logs in real-time
```bash
aws logs tail /aws/lambda/ray-converter --follow
```

**Step 3:** Query errors
```
Run "Find All Errors" query in Logs Insights
```

**Step 4:** Check specific error
```
Look at error message and request_id
Search logs for that request_id to trace flow
```

---

... (truncated in this view)
```