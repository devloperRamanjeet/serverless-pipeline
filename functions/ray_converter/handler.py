import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Convert Ray format data to standard format.
    
    Args:
        event: Lambda event containing ray data
        context: Lambda context
    
    Returns:
        Response object with converted data
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract ray data from event
        ray_data = event.get("ray", {})
        
        # Convert to standard format
        converted = {
            "standard": ray_data,
            "timestamp": context.aws_request_id if context else None
        }
        
        logger.info(f"Converted data: {json.dumps(converted)}")
        
        return {
            "statusCode": 200,
            "body": json.dumps(converted)
        }
    
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
