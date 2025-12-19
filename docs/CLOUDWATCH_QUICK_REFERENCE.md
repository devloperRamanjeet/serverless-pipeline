````markdown
# 📊 CloudWatch Quick Reference Card

## 🚀 Deploy CloudWatch

```bash
cd infra
terraform apply
```

---

## 👀 View Logs

### Real-time streaming
```bash
aws logs tail /aws/lambda/ray-converter --follow
```

### Last 100 lines
```bash
aws logs tail /aws/lambda/ray-converter --max-items 100
```

### Specific time range
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/ray-converter \
  --start-time 1703000000000 \
  --end-time 1703003600000
```

---

## 📊 Open Dashboard

```
AWS Console → CloudWatch → Dashboards → ray-converter-metrics
```

Direct URL:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=ray-converter-metrics
```

---

## 🔎 CloudWatch Logs Insights Queries

### Copy & Paste These:

**Find All Errors**
```
fields @timestamp, @message, request_id
| filter @message like /ERROR/
| stats count() as error_count by @message
```

**Response Times Analysis**
```
fields @duration
| filter @duration > 0
| stats avg(@duration) as avg_ms, max(@duration) as max_ms, pct(@duration, 99) as p99_ms
```

**Success Rate**
```
fields @message
| filter @message like /Converted|ERROR/
| stats count(*) as total, sum(ispresent(@message, /Converted/)) as successful
| fields total, successful, round((successful / total) * 100) as success_rate_percent
```

**Slow Requests (>5 sec)**
```
fields @timestamp, @duration, request_id, @message
| filter @duration > 5000
| sort @duration desc
| limit 20
```

**Errors by Hour**
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() as error_count by bin(1h)
```

**Error Types**
```
fields @message, error_type
| filter @message like /ERROR/
| stats count() as count by error_type
| sort count desc
```

**Request Breakdown**
```
fields @message, request_id, input_size, output_size
| filter ispresent(@message, /Converted/)
| stats avg(input_size) as avg_input, avg(output_size) as avg_output, count() as total_requests
```

---

## 🚨 Check Alarms

```bash
# View all alarms
aws cloudwatch describe-alarms --alarm-name-prefix ray-converter

# View alarm state
aws cloudwatch describe-alarms --alarm-names ray-converter-high-error-rate
```

---

## ✉️ Enable Email Alerts

**Step 1:** Edit `infra/terraform.tfvars`
```terraform
alert_email = "your-email@example.com"
```

**Step 2:** Deploy
```bash
cd infra && terraform apply
```

**Step 3:** Confirm email subscription

---

## 🧪 Test Lambda

```bash
aws lambda invoke \
  --function-name ray-converter \
  --payload '{"ray": {"x": 10, "y": 20, "z": 30}}' \
  response.json

cat response.json
```

---

## 📈 Metrics Available

| Metric | From | Command |
|--------|------|---------|
| **ErrorCount** | Logs | `aws logs filter-log-events --log-group-name /aws/lambda/ray-converter` |
| **WarningCount** | Logs | Same as above |
| **SuccessfulConversions** | Logs | Same as above |
| **Invocations** | AWS Native | `aws cloudwatch get-metric-statistics` |
| **Errors** | AWS Native | Same as above |
| **Duration** | AWS Native | Same as above |
| **Throttles** | AWS Native | Same as above |

---

## 🎯 5-Minute Quick Debugging

1. **Check if Lambda is running:**
   ```bash
   aws logs tail /aws/lambda/ray-converter --follow
   ```

2. **Check dashboard:**
   ```
   Open: CloudWatch → Dashboards → ray-converter-metrics
   ```

3. **Find errors:**
   - Open CloudWatch Logs Insights
   - Paste: `fields @message | filter @message like /ERROR/`
   - Click "Run query"

4. **Get success rate:**
   - Paste success rate query (above)
   - See % of requests that succeeded

5. **Done!** 🎉

---

## 🛠️ Troubleshooting

| Problem | Solution |
|---------|----------|
| No logs appearing | Invoke Lambda with test event, wait 5 seconds |
| Dashboard empty | Ensure Lambda has been invoked at least once |
| Query fails | Check field names match your logs |
| No email alerts | Confirm SNS subscription in your email |
| Metrics not updating | They update every 1-5 minutes, wait a bit |

---

## 📚 Full Guides

- **CLOUDWATCH_MONITORING_GUIDE.md** - Complete guide with all details
- **README.md** - Quick start and overview
- **CLOUDWATCH_SETUP_SUMMARY.md** - What was added and how to use it

---

## 🔗 AWS Console Links

**Log Group:**
```
https://console.aws.amazon.com/logs/home?region=us-east-1#logStream:group=/aws/lambda/ray-converter
```

**Dashboard:**
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=ray-converter-metrics
```

**Alarms:**
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:alarmFilter=ray-converter
```

**Lambda Function:**
```
https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions/ray-converter
```

---

**Last Updated:** December 19, 2025
**Status:** ✅ Ready for Production

````