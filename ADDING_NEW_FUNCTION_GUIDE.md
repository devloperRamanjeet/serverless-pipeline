# 📝 Adding a New Function - Complete Guide

This guide walks through **all the steps and files needed** to add a new Lambda function to your serverless pipeline.

---

## 🎯 Overview: What Needs to Change

When adding a new function, you'll modify/create files in **5 areas**:

```
1. CODE
   ├─ functions/new_function_name/
   │  ├─ handler.py (new)
   │  └─ tests/test_handler.py (new)
   └─ events/new_function_event.json (new)

2. INFRASTRUCTURE
   ├─ infra/main.tf (add Lambda resource)
   ├─ infra/triggers.tf (add trigger)
   └─ infra/variables.tf (optional: new variables)

3. CONFIGURATION
   ├─ config/triggers.yaml (add function config)
   └─ requirements.txt (if new dependencies)

4. AUTOMATION
   └─ .github/workflows/deploy.yml (usually no change needed)

5. DOCUMENTATION
   ├─ README.md (document new function)
   └─ events/ (sample events)
```

---

## 🚀 Step-by-Step: Adding "image_processor" Function

### Example: We're adding an image processor function

Let me show you exactly what to do...

---

## Step 1: Create Function Folder Structure

```bash
# Create directory for new function
mkdir -p functions/image_processor/tests

# Create empty files
touch functions/image_processor/handler.py
touch functions/image_processor/tests/test_handler.py
touch functions/image_processor/tests/__init__.py
touch events/image_processor_event.json
```

**Result:**
```
functions/
├── ray_converter/       (existing)
│   ├── handler.py
│   └── tests/
│
└── image_processor/     (NEW)
    ├── handler.py       (NEW)
    └── tests/           (NEW)
        ├── __init__.py  (NEW)
        └── test_handler.py (NEW)

events/
├── ray_event.json       (existing)
└── image_processor_event.json  (NEW)
```

---

## Step 2: Write the Function Handler

**File:** `functions/image_processor/handler.py`

```python
import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class StructuredLogger:
    """Wrapper for structured logging to CloudWatch"""
    
    def __init__(self, logger):
        self.logger = logger
    
    def log(self, level, message, **kwargs):
        """Log structured data to CloudWatch"""
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": level,
            "message": message,
            **kwargs
        }
        self.logger.log(getattr(logging, level), json.dumps(log_entry))
    
    def info(self, message, **kwargs):
        self.log("INFO", message, **kwargs)
    
    def error(self, message, **kwargs):
        self.log("ERROR", message, **kwargs)
    
    def warning(self, message, **kwargs):
        self.log("WARNING", message, **kwargs)


structured_logger = StructuredLogger(logger)


def lambda_handler(event, context):
    """
    Process image - resize, convert format, etc.
    
    Args:
        event: Lambda event containing image data
        context: Lambda context
    
    Returns:
        Response object with processed image metadata
    """
    request_id = context.aws_request_id if context else "local-test"
    
    try:
        structured_logger.info(
            "Received image processing request",
            request_id=request_id,
            event_keys=list(event.keys())
        )
        
        # Extract image data
        image_data = event.get("image", {})
        
        if not image_data:
            structured_logger.warning(
                "Empty image data received",
                request_id=request_id
            )
        
        # Process image (your business logic here)
        processed = {
            "original_size": len(json.dumps(image_data)),
            "format": image_data.get("format", "unknown"),
            "width": image_data.get("width"),
            "height": image_data.get("height"),
            "processed_at": datetime.utcnow().isoformat()
        }
        
        structured_logger.info(
            "Image processed successfully",
            request_id=request_id,
            format=processed["format"]
        )
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "status": "success",
                "data": processed
            })
        }
    
    except Exception as e:
        structured_logger.error(
            "Error processing image",
            request_id=request_id,
            error=str(e),
            error_type=type(e).__name__
        )
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Image processing failed"})
        }
```

---

## Step 3: Create Unit Tests

**File:** `functions/image_processor/tests/test_handler.py`

```python
import json
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from handler import lambda_handler


class MockContext:
    """Mock Lambda context for testing"""
    aws_request_id = "test-image-123"
    function_name = "image-processor"


def test_image_processor_success():
    """Test successful image processing"""
    event = {
        "image": {
            "format": "jpeg",
            "width": 1920,
            "height": 1080,
            "data": "base64encodeddata..."
        }
    }
    context = MockContext()
    
    result = lambda_handler(event, context)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["status"] == "success"
    assert body["data"]["format"] == "jpeg"


def test_image_processor_empty_image():
    """Test with empty image"""
    event = {"image": {}}
    context = MockContext()
    
    result = lambda_handler(event, context)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["status"] == "success"


def test_image_processor_missing_key():
    """Test with missing image key"""
    event = {}
    context = MockContext()
    
    result = lambda_handler(event, context)
    
    assert result["statusCode"] == 200


def test_image_processor_with_none_context():
    """Test with None context"""
    event = {"image": {"format": "png", "width": 800}}
    
    result = lambda_handler(event, None)
    
    assert result["statusCode"] == 200
```

**File:** `functions/image_processor/tests/__init__.py`

```python
# Empty file to make tests a package
```

---

## Step 4: Create Sample Event

**File:** `events/image_processor_event.json`

```json
{
  "image": {
    "format": "jpeg",
    "width": 1920,
    "height": 1080,
    "size_bytes": 2048576,
    "data": "base64encodedimagedata..."
  }
}
```

---

## Step 5: Update Terraform Infrastructure

### Part A: Add Lambda Function to main.tf

**File:** `infra/main.tf` (add this at the end)

```terraform
# Lambda function for image_processor
resource "aws_lambda_function" "image_processor" {
  filename      = data.archive_file.image_processor_zip.output_path
  function_name = "image-processor"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60  # Images might take longer
  memory_size   = 512  # More memory for image processing

  source_code_hash = data.archive_file.image_processor_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Archive the image_processor function code
data "archive_file" "image_processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/image_processor"
  output_path = "${path.module}/../build/image_processor.zip"
}

# CloudWatch Log Group for image_processor
resource "aws_cloudwatch_log_group" "image_processor_logs" {
  name              = "/aws/lambda/image-processor"
  retention_in_days = var.log_retention_days
}

# Output for new function
output "image_processor_function_arn" {
  value       = aws_lambda_function.image_processor.arn
  description = "ARN of the image_processor Lambda function"
}

output "image_processor_function_name" {
  value       = aws_lambda_function.image_processor.function_name
  description = "Name of the image_processor Lambda function"
}
```

### Part B: Add API Gateway Trigger to triggers.tf

**File:** `infra/triggers.tf` (add this section)

```terraform
# ============================================================
# API Gateway: image_processor endpoint
# ============================================================

# Route for image_processor
resource "aws_apigatewayv2_route" "image_processor_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /process-image"
  target    = "integrations/${aws_apigatewayv2_integration.image_processor_integration.id}"
}

# Integration
resource "aws_apigatewayv2_integration" "image_processor_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  
  integration_method = "POST"
  integration_uri    = aws_lambda_function.image_processor.invoke_arn
  payload_format_version = "2.0"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "image_processor_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
```

---

## Step 6: Add Conditional Triggers (Optional)

**File:** `infra/triggers_conditional.tf` (add this section)

```terraform
# ============================================================
# Conditional Triggers for image_processor
# ============================================================

# S3 Trigger (for image uploads)
resource "aws_s3_bucket" "image_input_bucket" {
  count  = local.image_processor_triggers.s3.enabled ? 1 : 0
  bucket = "image-processor-input-${var.environment}"
  
  tags = {
    Name        = "image-processor-input"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_notification" "image_processor_s3_notification" {
  count      = local.image_processor_triggers.s3.enabled ? 1 : 0
  bucket     = aws_s3_bucket.image_input_bucket[0].id
  depends_on = [aws_lambda_permission.image_processor_s3]

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".jpg,.png"
  }
}

resource "aws_lambda_permission" "image_processor_s3" {
  count         = local.image_processor_triggers.s3.enabled ? 1 : 0
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::image-processor-input-${var.environment}"
}

# Locals for trigger configuration
locals {
  image_processor_config = try(local.trigger_config.functions.image_processor, {})
  
  image_processor_triggers = {
    s3 = {
      enabled = try(local.image_processor_config.s3.enabled, false)
    }
    sqs = {
      enabled = try(local.image_processor_config.sqs.enabled, false)
    }
  }
}
```

---

## Step 7: Update Configuration File

**File:** `config/triggers.yaml` (add new section)

```yaml
functions:
  ray_converter:
    # ... existing ray_converter config ...
  
  image_processor:  # NEW FUNCTION
    name: image-processor
    runtime: python3.11
    memory: 512
    timeout: 60
    
    # API Gateway trigger
    api_gateway:
      enabled: true
      route: "POST /process-image"
      cors: true
    
    # S3 trigger (optional)
    s3:
      enabled: false
      bucket_name: "image-processor-input"
      events: ["s3:ObjectCreated:*"]
      filter_prefix: "uploads/"
      filter_suffix: ".jpg,.png"
    
    # SQS trigger (optional)
    sqs:
      enabled: false
      queue_name: "image-processor-queue"
      batch_size: 5
    
    # EventBridge trigger (optional)
    eventbridge:
      enabled: false
      schedule: "rate(1 day)"
```

---

## Step 8: Update Trigger Configuration Parser

**File:** `common/trigger_config.py` (update get_enabled_triggers method)

The existing code should handle this automatically, but verify:

```python
# Existing code already loops through all functions, so just make sure
# your new function is in config/triggers.yaml with correct format

def get_enabled_triggers(self):
    """Get all enabled triggers for all functions"""
    enabled = {}
    for func_name, func_config in self.config.get('functions', {}).items():
        enabled[func_name] = {}
        for trigger_type, trigger_config in func_config.items():
            if trigger_type != 'name' and trigger_config.get('enabled', False):
                enabled[func_name][trigger_type] = trigger_config
    return enabled
```

---

## Step 9: Update GitHub Actions Workflow

**File:** `.github/workflows/deploy.yml` (usually NO CHANGES needed!)

The existing workflow already handles new functions because:
- It runs `pytest functions/` (finds all test files)
- It zips all folders in `functions/`
- Terraform reads all `infra/*.tf` files

**BUT if you have special testing needs**, update the test section:

```yaml
- name: Run unit tests
  run: |
    pytest functions/ray_converter/tests/ -v --tb=short
    pytest functions/image_processor/tests/ -v --tb=short  # NEW
```

Or simpler (already works):
```yaml
- name: Run unit tests
  run: |
    pytest functions/ -v --tb=short  # Finds all test files
```

---

## Step 10: Update requirements.txt

**File:** `requirements.txt` (if needed)

If your new function needs additional dependencies:

```txt
pytest==7.4.3
boto3==1.34.0
aws-lambda-powertools==2.30.1
pyyaml==6.0.3
# Add new dependencies here if needed:
pillow==10.0.0  # For image processing example
```

---

## Step 11: Update Documentation

**File:** `README.md` (add new function section)

```markdown
## Available Functions

### 1. ray_converter
- **Purpose:** Convert Ray format data to standard format
- **Trigger:** HTTP API Gateway (POST /ray)
- **Handler:** `functions/ray_converter/handler.py`

### 2. image_processor  (NEW)
- **Purpose:** Process and transform images
- **Trigger:** HTTP API Gateway (POST /process-image)
- **Alternative Triggers:** S3 uploads, SQS queue
- **Handler:** `functions/image_processor/handler.py`
- **Sample Event:** `events/image_processor_event.json`
```

---

## Step 12: Commit All Changes

```bash
# Add all new files
git add functions/image_processor/
git add events/image_processor_event.json
git add infra/
git add config/triggers.yaml
git add requirements.txt
git add README.md

# Commit with clear message
git commit -m "Add image_processor Lambda function

- New function: image_processor with API Gateway trigger
- Includes unit tests (4 tests)
- Infrastructure: Lambda, API route, CloudWatch logs
- Configuration: Supports S3 and SQS triggers (optional)
- Sample event: events/image_processor_event.json
"

# Push to trigger GitHub Actions
git push origin main
```

---

## 📋 Checklist: All Changes Required

When adding a new function, verify you've completed:

### Code Changes ✅
- [ ] `functions/new_func/handler.py` - Main function code
- [ ] `functions/new_func/tests/test_handler.py` - Unit tests (minimum 3)
- [ ] `functions/new_func/tests/__init__.py` - Package marker
- [ ] `events/new_func_event.json` - Sample event

### Infrastructure Changes ✅
- [ ] `infra/main.tf` - Add Lambda function resource
- [ ] `infra/main.tf` - Add archive_file resource
- [ ] `infra/main.tf` - Add CloudWatch log group
- [ ] `infra/main.tf` - Add outputs
- [ ] `infra/triggers.tf` - Add API Gateway route/integration
- [ ] `infra/triggers_conditional.tf` - Add optional triggers (S3, SQS, etc)

### Configuration Changes ✅
- [ ] `config/triggers.yaml` - Add function configuration
- [ ] `requirements.txt` - Add dependencies (if needed)

### Automation Changes ✅
- [ ] `.github/workflows/deploy.yml` - Usually no change (already generic)

### Documentation Changes ✅
- [ ] `README.md` - Document new function
- [ ] Function docstring - Explain what it does
- [ ] Sample event - Show example usage

---

## 🧪 Test New Function Locally

```bash
# 1. Activate environment
source .venv/bin/activate

# 2. Run unit tests
pytest functions/image_processor/tests/ -v

# 3. Test with sample event
python << 'EOF'
import json
import sys
sys.path.insert(0, "functions/image_processor")
from handler import lambda_handler

class MockContext:
    aws_request_id = "local-test-123"

with open("events/image_processor_event.json") as f:
    event = json.load(f)

result = lambda_handler(event, MockContext())
print(json.dumps(json.loads(result['body']), indent=2))
EOF

# 4. Test with SAM (if updating template.yaml)
sam local start-api --port 3000
# In another terminal:
curl -X POST http://localhost:3000/process-image \
  -H "Content-Type: application/json" \
  -d @events/image_processor_event.json
```

---

## 🚀 Deploy New Function

```bash
# 1. Verify code locally
pytest functions/ -v

# 2. Push to GitHub
git push origin main

# 3. GitHub Actions automatically:
#    - Runs tests
#    - Builds package
#    - Deploys with Terraform
#    - Creates Lambda function
#    - Creates API endpoint
#    - Sets up CloudWatch

# 4. Get the new endpoint
cd infra
terraform output api_gateway_endpoint

# 5. Test the live endpoint
curl -X POST https://xxxxx.execute-api.us-east-1.amazonaws.com/dev/process-image \
  -H "Content-Type: application/json" \
  -d @events/image_processor_event.json
```

---

## 🎯 Key Points to Remember

### 1. **Follow Naming Conventions**
```
function_name (code):       image_processor
function_name (AWS Lambda): image-processor (dashes, not underscores)
handler file:               handler.py (always)
handler function:           lambda_handler (always)
```

### 2. **Keep Each Function Independent**
```
functions/
├── ray_converter/
│   ├── handler.py        (independent)
│   └── tests/            (independent)
│
└── image_processor/
    ├── handler.py        (independent)
    └── tests/            (independent)
```

### 3. **Shared Code Goes to `common/`**
```
functions/*/handler.py  - Function specific
common/*.py             - Shared utilities
```

### 4. **Test Before Pushing**
```bash
# Always run tests locally
pytest functions/ -v

# Check formatting
black --check functions/
flake8 functions/
```

### 5. **Update Docs**
```
Every new function needs:
├─ Handler docstring
├─ README.md entry
├─ Sample event file
└─ Unit tests (minimum 3)
```

---

## 📊 Complete File Structure After Adding image_processor

```
serverless-AiMl/
├── functions/
│   ├── ray_converter/
│   │   ├── handler.py
│   │   └── tests/
│   │       ├── __init__.py
│   │       └── test_handler.py
│   │
│   └── image_processor/          (NEW)
│       ├── handler.py            (NEW)
│       └── tests/                (NEW)
│           ├── __init__.py       (NEW)
│           └── test_handler.py   (NEW)
│
├── events/
│   ├── ray_event.json
│   └── image_processor_event.json (NEW)
│
├── infra/
│   ├── main.tf                   (MODIFIED - add Lambda)
│   ├── triggers.tf               (MODIFIED - add API route)
│   ├── triggers_conditional.tf   (MODIFIED - add optional triggers)
│   ├── variables.tf
│   └── terraform.tfvars
│
├── config/
│   ├── triggers.yaml             (MODIFIED - add config)
│   └── triggers.json
│
├── common/
│   ├── trigger_config.py
│   └── utils.py
│
├── .github/workflows/
│   └── deploy.yml                (Usually no change)
│
├── requirements.txt              (MODIFIED if new deps)
└── README.md                     (MODIFIED - document)
```

---

## 🔄 Example: Quick Add Another Function

Once you understand the pattern, adding a 3rd function is quick:

```bash
# 1. Create structure
mkdir -p functions/data_validator/tests
touch functions/data_validator/handler.py
touch functions/data_validator/tests/test_handler.py
touch functions/data_validator/tests/__init__.py
touch events/data_validator_event.json

# 2. Copy handler template from existing function
cp functions/image_processor/handler.py functions/data_validator/handler.py
# Edit to add your logic

# 3. Copy test template
cp functions/image_processor/tests/test_handler.py functions/data_validator/tests/test_handler.py
# Update tests

# 4. Add to config/triggers.yaml
# Copy image_processor section and modify

# 5. Add to infra/main.tf
# Copy image_processor resources and modify names

# 6. Add to infra/triggers.tf
# Copy API Gateway route and modify endpoint

# 7. Run tests
pytest functions/ -v

# 8. Push
git push
```

**Total time for experienced developer:** ~10-15 minutes

---

## 📞 Questions?

- **Adding different trigger types?** See `infra/triggers_conditional.tf`
- **Sharing code between functions?** Put in `common/`
- **Need specific permissions?** Update IAM policy in `infra/main.tf`
- **Dependencies?** Add to `requirements.txt`
- **Environment variables?** Add to `environment { variables {} }` in Lambda resource
