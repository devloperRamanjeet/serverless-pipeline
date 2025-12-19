#!/usr/bin/env python
"""
Trigger Configuration Demo
Shows how to enable/disable different triggers for Lambda functions
"""

import json
from pathlib import Path
from common.trigger_config import TriggerConfig


def demo_view_current_triggers():
    """Demo: View currently enabled triggers"""
    print("\n" + "="*70)
    print("DEMO 1: View Currently Enabled Triggers")
    print("="*70)
    
    config = TriggerConfig()
    config.print_triggers_summary("ray_converter")


def demo_read_configuration():
    """Demo: Read full configuration"""
    print("="*70)
    print("DEMO 2: Full Configuration Details")
    print("="*70)
    
    config = TriggerConfig()
    fn_config = config.get_function_config("ray_converter")
    
    print(f"\nFunction: {fn_config['name']}")
    print(f"Runtime: {fn_config['runtime']}")
    print(f"Memory: {fn_config['memory_size']} MB")
    print(f"Timeout: {fn_config['timeout']} seconds")
    
    print("\nAvailable Triggers:")
    for trigger_type, trigger_config in fn_config.items():
        if trigger_type not in ['name', 'runtime', 'memory_size', 'timeout', 'description']:
            status = "✅ ENABLED" if trigger_config.get('enabled') else "❌ DISABLED"
            print(f"  • {trigger_type.upper()}: {status}")


def demo_export_triggers():
    """Demo: Export triggers to JSON"""
    print("\n" + "="*70)
    print("DEMO 3: Export Triggers to JSON")
    print("="*70)
    
    config = TriggerConfig()
    output_file = "config/triggers.json"
    config.export_to_json(output_file)
    
    # Display exported content
    with open(output_file) as f:
        triggers_json = json.load(f)
    
    print(f"\nExported to {output_file}")
    print("Sample structure:")
    print(json.dumps(
        {"functions": {"ray_converter": triggers_json["functions"]["ray_converter"]}},
        indent=2
    )[:500] + "...")


def demo_conditional_triggers():
    """Demo: Show how to use triggers conditionally"""
    print("\n" + "="*70)
    print("DEMO 4: Using Triggers in Terraform")
    print("="*70)
    
    config = TriggerConfig()
    fn_config = config.get_function_config("ray_converter")
    
    print("\nTerraform will create these resources:")
    
    triggers = {
        'api_gateway': 'aws_apigatewayv2_api',
        'sqs': 'aws_sqs_queue + aws_lambda_event_source_mapping',
        's3': 'aws_s3_bucket + aws_s3_bucket_notification',
        'eventbridge': 'aws_cloudwatch_event_rule + aws_cloudwatch_event_target',
        'dynamodb': 'aws_lambda_event_source_mapping (DynamoDB stream)',
        'sns': 'aws_sns_topic + aws_lambda_permission'
    }
    
    for trigger_type, resource in triggers.items():
        if trigger_type in fn_config:
            status = "✅" if fn_config[trigger_type].get('enabled') else "❌"
            print(f"  {status} {trigger_type.upper()}: {resource}")


def demo_modify_instructions():
    """Show instructions for modifying triggers"""
    print("\n" + "="*70)
    print("DEMO 5: How to Enable/Disable Triggers")
    print("="*70)
    
    print("""
To enable/disable triggers, edit 'config/triggers.yaml':

1. Open the file:
   nano config/triggers.yaml

2. Change the 'enabled' flag:
   
   # BEFORE (SQS disabled):
   sqs:
     enabled: false
     queue_name: "ray-converter-queue"
   
   # AFTER (SQS enabled):
   sqs:
     enabled: true
     queue_name: "ray-converter-queue"
     batch_size: 10

3. Run validation:
   python common/trigger_config.py

4. Apply changes with Terraform:
   cd infra
   terraform plan
   terraform apply
""")


if __name__ == "__main__":
    print("\n" + "█"*70)
    print("█ LAMBDA TRIGGER CONFIGURATION DEMO")
    print("█"*70)
    
    demo_view_current_triggers()
    demo_read_configuration()
    demo_export_triggers()
    demo_conditional_triggers()
    demo_modify_instructions()
    
    print("\n" + "█"*70)
    print("█ Demo Complete! ✅")
    print("█"*70 + "\n")