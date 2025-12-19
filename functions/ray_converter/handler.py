import json
import loimport sys
from datetime import datetime

# Configure CloudWatch structured logging
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
    
    def debug(self, message, **kwargs):
        self.log("DEBUG", message, **kwargs)


structured_logger = StructuredLogger(logger)


def lambda_handler(event, context):
    """
    Convert Ray format data to standard format.
    
    Args:
        event: Lambda event containing ray data
        context: Lambda context
    
    Returns:
        Response object with converted data
    
    Logs to CloudWatch with structure for easy querying
    """
    request_id = context.aws_request_id if context else "local-test"
    
    try:
        # Log incoming request
        structured_logger.info(
            "Received event",
            request_id=request_id,
            event_keys=list(event.keys()),
            function_name=context.function_name if context else "unknown"
        )
        
        # Extract ray data from event
        ray_data = event.get("ray", {})
        
        if not ray_data:
            structured_logger.warning(
                "Empty ray data received",
                request_id=request_id,
                event=event
            )
        
        # Convert to standard format
        converted = {
            "standard": ray_data,
            "timestamp": request_id,
            "processed_at": datetime.utcnow().isoformat()
        }
        
        # Log successful conversion
        structured_logger.info(
            "Converted data successfully",
            request_id=request_id,
            input_keys=list(ray_data.keys()) if ray_data else [],
            output_keys=list(converted.keys()),
            input_size=len(json.dumps(ray_data)),
            output_size=len(json.dumps(converted))
        )
        
        response = {
            "statusCode": 200,
            "body": json.dumps(converted)
        }
        
        structured_logger.info(
            "Returning successful response",
            request_id=request_id,
            status_code=response["statusCode"]
        )
        
        return response
    
    except json.JSONDecodeError as e:
        structured_logger.error(
            "JSON decode error",
            request_id=request_id,
            error=str(e),
            error_type="JSONDecodeError"
        )
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Invalid JSON in request"})
        }
    
    except TypeError as e:
        structured_logger.error(
            "Type error during processing",
            request_id=request_id,
            error=str(e),
            error_type="TypeError"
        )
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Invalid data type"})
        }
    
    except Exception as e:
        structured_logger.error(
            "Unexpected error processing event",
            request_id=request_id,
            error=str(e),
            error_type=type(e).__name__,
            exc_info=True
        )
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"})
        }
