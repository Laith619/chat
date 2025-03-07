#!/bin/bash

# Set your OpenAI API key here or export it before running this script
# export OPENAI_API_KEY="your-api-key-here"

if [ -z "$OPENAI_API_KEY" ]; then
  echo "Please set your OPENAI_API_KEY environment variable before running this script."
  echo "Example: export OPENAI_API_KEY=\"your-api-key-here\""
  exit 1
fi

echo "Testing access to text-embedding-3-small model..."

curl -s -X POST \
  https://api.openai.com/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "text-embedding-3-small",
    "input": "Test text for embedding"
  }' | jq .

echo "Testing access to text-embedding-ada-002 model..."

curl -s -X POST \
  https://api.openai.com/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "text-embedding-ada-002",
    "input": "Test text for embedding"
  }' | jq .

echo "Done!" 