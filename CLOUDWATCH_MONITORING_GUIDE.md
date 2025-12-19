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

### Scenario 2: Lambda is Slow

**Step 1:** Check dashboard
```
CloudWatch → Dashboards → ray-converter-metrics
Look at "Avg Duration" widget
```

**Step 2:** Run performance query
```
Run "Analyze Response Times" query
```

**Step 3:** Find slow requests
```
Run "Find Slow Requests" query (>5 seconds)
```

**Step 4:** Investigate specific request
```
Click on request_id
View full logs for that request
Check input/output sizes
```

---

### Scenario 3: Lambda Keeps Timing Out

**Step 1:** Check timeout alarm
```bash
aws cloudwatch describe-alarms \
  --alarm-names ray-converter-timeout
```

**Step 2:** View logs near timeout
```bash
aws logs tail /aws/lambda/ray-converter --follow --since 10m
```

**Step 3:** Query recent errors
```
fields @message, error_type
| filter @message like /timeout/i
| sort @timestamp desc
```

**Step 4:** Solutions:
- Increase timeout in `infra/main.tf` (max 15 minutes)
- Optimize Lambda code
- Increase memory (faster CPU allocated)

---

## 📈 Metrics Explanations

### Lambda Native Metrics (AWS/Lambda namespace)

| Metric | Unit | Interpretation |
|--------|------|---|
| **Invocations** | Count | Total function calls |
| **Errors** | Count | Failed executions |
| **Duration** | Milliseconds | How long each execution takes |
| **Throttles** | Count | Times function hit concurrency limit |
| **Timeout** | Count | Executions that timed out |
| **ConcurrentExecutions** | Count | Simultaneous running instances |
| **UnreservedConcurrentExecutions** | Count | Available concurrency |

### Application Metrics (RayConverter namespace)

| Metric | Unit | Interpretation |
|--------|------|---|
| **ErrorCount** | Count | Errors logged in logs (from ERROR filter) |
| **WarningCount** | Count | Warnings logged (from WARN filter) |
| **SuccessfulConversions** | Count | Successful conversions (from Converted filter) |

---

## 🎛️ Configuration Options

### Modify Monitoring Behavior

**In `infra/terraform.tfvars`:**

```terraform
# Enable/disable alarms
enable_alarms = true

# Send email alerts (requires email)
alert_email = "your-email@example.com"

# Create visual dashboard
enable_dashboard = true

# How long to keep logs (default: 14 days)
log_retention_days = 14

# Enable detailed 1-minute metrics (costs more)
enable_detailed_monitoring = false
```

### Redeploy After Changes

```bash
cd infra
terraform plan
terraform apply
```

---

## 📋 CloudWatch Log Retention Policy

Your logs are automatically **retained for 14 days** (configurable).

### Change Retention

```terraform
# In terraform.tfvars
log_retention_days = 30  # Keep for 30 days instead
```

### AWS Pricing Note

- First 5 GB/month: FREE
- Additional: ~$0.50 per GB
- Log retention: ~$0.03 per GB/month

---

## 🔐 Security & Access Control

### Who Can View Logs?

**Configure in IAM:** `infra/main.tf`

Current setup uses basic Lambda execution role which has:
- ✅ Write logs to CloudWatch
- ✅ Basic metrics

To add CloudWatch viewing permissions, add to IAM policy:
```json
{
  "Effect": "Allow",
  "Action": [
    "logs:DescribeLogGroups",
    "logs:DescribeLogStreams",
    "logs:GetLogEvents",
    "cloudwatch:GetMetricStatistics"
  ],
  "Resource": "*"
}
```

---

## 🚀 Best Practices

### ✅ DO:
- ✅ Check alarms after each deployment
- ✅ Set up email notifications for production
- ✅ Review error logs daily
- ✅ Use structured logging format (already implemented!)
- ✅ Archive old logs to S3 for long-term storage

### ❌ DON'T:
- ❌ Log sensitive data (API keys, passwords)
- ❌ Leave verbose DEBUG logging enabled
- ❌ Ignore alarm emails
- ❌ Assume Lambda is working without checking CloudWatch

---

## 📞 Troubleshooting

### Problem: No logs appearing

**Solution:**
```bash
# Check log group exists
aws logs describe-log-groups --log-group-name-prefix /aws/lambda

# Manually invoke function to generate logs
aws lambda invoke \
  --function-name ray-converter \
  --payload '{"ray": {"x": 1, "y": 2}}' \
  response.json
```

### Problem: CloudWatch Logs Insights query fails

**Solution:**
- Ensure query syntax is correct
- Check if logs contain the fields you're searching for
- Try simpler query first: `fields @message | limit 100`

### Problem: Alarms not sending emails

**Solution:**
```bash
# Verify SNS topic exists
aws sns list-topics

# Test SNS notification manually
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:ray-converter-lambda-alerts \
  --message "Test alert"
```

---

## 📊 Dashboard URLs

After deployment, access your dashboard:

```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=ray-converter-metrics
```

---

## ✨ Summary

You now have **enterprise-grade monitoring** with:
- ✅ Structured JSON logging
- ✅ Real-time log streaming
- ✅ Advanced log querying
- ✅ Automatic alarms
- ✅ Visual dashboard
- ✅ Email notifications

**Next steps:**
1. Deploy: `terraform apply`
2. Set your email in `terraform.tfvars`
3. Redeploy to enable notifications
4. Test by invoking Lambda
5. Check CloudWatch console
6. Monitor production! 🚀

---

**Questions?** Check AWS documentation:
- CloudWatch Logs: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/
- Logs Insights: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html
