# 📘 Developer Guide: AI Utils Lambda Pipeline

This guide explains how to **develop, test, and deploy AWS Lambda functions** using **VSCode, GitHub Actions, Terraform, and SAM CLI**.  
We use a **global `requirements.txt`** for dependencies to keep things simple and fast.

---

## 🛠️ Step 1: Local Environment Setup

### Install tools
- Python 3.11 + `pip`
- VSCode (Python extension)
- AWS CLI → `aws configure`
- AWS SAM CLI → local Lambda testing
- Terraform → infra provisioning
- Git

### Clone repo
```bash
git clone https://github.com/your-org/ai-utils-pipeline.git
cd ai-utils-pipeline
```

**Folder structure (initial skeleton):**
```bash
repo-root/
│── .github/workflows/deploy.yml
│── infra/
│   ├── main.tf
│   └── sam-template.yaml
│── common/utils.py
│── functions/
│── events/
│── tests/
│── requirements.txt   # global dependencies
│── README.md
```

---

## 📝 Step 2: Write the First Function

Create a new folder under `functions/`:

```bash
mkdir functions/ray_converter
```

Add `handler.py`:

```python
def lambda_handler(event, context):
    ray_data = event.get("ray", {})
    converted = {"standard": ray_data}
    return {
        "statusCode": 200,
        "body": converted
    }
```

Add a unit test in `functions/ray_converter/tests/test_handler.py`:

```python
from handler import lambda_handler

def test_lambda_handler():
    event = {"ray": {"x": 1, "y": 2}}
    result = lambda_handler(event, None)
    assert result["statusCode"] == 200
    assert "standard" in result["body"]
```

**Folder structure after adding function:**
```bash
repo-root/
│── functions/
│   └── ray_converter/
│       ├── handler.py
│       └── tests/test_handler.py
│── events/
│   └── ray_event.json
│── requirements.txt
```

---

## 🧪 Step 3: Run Locally

### Option 1: Run Unit Tests (Fastest)

```bash
# Activate virtual environment
source .venv/bin/activate  # or .venv\Scripts\activate on Windows

# Run all tests
pytest functions/ray_converter/tests/ -v

# Run specific test
pytest functions/ray_converter/tests/test_handler.py::test_lambda_handler_success -v

# Run with coverage
pytest functions/ray_converter/tests/ --cov=functions/ray_converter --cov-report=html
```

### Option 2: Test Handler Manually with Python

```bash
# Test with sample event
python << 'EOF'
import json
import sys
sys.path.insert(0, "functions/ray_converter")
from handler import lambda_handler

# Load sample event
with open("events/ray_event.json") as f:
    event = json.load(f)

# Mock context
class MockContext:
    aws_request_id = "test-123"

# Run handler
result = lambda_handler(event, MockContext())
print(json.dumps(json.loads(result['body']), indent=2))
EOF
```

### Option 3: Use SAM CLI (Local Lambda Runtime)

```bash
# Install SAM CLI (if not already installed)
pip install aws-sam-cli

# Build and test locally
sam local start-api

# In another terminal, invoke the function
curl -X POST http://localhost:3000/ray \
  -H "Content-Type: application/json" \
  -d '{"ray": {"x": 10, "y": 20}}'
```

### Option 4: Create Custom Test Script

Create `test_locally.py` in the repo root:

```python
#!/usr/bin/env python
import json
import sys
sys.path.insert(0, "functions/ray_converter")
from handler import lambda_handler

def test_with_custom_data():
    test_cases = [
        {"name": "Basic", "ray": {"x": 10, "y": 20, "z": 30}},
        {"name": "Empty", "ray": {}},
        {"name": "Complex", "ray": {"coords": [1, 2, 3], "label": "test"}},
    ]
    
    class MockContext:
        aws_request_id = "local-test"
    
    for test in test_cases:
        event = test.copy()
        name = event.pop("name")
        result = lambda_handler(event, MockContext())
        print(f"✓ {name}: {result['statusCode']}")

if __name__ == "__main__":
    test_with_custom_data()
```

Run it:
```bash
python test_locally.py
```

---

## 📊 Sample Event in `events/ray_event.json`

```json
{ "ray": { "x": 10, "y": 20 } }
```

---

## 📂 Step 8: Push Code to GitHub

```bash
git add functions/ray_converter
git commit -m "Add ray_converter Lambda function"
git push origin main
```

This triggers the GitHub Actions pipeline.

---

## ☁️ Step 9: AWS Setup

- Create IAM role for Lambda execution.
- Create S3 bucket for deployment packages.
- Create API Gateway (if HTTP trigger needed).
- Configure Terraform backend (S3 + DynamoDB for state).

---

## ⚙️ Step 6: Configure Function Triggers

Instead of hardcoding triggers, use the **trigger configuration file** to enable/disable them easily.

### Trigger Configuration File: `config/triggers.yaml`

This file defines **how your Lambda function will be triggered**:

```yaml
functions:
  ray_converter:
    name: ray-converter
    runtime: python3.11
    
    # Enable/disable different trigger types
    api_gateway:
      enabled: true
      route: "POST /ray"
      
    sqs:
      enabled: false
      queue_name: "ray-converter-queue"
      
    s3:
      enabled: false
      bucket_name: "ray-converter-input"
      events: ["s3:ObjectCreated:*"]
      
    eventbridge:
      enabled: false
      schedule: "rate(1 hour)"
      
    # ... more triggers available
```

### Supported Triggers:

| Trigger Type | Use Case | Config Key |
|---|---|---|
| **API Gateway** | HTTP API endpoint (GET/POST) | `api_gateway` |
| **SQS** | Process async messages from queue | `sqs` |
| **S3** | Trigger on file upload | `s3` |
| **EventBridge** | Scheduled execution (cron/rate) | `eventbridge` |
| **DynamoDB** | Stream processing | `dynamodb` |
| **SNS** | Trigger on topic notification | `sns` |

### Enable/Disable Triggers:

1. **Enable API Gateway (HTTP endpoint):**
   ```yaml
   api_gateway:
     enabled: true
     route: "POST /ray"
   ```

2. **Enable SQS Queue:**
   ```yaml
   sqs:
     enabled: true
     queue_name: "ray-converter-queue"
     batch_size: 10
   ```

3. **Enable S3 Bucket Trigger:**
   ```yaml
   s3:
     enabled: true
     bucket_name: "ray-converter-input"
     events: ["s3:ObjectCreated:*"]
   ```

4. **Enable Scheduled Execution (EventBridge):**
   ```yaml
   eventbridge:
     enabled: true
     schedule: "rate(30 minutes)"  # or "cron(0 12 * * ? *)"
   ```

### View Enabled Triggers:

```bash
# Check which triggers are currently enabled
python common/trigger_config.py

# Output:
# ✅ Enabled Triggers:
# • API GATEWAY
#   Route: POST /ray
# • SQS
#   Queue: ray-converter-queue
#   Batch Size: 10
```

### Export Configuration:

```bash
# Export YAML config to JSON for use in scripts
python -c "from common.trigger_config import TriggerConfig; TriggerConfig().export_to_json()"
```

---

## ⚙️ Step 7: Terraform Infrastructure

Define Lambda + trigger in `infra/main.tf`:

```hcl
resource "aws_lambda_function" "ray_converter" {
  function_name = "ray_converter"
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "${path.module}/../build/ray_converter.zip"
}

resource "aws_apigatewayv2_route" "ray_converter_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /ray"
  target    = "integrations/${aws_apigatewayv2_integration.ray_converter_integration.id}"
}
```

Apply infra:

```bash
terraform init
terraform apply -auto-approve
```

---

## 🔄 Step 10: GitHub Actions Workflow

`.github/workflows/deploy.yml`:

```yaml
name: Deploy Lambda Functions

on:
  push:
    branches: [ "main" ]

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.11"

      - name: Install global dependencies
        run: pip install -r requirements.txt -t python/

      - name: Package Lambda functions
        run: |
          mkdir build
          for dir in functions/*; do
            cd $dir
            zip -r ../../build/$(basename $dir).zip . ../../python
            cd -
          done

      - name: Deploy with Terraform
        run: |
          cd infra
          terraform init
          terraform apply -auto-approve
```

---

# 🔄 Developer Workflow Recap
1. **Setup tools + clone repo** → skeleton folders + global `requirements.txt`.  
2. **Write function** → add folder + handler.  
3. **Test locally** → sample events + SAM CLI + pytest.  
4. **Push to GitHub** → pipeline triggers.  
5. **AWS setup** → IAM, S3, API Gateway defined in `infra/`.  
6. **Terraform infra** → reproducible infra + triggers.  
7. **YAML pipeline** → automated build + deploy with global dependencies.

---
# 📊 CloudWatch Monitoring for Production Debugging

Your Lambda function includes **enterprise-grade CloudWatch monitoring** for production debugging:

## What's Monitored

- ✅ **Structured Logs** - JSON-formatted logs for easy parsing
- ✅ **Real-time Metrics** - Errors, warnings, success rate tracked
- ✅ **Auto Alarms** - Email alerts on errors, timeouts, throttles
- ✅ **Visual Dashboard** - Pre-built metrics dashboard
- ✅ **Log Insights** - Advanced querying and analysis

## Quick Start

### View Live Logs

```bash
# Stream logs in real-time
aws logs tail /aws/lambda/ray-converter --follow

# View last 100 lines
aws logs tail /aws/lambda/ray-converter --max-items 100
```

### Open Dashboard

```
AWS Console → CloudWatch → Dashboards → ray-converter-metrics
```

### Enable Email Alerts

Edit `infra/terraform.tfvars`:
```terraform
enable_alarms = true
alert_email   = "your-email@example.com"  # Add your email
```

Then redeploy:
```bash
cd infra && terraform apply
```

### Query Logs in Logs Insights

Example query to find errors:
```
fields @timestamp, @message, request_id
| filter @message like /ERROR/
| stats count() as error_count by @message
```

## Full Documentation

See **[CLOUDWATCH_MONITORING_GUIDE.md](CLOUDWATCH_MONITORING_GUIDE.md)** for:
- Detailed monitoring setup
- All pre-built queries
- Production debugging workflows
- Troubleshooting guide
- Metrics explanations

---
# 📊 CODE FLOW DIAGRAM & EXECUTION PATH

## Local Development Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVELOPER'S LOCAL MACHINE                    │
└─────────────────────────────────────────────────────────────────┘

1️⃣  EDIT CODE
    ↓
    functions/ray_converter/handler.py
    ├─ Lambda function logic
    ├─ Input: event (Ray data)
    └─ Output: converted standard format

2️⃣  RUN LOCAL TESTS
    ↓
    pytest functions/ray_converter/tests/test_handler.py
    │
    ├─ test_lambda_handler_success
    ├─ test_lambda_handler_empty_ray
    ├─ test_lambda_handler_missing_ray_key
    └─ test_lambda_handler_with_none_context

3️⃣  TEST WITH SAM CLI (Local Server)
    ↓
    sam local start-api --port 3000
    │
    └─ Starts local API server at http://localhost:3000/ray
       ├─ Receives POST request with JSON body
       ├─ Calls: functions/ray_converter/handler.py → lambda_handler()
       ├─ Processes: event from request
       └─ Returns: JSON response with statusCode 200

4️⃣  TEST WITH CURL/POSTMAN
    ↓
    curl -X POST http://localhost:3000/ray \
      -H "Content-Type: application/json" \
      -d '{"ray": {"x": 10, "y": 20, "z": 30}}'
    │
    ├─ Request hits: functions/ray_converter/handler.py
    ├─ Files accessed:
    │   ├─ events/ray_event.json (sample data)
    │   └─ common/ (any utilities)
    └─ Response body contains converted data
```

---

## Push to Git & GitHub Actions Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                   LOCAL GIT REPOSITORY                          │
└─────────────────────────────────────────────────────────────────┘

5️⃣  COMMIT & PUSH CODE
    ↓
    $ git add functions/
    $ git commit -m "Update ray_converter handler"
    $ git push origin main
    │
    └─ Files pushed to GitHub:
       ├─ functions/ray_converter/handler.py
       ├─ functions/ray_converter/tests/test_handler.py
       ├─ requirements.txt
       └─ infra/ (all Terraform files)

┌─────────────────────────────────────────────────────────────────┐
│              GITHUB ACTIONS PIPELINE TRIGGERED                  │
│           (.github/workflows/deploy.yml executed)               │
└─────────────────────────────────────────────────────────────────┘

6️⃣  GITHUB ACTIONS: TEST JOB
    ↓
    Steps:
    ├─ Checkout: Clone repo
    ├─ Setup Python 3.11
    ├─ Install dependencies: pip install -r requirements.txt
    │  └─ Installs: pytest, boto3, aws-lambda-powertools
    │
    ├─ Run unit tests:
    │  └─ pytest functions/ray_converter/tests/ -v
    │     ├─ Runs all test_*.py files
    │     └─ If ANY test fails → Pipeline STOPS ❌
    │
    ├─ Check code formatting:
    │  ├─ black --check functions/
    │  └─ flake8 functions/
    │
    └─ If ALL tests pass → Proceed to BUILD JOB ✅

7️⃣  GITHUB ACTIONS: BUILD & DEPLOY JOB
    ↓
    Prerequisites: All tests passed
    
    Steps:
    ├─ Checkout code
    ├─ Setup Python 3.11
    │
    ├─ Install dependencies (with path):
    │  └─ pip install -r requirements.txt -t python/
    │     ├─ Creates: python/ directory with all packages
    │     └─ This gets zipped with Lambda code
    │
    ├─ Create build directory:
    │  └─ mkdir -p build/
    │
    ├─ PACKAGE LAMBDA FUNCTION:
    │  ├─ cd functions/ray_converter
    │  ├─ zip -r ../../build/ray_converter.zip . ../../python
    │  └─ Output: build/ray_converter.zip
    │     ├─ Contains: handler.py
    │     ├─ Contains: all dependencies (from python/)
    │     └─ Size: Ready for AWS Lambda
    │
    ├─ CONFIGURE AWS CREDENTIALS:
    │  └─ Uses GitHub Secrets:
    │     ├─ AWS_ACCESS_KEY_ID
    │     └─ AWS_SECRET_ACCESS_KEY
    │
    ├─ DEPLOY WITH TERRAFORM:
    │  ├─ cd infra
    │  ├─ terraform init
    │  │  └─ Initializes Terraform workspace
    │  │
    │  ├─ terraform plan -out=tfplan
    │  │  └─ Reviews what will be created
    │  │
    │  └─ terraform apply tfplan
    │     ├─ Creates AWS resources:
    │     │  ├─ AWS Lambda Function
    │     │  │  └─ Uses: build/ray_converter.zip
    │     │  ├─ AWS API Gateway
    │     │  ├─ AWS IAM Role
    │     │  ├─ AWS CloudWatch Logs
    │     │  └─ AWS Lambda Permissions
    │     │
    │     └─ Reads config from:
    │        ├─ infra/main.tf
    │        ├─ infra/triggers.tf
    │        ├─ infra/triggers_conditional.tf
    │        ├─ infra/variables.tf
    │        └─ infra/terraform.tfvars
    │
    └─ OUTPUT RESULTS:
       └─ terraform output
          ├─ Lambda ARN
          ├─ API Gateway Endpoint (YOUR API URL)
          └─ Log group name
```

---

## File Execution Flow During Different Stages

### Stage 1: Local Development
```
Your Code Change
    ↓
handler.py (EDITED)
    ├─ You make changes here
    └─ Add business logic
    
Run Local Test
    ↓
tests/test_handler.py (EXECUTED)
    ├─ Imports: from handler import lambda_handler
    ├─ Calls: lambda_handler(event, context)
    └─ Verifies: Results match expected output
    
Test with SAM
    ↓
template.yaml (READ by SAM)
    ├─ Defines: CodeUri: functions/ray_converter/
    └─ SAM starts Flask server at http://localhost:3000

cURL/Postman Request
    ↓
handler.py (CALLED)
    ├─ Entry point: lambda_handler(event, context)
    ├─ Reads: event["ray"] from request body
    ├─ Processes: Ray data
    └─ Returns: Converted format
    
events/ray_event.json (REFERENCE)
    └─ Shows example of what to send
```

### Stage 2: Push to GitHub
```
$ git push origin main
    ↓
GitHub receives push
    ↓
.github/workflows/deploy.yml (TRIGGERED)
    ├─ Reads: Files in push
    ├─ Checks: requirements.txt
    ├─ Runs: tests from functions/ray_converter/tests/
    └─ If OK: Proceeds to build
```

### Stage 3: Build & Package
```
.github/workflows/deploy.yml (CONTINUES)
    ↓
requirements.txt (READ)
    ├─ Installs all packages locally
    └─ Bundles into: python/ directory
    
handler.py (PACKAGED)
    ├─ Zipped with all dependencies
    └─ Output: build/ray_converter.zip
    
Terraform files (PREPARED)
    ├─ infra/main.tf
    ├─ infra/triggers.tf
    ├─ infra/triggers_conditional.tf
    ├─ infra/variables.tf
    └─ infra/terraform.tfvars
```

### Stage 4: Deploy to AWS
```
terraform init (SETUP)
    ├─ Downloads AWS provider plugin
    ├─ Creates: .terraform/ directory
    └─ Sets up: State management
    
terraform plan (REVIEW)
    ├─ Reads: infra/main.tf
    ├─ Checks: Current AWS state
    └─ Shows: What will change
    
terraform apply (DEPLOY)
    ├─ Reads: build/ray_converter.zip
    ├─ Creates: AWS Lambda Function
    │  ├─ Function name: ray-converter
    │  ├─ Handler: handler.lambda_handler
    │  ├─ Code: build/ray_converter.zip
    │  └─ Runtime: python3.11
    │
    ├─ Creates: API Gateway
    │  ├─ Route: POST /ray
    │  ├─ Integration: Lambda function
    │  └─ CORS: Enabled
    │
    ├─ Creates: IAM Role
    │  └─ Permissions: Lambda execution
    │
    ├─ Creates: CloudWatch Log Group
    │  └─ Name: /aws/lambda/ray-converter
    │
    └─ Outputs:
       ├─ api_gateway_endpoint
       ├─ lambda_function_arn
       └─ lambda_function_name
```

### Stage 5: Live API Usage
```
After Deployment
    ↓
Your API is LIVE at:
    https://xxxxx.execute-api.us-east-1.amazonaws.com/dev/ray
    
POST Request
    ↓
API Gateway receives
    ├─ Route: POST /ray
    ├─ Validates: CORS
    └─ Forwards to: Lambda
    
AWS Lambda Execution
    ├─ Loads: build/ray_converter.zip
    ├─ Executes: handler.lambda_handler()
    ├─ Reads: event from request body
    ├─ Processes: Ray data conversion
    ├─ Logs to: CloudWatch (/aws/lambda/ray-converter)
    └─ Returns: JSON response
    
Response sent back
    ├─ Status: 200 (on success)
    ├─ Body: Converted ray data
    └─ User receives: Result
```

---

## Which Files Get Hit at Each Stage

### 🔴 Local Testing (Your Machine)
| Stage | Primary Files | Secondary Files |
|-------|------|---------|
| Edit Code | `functions/ray_converter/handler.py` | `common/utils.py` |
| Run Tests | `functions/ray_converter/tests/test_handler.py` | `requirements.txt` |
| SAM Local | `template.yaml` | `functions/ray_converter/handler.py` |
| Manual Test | `events/ray_event.json` | `handler.py` |

### 🔵 GitHub Actions (Automated)
| Stage | Primary Files | Secondary Files |
|-------|------|---------|
| Trigger | `.github/workflows/deploy.yml` | All changed files |
| Test | `requirements.txt` | `functions/ray_converter/tests/` |
| Build | `functions/ray_converter/handler.py` | `requirements.txt` |
| Package | `build/ray_converter.zip` (output) | All Python files |
| Deploy | `infra/main.tf`, `infra/triggers.tf` | `infra/variables.tf`, `terraform.tfvars` |

### 🟢 AWS (After Deployment)
| Stage | Files Executed | Where |
|-------|------|---------|
| API Call | `build/ray_converter.zip` | AWS Lambda |
| Handler | `handler.lambda_handler()` | Lambda runtime |
| Logging | Outputs to | `/aws/lambda/ray-converter` CloudWatch |

---

## Next Steps After Each Stage

### After Local Testing ✅
```
If ALL tests pass:
    ↓
$ git add functions/ infra/ requirements.txt
$ git commit -m "Ray converter Lambda function ready"
$ git push origin main
```

### After Push to GitHub 🔄
```
GitHub Actions automatically:
    ├─ Runs tests
    ├─ Builds package
    ├─ Deploys to AWS
    └─ Sends status back
```

### After Deployment ✅
```
Lambda is LIVE!
    ├─ API Endpoint: terraform output api_gateway_endpoint
    ├─ Test: curl -X POST <endpoint> ...
    ├─ Monitor: AWS Console → Lambda
    └─ Logs: CloudWatch → /aws/lambda/ray-converter
```

### To Update Code 🔄
```
1. Edit: functions/ray_converter/handler.py
2. Test: pytest functions/ray_converter/tests/
3. Push: git push origin main
4. GitHub Actions auto-deploys the changes
5. Your API is updated (no manual steps needed!)
```

---

## Configuration Flow

### Trigger Configuration
```
config/triggers.yaml (YOU EDIT THIS)
    ↓
common/trigger_config.py (READS & PARSES)
    ├─ Validates YAML
    ├─ Checks enabled triggers
    └─ Exports to JSON
    
infra/triggers_conditional.tf (USES THIS)
    ├─ Reads trigger settings
    ├─ Creates enabled resources
    └─ Skips disabled ones
```

### How to Enable More Triggers
```
1. Edit config/triggers.yaml
   sqs:
     enabled: true    # Change from false to true
     
2. Run: python common/trigger_config.py
   └─ Validates your changes
   
3. Deploy: cd infra && terraform apply
   └─ Creates SQS queue + Lambda mapping
   
4. Result: Lambda now triggers from SQS!
```  
