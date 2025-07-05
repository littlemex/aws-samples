#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
AWS Bedrock Model Validator

This script validates that AWS Bedrock models specified in the Wren AI configuration
are properly enabled and accessible in the AWS account.

Usage:
    python model_validator.py --config /path/to/config.yaml

Author: Wren AI Team
"""

import argparse
import boto3
import logging
import os
import sys
import yaml
from botocore.exceptions import ClientError
from typing import Dict, List, Tuple, Any, Optional, Union

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("model_validator")

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Validate AWS Bedrock models in configuration')
    parser.add_argument('--config', type=str, required=True, help='Path to Wren AI config.yaml')
    parser.add_argument('--region', type=str, help='AWS region (overrides config)')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    return parser.parse_args()

def load_config(config_path: str) -> List[Dict]:
    """
    Load the Wren AI configuration file.
    
    Args:
        config_path: Path to the config.yaml file
        
    Returns:
        List of configuration documents
    """
    try:
        with open(config_path, 'r') as f:
            config_docs = list(yaml.safe_load_all(f))
            logger.info(f"Loaded configuration from {config_path}")
            return config_docs
    except Exception as e:
        logger.error(f"Failed to load configuration from {config_path}: {e}")
        sys.exit(1)

def extract_bedrock_models_from_config(config_docs: List[Dict]) -> List[str]:
    """
    Extract all AWS Bedrock model IDs from the configuration.
    
    Args:
        config_docs: List of configuration documents
        
    Returns:
        List of Bedrock model IDs
    """
    models = []
    
    for doc in config_docs:
        if not isinstance(doc, dict):
            continue
            
        # Extract LLM models
        if doc.get('type') == 'llm' and doc.get('provider') == 'litellm_llm':
            for model in doc.get('models', []):
                model_id = model.get('model')
                if model_id and model_id.startswith('bedrock/'):
                    models.append(model_id)
        
        # Extract embedding models
        if doc.get('type') == 'embedder' and doc.get('provider') == 'litellm_embedder':
            for model in doc.get('models', []):
                model_id = model.get('model')
                if model_id and model_id.startswith('bedrock/'):
                    models.append(model_id)
                    
        # Extract fallback models from settings
        if doc.get('settings') and doc.get('settings').get('litellm_settings'):
            fallbacks = doc.get('settings').get('litellm_settings').get('fallbacks', [])
            for fallback in fallbacks:
                if isinstance(fallback, dict):
                    for primary_model, backup_models in fallback.items():
                        if primary_model.startswith('bedrock/'):
                            models.append(primary_model)
                        if isinstance(backup_models, list):
                            for backup_model in backup_models:
                                if backup_model.startswith('bedrock/'):
                                    models.append(backup_model)
    
    # Remove duplicates while preserving order
    unique_models = []
    for model in models:
        if model not in unique_models:
            unique_models.append(model)
    
    logger.info(f"Found {len(unique_models)} unique Bedrock models in configuration")
    return unique_models

def normalize_model_id(model_id: str) -> str:
    """
    Normalize the model ID to the format expected by the AWS Bedrock API.
    
    Args:
        model_id: Model ID from the configuration (e.g., 'bedrock/converse/us.anthropic.claude-3-7-sonnet-20250219-v1:0')
        
    Returns:
        Normalized model ID (e.g., 'anthropic.claude-3-7-sonnet-20250219-v1')
    """
    original_id = model_id
    logger.debug(f"Normalizing model ID: {original_id}")
    
    # Remove 'bedrock/' prefix if present
    if model_id.startswith('bedrock/'):
        model_id = model_id[len('bedrock/'):]
        logger.debug(f"After removing 'bedrock/' prefix: {model_id}")
    
    # Remove 'converse/' prefix if present
    if model_id.startswith('converse/'):
        model_id = model_id[len('converse/'):]
        logger.debug(f"After removing 'converse/' prefix: {model_id}")
    
    # Handle additional path components
    parts = model_id.split('/')
    if len(parts) > 1:
        # The last part should contain the actual model ID
        model_id = parts[-1]
        logger.debug(f"After extracting last path component: {model_id}")
    
    # Remove version suffix if present (e.g., ':0')
    if ':' in model_id:
        model_id = model_id.split(':', 1)[0]
        logger.debug(f"After removing version suffix: {model_id}")
    
    # Handle regional prefixes in the model ID itself
    if model_id.startswith(('us.', 'apac.')):
        # For example, convert 'us.anthropic.claude-3-7-sonnet-20250219-v1' to 'anthropic.claude-3-7-sonnet-20250219-v1'
        parts = model_id.split('.', 1)
        if len(parts) > 1:
            model_id = parts[1]
            logger.debug(f"After removing regional prefix: {model_id}")
    
    # LiteLLM to AWS Bedrock model ID mappings
    # Based on AWS documentation: https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html
    model_mapping = {
        # Claude 3.5 models
        "anthropic.claude-3-5-sonnet-20240620-v1": "anthropic.claude-3-5-sonnet-20240620-v1:0",
        "anthropic.claude-3-5-sonnet-20241022-v2": "anthropic.claude-3-5-sonnet-20241022-v2:0",
        
        # Claude 3.7 models
        "anthropic.claude-3-7-sonnet-20250219-v1": "anthropic.claude-3-7-sonnet-20250219-v1:0",
        
        # Claude 3 models
        "anthropic.claude-3-sonnet-20240229-v1": "anthropic.claude-3-sonnet-20240229-v1:0",
        "anthropic.claude-3-haiku-20240307-v1": "anthropic.claude-3-haiku-20240307-v1:0",
        "anthropic.claude-3-opus-20240229-v1": "anthropic.claude-3-opus-20240229-v1:0",
        
        # Titan models
        "amazon.titan-text-express-v1": "amazon.titan-text-express-v1:0",
        "amazon.titan-text-lite-v1": "amazon.titan-text-lite-v1:0",
        "amazon.titan-embed-text-v1": "amazon.titan-embed-text-v1:0",
        "amazon.titan-embed-text-v2": "amazon.titan-embed-text-v2:0",
        
        # Add more mappings as needed
    }
    
    # Check if we have a direct mapping for this model ID
    if model_id in model_mapping:
        mapped_id = model_mapping[model_id]
        logger.debug(f"Mapped model ID '{model_id}' to '{mapped_id}'")
        return mapped_id
    
    # If the model ID doesn't end with a version suffix (e.g., ':0'), add it
    if not model_id.endswith(':0'):
        model_id = f"{model_id}:0"
        logger.debug(f"Added version suffix: {model_id}")
    
    logger.debug(f"Final normalized model ID: {model_id} (from original: {original_id})")
    return model_id

def check_model_availability(model_id: str, region: Optional[str] = None) -> Tuple[bool, Dict]:
    """
    Check if a Bedrock model is available for use.
    
    Args:
        model_id: The model ID to check
        region: AWS region to use (optional)
        
    Returns:
        Tuple of (is_available, details)
    """
    normalized_id = normalize_model_id(model_id)
    original_id = model_id
    
    # Create Bedrock client
    bedrock_kwargs = {}
    if region:
        bedrock_kwargs['region_name'] = region
    
    try:
        bedrock_client = boto3.client('bedrock', **bedrock_kwargs)
        
        # Get list of available models
        response = bedrock_client.list_foundation_models()
        models = response.get("modelSummaries", [])
        
        # Create a mapping of model IDs to model details
        model_map = {}
        for model in models:
            model_id = model.get("modelId")
            if model_id:
                model_map[model_id] = model
                
                # Also add version without suffix for models like amazon.titan-embed-text-v1
                if ':' in model_id:
                    base_id = model_id.split(':', 1)[0]
                    if base_id not in model_map:
                        model_map[base_id] = model
        
        # Check if our normalized model ID is in the list
        if normalized_id in model_map:
            model_details = model_map[normalized_id]
            
            # Check if the model is accessible
            # A model is typically available if it's in the list and has a status of "ACTIVE" or "LEGACY"
            model_lifecycle_status = model_details.get("modelLifecycle", {}).get("status", "")
            is_available = model_lifecycle_status in ["ACTIVE", "LEGACY"]
            
            return is_available, {
                "modelId": normalized_id,
                "modelName": model_details.get("modelName", ""),
                "providerName": model_details.get("providerName", ""),
                "modelLifecycle": model_details.get("modelLifecycle", {}),
                "inputModalities": model_details.get("inputModalities", []),
                "outputModalities": model_details.get("outputModalities", []),
                "original_id": original_id
            }
        else:
            # Try to find a similar model by partial matching
            similar_models = []
            for model_id in model_map.keys():
                # Check if the normalized ID is a substring of any available model ID
                # or if any available model ID is a substring of the normalized ID
                if normalized_id in model_id or model_id in normalized_id:
                    similar_models.append(model_id)
            
            return False, {
                "error": "Model not found",
                "original_id": original_id,
                "normalized_id": normalized_id,
                "similar_models": similar_models,
                "available_models": list(model_map.keys())
            }
            
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code')
        error_message = e.response.get('Error', {}).get('Message')
        
        if error_code == 'AccessDeniedException':
            logger.warning(f"Access denied to check model {original_id}")
            return False, {"error": "Access denied", "details": str(e)}
        else:
            logger.error(f"Error checking model {original_id}: {e}")
            return False, {"error": error_code, "message": error_message, "details": str(e)}
    except Exception as e:
        logger.error(f"Unexpected error checking model {original_id}: {e}")
        return False, {"error": "Unexpected error", "details": str(e)}

def validate_models(models: List[str], region: Optional[str] = None, verbose: bool = False) -> Dict[str, Dict]:
    """
    Validate a list of Bedrock models.
    
    Args:
        models: List of model IDs to validate
        region: AWS region to use (optional)
        verbose: Whether to print verbose output
        
    Returns:
        Dictionary of validation results
    """
    results = {}
    all_available = True
    
    for model_id in models:
        logger.info(f"Checking availability of model: {model_id}")
        is_available, details = check_model_availability(model_id, region)
        
        results[model_id] = {
            "available": is_available,
            "details": details
        }
        
        if is_available:
            logger.info(f"✅ Model {model_id} is available")
            if verbose:
                logger.info(f"  Details: {details}")
        else:
            all_available = False
            logger.warning(f"❌ Model {model_id} is NOT available")
            logger.warning(f"  Details: {details}")
    
    return results

def print_summary(results: Dict[str, Dict]):
    """
    Print a summary of the validation results.
    
    Args:
        results: Dictionary of validation results
    """
    available_models = [model for model, result in results.items() if result["available"]]
    unavailable_models = [model for model, result in results.items() if not result["available"]]
    
    print("\n" + "="*80)
    print(f"AWS BEDROCK MODEL VALIDATION SUMMARY")
    print("="*80)
    print(f"Total models checked: {len(results)}")
    print(f"Available models: {len(available_models)}")
    print(f"Unavailable models: {len(unavailable_models)}")
    
    if available_models:
        print("\nAVAILABLE MODELS:")
        for model in available_models:
            details = results[model]["details"]
            model_name = details.get("modelName", "Unknown")
            provider = details.get("providerName", "Unknown")
            print(f"  ✅ {model} ({provider} - {model_name})")
    
    if unavailable_models:
        print("\nUNAVAILABLE MODELS:")
        for model in unavailable_models:
            details = results[model]["details"]
            error_info = details.get("error", "Unknown error")
            
            print(f"  ❌ {model}: {error_info}")
            
            # If we have similar models, suggest them
            similar_models = details.get("similar_models", [])
            if similar_models:
                print(f"     Similar models that might be available:")
                for similar in similar_models[:3]:  # Limit to top 3 suggestions
                    print(f"     - {similar}")
            
            # If the model was not found, show the normalized ID we looked for
            if error_info == "Model not found":
                normalized_id = details.get("normalized_id", "")
                if normalized_id:
                    print(f"     Looked for model ID: {normalized_id}")
        
        print("\nRECOMMENDED ACTIONS:")
        print("  1. Enable these models in the AWS Bedrock console:")
        print("     https://console.aws.amazon.com/bedrock/home#/modelaccess")
        print("  2. Ensure your IAM role has the 'bedrock:InvokeModel' permission")
        print("  3. Check that the models are available in your AWS region")
        print("  4. Verify the model IDs in your configuration match the actual Bedrock model IDs")
        print("  5. For LiteLLM integration, ensure the model naming follows LiteLLM conventions")
        
        # Show available models in the region as reference
        available_bedrock_models = set()
        for model in unavailable_models:
            details = results[model]["details"]
            if "available_models" in details:
                available_bedrock_models.update(details["available_models"])
        
        if available_bedrock_models:
            print("\nAVAILABLE BEDROCK MODELS IN YOUR REGION:")
            for i, model in enumerate(sorted(available_bedrock_models)):
                print(f"  - {model}")
                if i >= 9:  # Limit to 10 models to avoid overwhelming output
                    remaining = len(available_bedrock_models) - 10
                    if remaining > 0:
                        print(f"  ... and {remaining} more")
                    break
    
    print("="*80)

def main():
    """Main entry point."""
    args = parse_args()
    
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    # Load configuration
    config_docs = load_config(args.config)
    
    # Extract Bedrock models
    models = extract_bedrock_models_from_config(config_docs)
    
    if not models:
        logger.warning("No Bedrock models found in configuration")
        return
    
    # Validate models
    results = validate_models(models, args.region, args.verbose)
    
    # Print summary
    print_summary(results)
    
    # Exit with error code if any models are unavailable
    unavailable_models = [model for model, result in results.items() if not result["available"]]
    if unavailable_models:
        sys.exit(1)

if __name__ == "__main__":
    main()
