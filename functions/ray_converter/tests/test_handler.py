import sys
import json
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from handler import lambda_handler


class MockContext:
    """Mock Lambda context for testing"""
    aws_request_id = "test-request-id-123"
    function_name = "test-function"
    invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:test-function"
    memory_limit_in_mb = 128


def test_lambda_handler_success():
    """Test successful ray conversion"""
    event = {"ray": {"x": 10, "y": 20, "z": 30}}
    context = MockContext()
    
    result = lambda_handler(event, context)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert "standard" in body
    assert body["standard"]["x"] == 10
    assert body["standard"]["y"] == 20
    assert body["standard"]["z"] == 30
    assert "processed_at" in body
    assert "timestamp" in body


def test_lambda_handler_empty_ray():
    """Test with empty ray data"""
    event = {"ray": {}}
    context = MockContext()
    
    result = lambda_handler(event, context)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["standard"] == {}


def test_lambda_handler_missing_ray_key():
    """Test with missing ray key in event"""
    event = {}
    context = MockContext()
    
    result = lambda_handler(event, context)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["standard"] == {}


def test_lambda_handler_with_none_context():
    """Test with None context (local testing)"""
    event = {"ray": {"a": 1}}
    
    result = lambda_handler(event, None)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert "timestamp" in body
    assert body["timestamp"] == "local-test"  # Should be "local-test" when context is None


def test_lambda_handler_complex_nested_data():
    """Test conversion of complex nested structures"""
    event = {
        "ray": {
            "coordinates": [1, 2, 3],
            "metadata": {
                "source": "test",
                "version": "1.0"
            },
            "tags": ["test", "example"]
        }
    }
    context = MockContext()
    
    result = lambda_handler(event, context)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["standard"]["coordinates"] == [1, 2, 3]
    assert body["standard"]["metadata"]["source"] == "test"
    assert "processed_at" in body
