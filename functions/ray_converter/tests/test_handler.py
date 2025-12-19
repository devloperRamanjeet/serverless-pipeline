import sys
import json
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from handler import lambda_handler


class MockContext:
    """Mock Lambda context for testing"""
    aws_request_id = "test-request-id-123"


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
    """Test with None context"""
    event = {"ray": {"a": 1}}
    
    result = lambda_handler(event, None)
    
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["timestamp"] is None
