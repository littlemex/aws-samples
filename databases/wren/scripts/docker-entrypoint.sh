#!/bin/bash
#
# Docker Entrypoint Script for Wren AI Service
#
# This script validates AWS Bedrock models before starting the Wren AI service.
# It can be used as an entrypoint for the Docker container.
#

set -e

# Configuration
CONFIG_PATH=${CONFIG_PATH:-"/app/data/config.yaml"}
AWS_REGION=${AWS_REGION_NAME:-"us-east-1"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Wren AI Service Docker Entrypoint ==="
echo "Config path: $CONFIG_PATH"
echo "AWS Region: $AWS_REGION"

# Check if validation should be skipped
if [ "${SKIP_MODEL_VALIDATION:-false}" = "true" ]; then
  echo "⚠️ Skipping model validation (SKIP_MODEL_VALIDATION=true)"
else
  echo "Validating AWS Bedrock models..."
  
  # Run model validation
  if python3 "$SCRIPT_DIR/model_validator.py" --config "$CONFIG_PATH" --region "$AWS_REGION"; then
    echo "✅ All models validated successfully!"
  else
    EXIT_CODE=$?
    echo "❌ Model validation failed with exit code $EXIT_CODE"
    
    # Check if we should continue despite validation failure
    if [ "${CONTINUE_ON_VALIDATION_FAILURE:-false}" = "true" ]; then
      echo "⚠️ Continuing despite validation failure (CONTINUE_ON_VALIDATION_FAILURE=true)"
    else
      echo "Exiting due to validation failure. Set CONTINUE_ON_VALIDATION_FAILURE=true to override."
      exit $EXIT_CODE
    fi
  fi
fi

# Execute the original command or start the service
echo "Starting Wren AI service..."
exec "$@"
