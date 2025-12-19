# ⚡ Quick Checklist: Adding a New Function

Use this quick reference when adding a new Lambda function.

**Replacing `function_name` with your actual name** (e.g., `image_processor`)

---

## 📋 Pre-Creation Checklist

- [ ] Function name decided (snake_case, e.g., `image_processor`)
- [ ] AWS name ready (kebab-case, e.g., `image-processor`)
- [ ] API route decided (e.g., `POST /process-image`)
- [ ] Purpose clearly defined
- [ ] Test cases planned (minimum 3)

---

## 📁 Step 1: Create Folders & Files

```bash
# Copy-paste this entire block:
mkdir -p functions/function_name/tests
touch functions/function_name/handler.py
touch functions/function_name/tests/__init__.py
touch functions/function_name/tests/test_handler.py
touch events/function_name_event.json
```

---

## 📝 Step 2: Create Files (Copy Templates)

### handler.py Template

```python
import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class StructuredLogger:
		def __init__(self, logger):
				self.logger = logger
    
		def log(self, level, message, **kwargs):
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
		"""YOUR FUNCTION DESCRIPTION HERE"""
		request_id = context.aws_request_id if context else "local-test"
    
		try:
				structured_logger.info(
						"Processing request",
						request_id=request_id,
						event_keys=list(event.keys())
				)
        
				# YOUR LOGIC HERE
        
				return {
						"statusCode": 200,
						"body": json.dumps({"status": "success"})
				}
    
		except Exception as e:
				structured_logger.error(
						"Error",
						request_id=request_id,
						error=str(e),
						error_type=type(e).__name__
				)
				return {
						"statusCode": 500,
						"body": json.dumps({"error": str(e)})
				}
```

### test_handler.py Template

```python
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from handler import lambda_handler

class MockContext:
		aws_request_id = "test-123"
		function_name = "test-function"

def test_success():
		event = {"key": "value"}
		result = lambda_handler(event, MockContext())
		assert result["statusCode"] == 200

def test_empty():
		event = {}
		result = lambda_handler(event, MockContext())
		assert result["statusCode"] == 200

def test_none_context():
		event = {"key": "value"}
		result = lambda_handler(event, None)
		assert result["statusCode"] == 200

def test_error_handling():
		# Test error case
		event = {"invalid": True}
		result = lambda_handler(event, MockContext())
		# Expect 200 or 500 depending on logic
```

### __init__.py

```python
# Empty file - no content needed
```

### Sample Event

```json
{
	"key": "value",
	"data": "sample data"
}
```

---

## ⚙️ Step 3: Infrastructure Changes

### Add to `infra/main.tf`

```terraform
# Lambda function for function_name
resource "aws_lambda_function" "function_name" {
	filename      = data.archive_file.function_name_zip.output_path
	function_name = "function-name"
	role          = aws_iam_role.lambda_exec_role.arn
	handler       = "handler.lambda_handler"
	runtime       = "python3.11"
	timeout       = 30
	memory_size   = 128

	source_code_hash = data.archive_file.function_name_zip.output_base64sha256

	environment {
		variables = {
			LOG_LEVEL = "INFO"
		}
	}

	depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Archive
data "archive_file" "function_name_zip" {
	type        = "zip"
	source_dir  = "${path.module}/../functions/function_name"
	output_path = "${path.module}/../build/function_name.zip"
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "function_name_logs" {
	name              = "/aws/lambda/function-name"
	retention_in_days = var.log_retention_days
}

# Outputs
output "function_name_function_arn" {
	value       = aws_lambda_function.function_name.arn
	description = "ARN of function_name Lambda"
}

output "function_name_function_name" {
	value       = aws_lambda_function.function_name.function_name
	description = "Name of function_name Lambda"
}
```

### Add to `infra/triggers.tf`

```terraform
# API Gateway route
resource "aws_apigatewayv2_route" "function_name_route" {
	api_id    = aws_apigatewayv2_api.http_api.id
	route_key = "POST /api-path"  # CHANGE THIS
	target    = "integrations/${aws_apigatewayv2_integration.function_name_integration.id}"
}

# Integration
resource "aws_apigatewayv2_integration" "function_name_integration" {
	api_id           = aws_apigatewayv2_api.http_api.id
	integration_type = "AWS_PROXY"
	integration_method = "POST"
	integration_uri    = aws_lambda_function.function_name.invoke_arn
	payload_format_version = "2.0"
}

# Permission
resource "aws_lambda_permission" "function_name_api" {
	statement_id  = "AllowAPIGatewayInvoke"
	action        = "lambda:InvokeFunction"
	function_name = aws_lambda_function.function_name.function_name
	principal     = "apigateway.amazonaws.com"
	source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
```

---

## 📋 Step 4: Configuration

### Add to `config/triggers.yaml`

```yaml
	function_name:           # Replace with your function name
		name: function-name    # Replace with AWS name
		runtime: python3.11
		memory: 128
		timeout: 30
    
		api_gateway:
			enabled: true
			route: "POST /api-path"
			cors: true
    
		sqs:
			enabled: false
			queue_name: "function-name-queue"
			batch_size: 10
    
		s3:
			enabled: false
			bucket_name: "function-name-input"
			events: ["s3:ObjectCreated:*"]
```

### Update `requirements.txt` (if needed)

```txt
# Add any new dependencies:
new-package==1.0.0
another-package==2.0.0
```

---

## 🧪 Step 5: Local Testing

```bash
# Run tests
pytest functions/function_name/tests/ -v

# Manual test
python << 'EOF'
import json, sys
sys.path.insert(0, "functions/function_name")
from handler import lambda_handler

class MockContext:
		aws_request_id = "test"

with open("events/function_name_event.json") as f:
		event = json.load(f)

result = lambda_handler(event, MockContext())
print(json.dumps(json.loads(result['body']), indent=2))
EOF
```

---

## 📚 Step 6: Documentation

### Add to README.md

```markdown
### new_function_name
- **Purpose:** Description here
- **Trigger:** HTTP POST /api-path
- **Handler:** `functions/function_name/handler.py`
- **Tests:** `functions/function_name/tests/test_handler.py`
- **Sample Event:** `events/function_name_event.json`
```

---

## 🚀 Step 7: Deploy

```bash
# Test everything
pytest functions/ -v

# Git operations
git add functions/function_name
git add events/function_name_event.json
git add infra/main.tf infra/triggers.tf
git add config/triggers.yaml
git add requirements.txt
git add README.md

git commit -m "Add function_name Lambda function"
git push origin main

# GitHub Actions automatically:
# - Runs tests
# - Builds package
# - Deploys with Terraform
```

---

## ✅ Final Verification Checklist

### Code ✅
- [ ] `handler.py` created and working
- [ ] Tests written (minimum 3)
- [ ] Sample event created
- [ ] `__init__.py` in tests folder
- [ ] All tests passing: `pytest functions/function_name/tests/ -v`

### Infrastructure ✅
- [ ] Added to `infra/main.tf` (Lambda + archive + logs)
- [ ] Added to `infra/triggers.tf` (API route + integration + permission)
- [ ] All resource names follow convention (kebab-case for AWS)
- [ ] Outputs added for Lambda ARN and name

### Configuration ✅
- [ ] Added to `config/triggers.yaml`
- [ ] Function name correct (snake_case in code, kebab-case in AWS)
- [ ] Trigger settings configured
- [ ] Dependencies added to `requirements.txt` (if any)

### Documentation ✅
- [ ] Handler has docstring
- [ ] README.md updated
- [ ] Sample event shows example input
- [ ] Purpose clearly stated

### Git ✅
- [ ] All files staged: `git add`
- [ ] Commit message clear
- [ ] Pushed to main: `git push origin main`

---

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Tests fail | Check imports, use correct MockContext |
| Terraform error | Check resource names (kebab-case in AWS) |
| Missing deployment | Make sure you pushed to `main` branch |
| API not working | Verify route in `triggers.tf` matches what you're calling |
| Function missing | Check all Terraform variables are defined |

---

## 📝 Naming Convention Reference

```
Function folder:     functions/my_function/      (snake_case)
Handler file:        handler.py                  (always)
Handler function:    lambda_handler              (always)
AWS Lambda name:     my-function                 (kebab-case)
API route:           POST /my-path               (lowercase)
CloudWatch log:      /aws/lambda/my-function     (kebab-case)
Config section:      my_function:                (snake_case)
Sample event:        events/my_function_event.json (snake_case)
```

---

## 💡 Pro Tips

1. **Copy from existing function** - Much faster than starting from scratch
2. **Test locally first** - `pytest` catches 90% of issues
3. **Use correct naming** - Avoid issues with kebab vs snake case
4. **Small functions** - Easier to test and maintain
5. **Shared code to `common/`** - Keep functions independent

---

## 🔗 See Also

- **Full Guide:** [ADDING_NEW_FUNCTION_GUIDE.md](ADDING_NEW_FUNCTION_GUIDE.md)
- **Terraform Info:** [TERRAFORM_PUSH_BEHAVIOR.md](TERRAFORM_PUSH_BEHAVIOR.md)
- **CloudWatch Guide:** [CLOUDWATCH_MONITORING_GUIDE.md](CLOUDWATCH_MONITORING_GUIDE.md)

