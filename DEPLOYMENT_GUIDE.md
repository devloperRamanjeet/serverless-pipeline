# 🚀 DEPLOYMENT GUIDE - Ray Converter Lambda

## ✅ Project Status: READY FOR DEPLOYMENT

All components are complete and tested:
- ✅ Lambda handler with error handling
- ✅ Unit tests (4/4 passing)
- ✅ Terraform infrastructure code
- ✅ GitHub Actions CI/CD pipeline
- ✅ Trigger configuration system
- ✅ Local testing setup (SAM CLI)
- ✅ API documentation

---

## 📋 Pre-Deployment Checklist

### 1. AWS Account Setup
- [ ] AWS Account created
- [ ] AWS CLI installed: `aws --version`
- [ ] AWS credentials configured: `aws configure`
- [ ] Verify access: `aws sts get-caller-identity`

### 2. AWS Permissions
- [ ] IAM user has these permissions:
  - Lambda full access
  - API Gateway full access
  - IAM role creation
  - CloudWatch logs write
  - (Recommended: Use AdministratorAccess for first deployment)

### 3. Local Tools
- [ ] Terraform installed: `terraform -version`
- [ ] AWS CLI configured: `aws configure list`
- [ ] Git installed: `git --version`

### 4. GitHub Setup (for CI/CD)
- [ ] Repository created on GitHub
- [ ] Repository cloned locally
- [ ] AWS credentials added to GitHub Secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

---

## �� Deployment Steps

### Step 1: Verify AWS Access
```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDXXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

### Step 2: Initialize Terraform
```bash
cd /Users/ramanjeet/devlopment/serverless-AiMl/infra
terraform init
```

This will:
- Download Terraform AWS provider
- Create `.terraform` directory
- Initialize Terraform workspace

### Step 3: Review Deployment Plan
```bash
terraform plan -out=tfplan
```

This will show what will be created:
```
Plan: 6 to add, 0 to change, 0 to destroy.
```

Review the output carefully!

### Step 4: Deploy to AWS
```bash
terraform apply tfplan
```

Wait for completion (usually 1-2 minutes).

### Step 5: Get API Endpoint
```bash
terraform output api_gateway_endpoint
```

This will show your API URL:
```
https://xxxxx.execute-api.us-east-1.amazonaws.com/dev/ray
```

Save this URL - you'll use it for testing!

---

## 📊 What Gets Created

### AWS Resources

| Resource | Count | Purpose |
|----------|-------|---------|
| Lambda Function | 1 | ray-converter |
| IAM Role | 1 | Lambda execution permissions |
| API Gateway | 1 | HTTP API for endpoint |
| CloudWatch Log Group | 1 | Lambda logs |
| Lambda Permission | 1 | API Gateway invoke |

### Estimated Costs (Monthly)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1M requests free tier | ~$0 |
| API Gateway | 1M requests free tier | ~$0 |
| CloudWatch | 5GB free tier | ~$0 |
| **Total** | | ~$0 (under free tier) |

---

## 🧪 Post-Deployment Testing

### Test 1: Get Outputs
```bash
cd infra
terraform output
```

### Test 2: Test with cURL
```bash
API_URL=$(cd infra && terraform output -raw api_gateway_endpoint)

curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "ray": {
      "x": 10,
      "y": 20,
      "z": 30
    }
  }'
```

Expected response:
```json
{
  "statusCode": 200,
  "body": {
    "standard": {
      "x": 10,
      "y": 20,
      "z": 30
    },
    "timestamp": "aws-request-id"
  }
}
```

### Test 3: Test with Postman
1. Get API URL from `terraform output`
2. Open Postman
3. Create POST request to your API URL
4. Add header: `Content-Type: application/json`
5. Add body with JSON (see POSTMAN_GUIDE.md)
6. Send and verify response

### Test 4: Check CloudWatch Logs
```bash
# View Lambda logs
aws logs tail /aws/lambda/ray-converter --follow
```

---

## 🔄 GitHub Actions CI/CD

After deployment, push to GitHub to trigger automation:

```bash
git add .
git commit -m "Deploy Ray Converter Lambda"
git push origin main
```

GitHub Actions will:
1. Run unit tests
2. Check code formatting
3. Package Lambda function
4. Deploy with Terraform

---

## 🛠️ Updating Deployment

### Update Lambda Code
```bash
# Edit handler.py
nano functions/ray_converter/handler.py

# Test locally
pytest functions/ray_converter/tests/ -v

# Push to Git (auto-deploys via GitHub Actions)
git add functions/
git commit -m "Update handler logic"
git push origin main
```

### Update Configuration
```bash
# Edit trigger configuration
nano config/triggers.yaml

# Plan changes
cd infra
terraform plan

# Apply changes
terraform apply
```

### Update Infrastructure
```bash
# Edit Terraform files
nano infra/main.tf

# Plan changes
terraform plan

# Apply changes
terraform apply
```

---

## ⚠️ Destroying Deployment

To remove all AWS resources:

```bash
cd infra
terraform destroy
```

**WARNING:** This will delete:
- Lambda function
- API Gateway
- IAM role
- CloudWatch logs

---

## 🐛 Troubleshooting

### Error: "Access Denied"
```
Fix: Check AWS credentials
    aws sts get-caller-identity
    Check IAM permissions
```

### Error: "API Gateway not reachable"
```
Fix: Wait 1-2 minutes after deployment
    Check API URL: terraform output
    Check security groups
```

### Error: "Lambda timeout"
```
Fix: Increase timeout in infra/main.tf
    timeout = 60  (default is 30)
    Re-apply: terraform apply
```

### Lambda returns 500 error
```
Fix: Check CloudWatch logs
    aws logs tail /aws/lambda/ray-converter --follow
    Check handler.py for exceptions
```

---

## 📞 Support Commands

```bash
# Get Lambda function details
aws lambda get-function --function-name ray-converter

# Get API Gateway details
aws apigatewayv2 get-apis

# View recent invocations
aws lambda get-function-concurrency --function-name ray-converter

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda

# Check deployed version
terraform show
```

---

## 🎯 Next Steps After Deployment

1. **Monitor in AWS Console**
   - Lambda → ray-converter
   - API Gateway → ray-converter-api
   - CloudWatch → Logs

2. **Set Up Alarms**
   - Lambda error rate
   - API Gateway latency
   - Throttling alerts

3. **Enable X-Ray Tracing** (optional)
   - Update Terraform code
   - Redeploy: `terraform apply`

4. **Scale Configuration**
   - Increase memory if needed
   - Adjust timeout
   - Add more triggers

5. **Production Setup**
   - Use separate environments (dev/staging/prod)
   - Add S3 backend for Terraform state
   - Enable VPC if needed
   - Add authentication/authorization

---

## 📚 Useful Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)

---

## ✅ Deployment Checklist Summary

- [ ] AWS account verified
- [ ] AWS CLI configured
- [ ] Terraform initialized
- [ ] Deployment plan reviewed
- [ ] Resources deployed
- [ ] API tested locally
- [ ] API tested on AWS
- [ ] CloudWatch logs verified
- [ ] GitHub Actions workflow confirmed
- [ ] Documentation updated

---

**Congratulations! Your Lambda function is now deployed! 🎉**

