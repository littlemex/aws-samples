#!/bin/bash
# 
# AWS Bedrock Model Validator Wrapper Script
#
# This script runs the model_validator.py script to validate AWS Bedrock models
# before starting the Wren AI services.
#
# Usage:
#   ./validate_models.sh [--config CONFIG_PATH] [--region REGION] [--verbose]
#

set -e

# Default values
CONFIG_PATH="../config.yaml"
REGION=""
VERBOSE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE="--verbose"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure config file exists
if [ ! -f "$CONFIG_PATH" ]; then
  # Try relative to script directory
  if [ -f "$SCRIPT_DIR/$CONFIG_PATH" ]; then
    CONFIG_PATH="$SCRIPT_DIR/$CONFIG_PATH"
  else
    echo "Error: Config file not found at $CONFIG_PATH"
    exit 1
  fi
fi

echo "=== AWS Bedrock Model Validator ==="
echo "Config path: $CONFIG_PATH"
if [ -n "$REGION" ]; then
  echo "AWS Region: $REGION"
fi

# Build command
CMD="python3 $SCRIPT_DIR/model_validator.py --config $CONFIG_PATH"
if [ -n "$REGION" ]; then
  CMD="$CMD --region $REGION"
fi
if [ -n "$VERBOSE" ]; then
  CMD="$CMD $VERBOSE"
fi

# Run validator
echo "Running: $CMD"
if $CMD; then
  echo "✅ All models validated successfully!"
  exit 0
else
  EXIT_CODE=$?
  echo "❌ Model validation failed with exit code $EXIT_CODE"
  echo "Please fix the issues before starting the services."
  exit $EXIT_CODE
fi
