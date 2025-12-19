"""
Trigger Configuration Parser
Reads and validates trigger configuration for Lambda functions
"""

import yaml
import json
from typing import Dict, Any, Optional
from pathlib import Path


class TriggerConfig:
    """Parse and manage Lambda trigger configurations"""
    
    def __init__(self, config_path: str = "config/triggers.yaml"):
        """
        Initialize trigger configuration
        
        Args:
            config_path: Path to triggers.yaml configuration file
        """
        self.config_path = Path(config_path)
        self.config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """Load and parse YAML configuration"""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")
        
        with open(self.config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def get_function_config(self, function_name: str) -> Dict[str, Any]:
        """Get configuration for specific function"""
        functions = self.config.get('functions', {})
        if function_name not in functions:
            raise ValueError(f"Function '{function_name}' not found in configuration")
        return functions[function_name]
    
    def get_enabled_triggers(self, function_name: str) -> Dict[str, Dict[str, Any]]:
        """Get all enabled triggers for a function"""
        config = self.get_function_config(function_name)
        triggers = {}
        
        trigger_types = ['api_gateway', 'sqs', 's3', 'eventbridge', 'dynamodb', 'sns']
        
        for trigger_type in trigger_types:
            if trigger_type in config:
                trigger_config = config[trigger_type]
                if trigger_config.get('enabled', False):
                    triggers[trigger_type] = trigger_config
        
        return triggers
    
    def get_environment_config(self, environment: str) -> Dict[str, Any]:
        """Get environment-specific configuration"""
        environments = self.config.get('environments', {})
        if environment not in environments:
            raise ValueError(f"Environment '{environment}' not found in configuration")
        return environments[environment]
    
    def print_triggers_summary(self, function_name: str) -> None:
        """Print summary of enabled triggers"""
        config = self.get_function_config(function_name)
        enabled = self.get_enabled_triggers(function_name)
        
        print(f"\n{'='*60}")
        print(f"Function: {config.get('name', function_name)}")
        print(f"Description: {config.get('description', 'N/A')}")
        print(f"{'='*60}")
        
        if enabled:
            print("\n✅ Enabled Triggers:")
            for trigger_type, trigger_config in enabled.items():
                print(f"\n  • {trigger_type.upper().replace('_', ' ')}")
                print(f"    Description: {trigger_config.get('description', 'N/A')}")
                
                # Show trigger-specific details
                if trigger_type == 'api_gateway':
                    print(f"    Route: {trigger_config.get('route', 'N/A')}")
                elif trigger_type == 'sqs':
                    print(f"    Queue: {trigger_config.get('queue_name', 'N/A')}")
                    print(f"    Batch Size: {trigger_config.get('batch_size', 1)}")
                elif trigger_type == 's3':
                    print(f"    Bucket: {trigger_config.get('bucket_name', 'N/A')}")
                    print(f"    Events: {trigger_config.get('events', [])}")
                elif trigger_type == 'eventbridge':
                    print(f"    Schedule: {trigger_config.get('schedule', 'N/A')}")
        else:
            print("\n⚠️  No triggers enabled")
        
        print(f"\n{'='*60}\n")
    
    def export_to_json(self, output_path: str = "config/triggers.json") -> None:
        """Export configuration to JSON format"""
        with open(output_path, 'w') as f:
            json.dump(self.config, f, indent=2)
        print(f"✅ Configuration exported to {output_path}")
    
    def validate_config(self) -> bool:
        """Validate configuration structure"""
        required_keys = ['functions']
        
        for key in required_keys:
            if key not in self.config:
                print(f"❌ Missing required key: {key}")
                return False
        
        if not self.config['functions']:
            print("❌ No functions defined in configuration")
            return False
        
        print("✅ Configuration is valid")
        return True


# Example usage
if __name__ == "__main__":
    try:
        # Load configuration
        config = TriggerConfig()
        
        # Validate
        config.validate_config()
        
        # Print summary
        config.print_triggers_summary("ray_converter")
        
        # Export to JSON
        config.export_to_json()
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")