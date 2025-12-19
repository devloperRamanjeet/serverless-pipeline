````markdown
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

---

... (rest of guide preserved)
````
