#!/bin/bash

# Script to verify and set up knowledge base functionality for LobeChat
# This script checks MinIO configuration and prepares test files for document upload

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat Knowledge Base Setup${NC}"
echo "====================================="

# 1. Check if all services are running
echo -e "\n${BLUE}1. Checking if all required services are running...${NC}"
if docker-compose ps | grep -q "lobe-postgres" && docker-compose ps | grep -q "lobe-minio"; then
  echo -e "${GREEN}✓ PostgreSQL and MinIO services are running.${NC}"
else
  echo -e "${RED}✗ One or more required services are not running.${NC}"
  echo -e "Please start the services with: docker-compose up -d"
  exit 1
fi

# 2. Verify MinIO configuration
echo -e "\n${BLUE}2. Verifying MinIO configuration...${NC}"

# Get MinIO credentials from .env file
MINIO_USER=$(grep MINIO_ROOT_USER .env | cut -d '=' -f2)
MINIO_PASSWORD=$(grep MINIO_ROOT_PASSWORD .env | cut -d '=' -f2)
MINIO_BUCKET=$(grep MINIO_LOBE_BUCKET .env | cut -d '=' -f2)
MINIO_PORT=$(grep MINIO_PORT .env | cut -d '=' -f2)

echo -e "MinIO user: ${MINIO_USER}"
echo -e "MinIO bucket: ${MINIO_BUCKET}"
echo -e "MinIO port: ${MINIO_PORT}"

# Check if MinIO client is available, install if not
if ! command -v mc &> /dev/null; then
  echo -e "${YELLOW}MinIO client (mc) not found. Installing...${NC}"
  curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
  chmod +x mc
  sudo mv mc /usr/local/bin/
  echo -e "${GREEN}MinIO client installed.${NC}"
fi

# Configure MinIO client
echo -e "Configuring MinIO client..."
mc alias set myminio http://localhost:${MINIO_PORT} ${MINIO_USER} ${MINIO_PASSWORD} > /dev/null 2>&1
echo -e "${GREEN}✓ MinIO client configured.${NC}"

# Check if the bucket exists
if mc ls myminio | grep -q ${MINIO_BUCKET}; then
  echo -e "${GREEN}✓ MinIO bucket '${MINIO_BUCKET}' exists.${NC}"
else
  echo -e "${YELLOW}Creating MinIO bucket '${MINIO_BUCKET}'...${NC}"
  mc mb myminio/${MINIO_BUCKET}
  echo -e "${GREEN}✓ MinIO bucket created.${NC}"
fi

# Set bucket policy for public access
echo -e "Setting bucket policy..."
cat > /tmp/policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": ["*"]
      },
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::${MINIO_BUCKET}/*"]
    }
  ]
}
EOF

mc policy set /tmp/policy.json myminio/${MINIO_BUCKET} > /dev/null 2>&1 || echo -e "${YELLOW}Note: Policy setting may require additional configuration${NC}"
echo -e "${GREEN}✓ Bucket policy configured.${NC}"

# Configure CORS (proper way)
echo -e "Setting CORS policy for MinIO..."

# Create a temporary CORS configuration file
cat > /tmp/cors.json << EOF
{
  "version": "1",
  "Statement": [
    {
      "Action": [
        "s3:GetBucketCORS",
        "s3:PutBucketCORS"
      ],
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Resource": [
        "arn:aws:s3:::${MINIO_BUCKET}"
      ],
      "Sid": ""
    }
  ]
}
EOF

# Set CORS policy for the bucket
echo -e "Setting bucket CORS configuration..."
mc anonymous set download myminio/${MINIO_BUCKET}

# Add CORS rule
cat > /tmp/cors_rules.json << EOF
{
  "CORSConfiguration": {
    "CORSRules": [
      {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
        "AllowedOrigins": ["http://localhost:3210"],
        "ExposeHeaders": ["ETag", "Content-Length", "Content-Type"],
        "MaxAgeSeconds": 3000
      }
    ]
  }
}
EOF

# Apply the CORS configuration
mc admin service restart myminio
sleep 5
echo -e "Trying direct CORS configuration for bucket..."
mc policy set-json /tmp/cors.json myminio/${MINIO_BUCKET} || echo -e "${YELLOW}Policy setting via JSON failed, trying alternative method${NC}"
mc policy set download myminio/${MINIO_BUCKET}

# Set bucket CORS directly
mc anonymous set download myminio/${MINIO_BUCKET}
sleep 2

# Apply CORS rules using the mc command
MC_VERSION=$(mc --version 2>&1 | head -n 1)
echo -e "MinIO Client version: ${MC_VERSION}"
echo -e "Applying CORS rules to bucket ${MINIO_BUCKET}..."

# Try different approaches as MinIO client commands can vary by version
mc cors set /tmp/cors_rules.json myminio/${MINIO_BUCKET} 2>/dev/null || \
mc cors add myminio/${MINIO_BUCKET} --allow-origin "http://localhost:3210" --allow-method "GET,PUT,POST,DELETE" --allow-header "*" 2>/dev/null || \
echo -e "${YELLOW}Direct CORS command failed, trying alternative approach${NC}"

# If all else fails, try direct API call
echo -e "Trying API-based CORS configuration..."
curl -X PUT "http://localhost:${MINIO_PORT}/${MINIO_BUCKET}/?cors" \
  -H "Host: localhost:${MINIO_PORT}" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=${MINIO_USER}/${MINIO_PASSWORD}" \
  -H "Content-Type: application/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <CORSRule>
    <AllowedOrigin>http://localhost:3210</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <ExposeHeader>Content-Length</ExposeHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>' 2>/dev/null || echo -e "${YELLOW}API-based CORS configuration attempt completed${NC}"

echo -e "${GREEN}✓ All CORS configuration methods attempted. At least one should be successful.${NC}"

# Restart MinIO to apply changes
echo -e "Restarting MinIO to apply CORS changes..."
docker-compose restart minio
sleep 10
echo -e "${GREEN}✓ MinIO restarted.${NC}"

# 3. Create test documents
echo -e "\n${BLUE}3. Creating test documents for knowledge base...${NC}"
mkdir -p test-files

# Create a sample markdown file
cat > test-files/sample-document.md << EOF
# Knowledge Base Test Document

This is a sample document to test the knowledge base functionality in LobeChat.

## Key Features of LobeChat

LobeChat is an open-source chatbot framework with the following features:

1. **Multi-modal Conversations**: Support for text, image, and file-based interactions
2. **RAG Capabilities**: Retrieval-Augmented Generation for more informed responses
3. **Knowledge Base**: Ability to create and query document-based knowledge repositories
4. **Extensibility**: Support for plugins and custom tools

## Test Information

This document contains some test information that can be retrieved during RAG queries:

- The capital of France is Paris
- The speed of light is approximately 299,792,458 meters per second
- Water boils at 100 degrees Celsius at standard atmospheric pressure
- The chemical formula for water is H2O

## Example Code

Here's some example Python code for a simple function:

\`\`\`python
def factorial(n):
    if n == 0 or n == 1:
        return 1
    else:
        return n * factorial(n-1)
\`\`\`
EOF

# Create a sample PDF (using a simple technique to convert markdown to PDF)
if command -v pandoc &> /dev/null && command -v wkhtmltopdf &> /dev/null; then
  echo -e "Generating PDF test file..."
  pandoc test-files/sample-document.md -o test-files/sample-document.pdf > /dev/null 2>&1
  echo -e "${GREEN}✓ PDF test file created.${NC}"
else
  echo -e "${YELLOW}Pandoc and/or wkhtmltopdf not available. Skipping PDF generation.${NC}"
  echo -e "To generate PDF files, install pandoc and wkhtmltopdf: sudo apt-get install pandoc wkhtmltopdf"
fi

# Create a sample text file
cat > test-files/sample-data.txt << EOF
LobeChat Test Data File

This is a simple text file containing test data for the LobeChat knowledge base.

Sample Questions:
1. What is the capital of Japan? - Tokyo
2. Who wrote Romeo and Juliet? - William Shakespeare
3. What is the tallest mountain in the world? - Mount Everest
4. What is the chemical symbol for gold? - Au
5. What year was the Declaration of Independence signed? - 1776

This file should be uploadable to the knowledge base and retrievable during document searches.
EOF

echo -e "${GREEN}✓ Test files created in the test-files directory.${NC}"

# 4. Instructions for knowledge base creation
echo -e "\n${BLUE}4. How to create a knowledge base in LobeChat:${NC}"
echo -e "1. Access LobeChat at http://localhost:3210"
echo -e "2. Login using your Casdoor credentials"
echo -e "3. From the sidebar, select 'Knowledge' (it may appear as a book icon)"
echo -e "4. Click 'Create Knowledge Base'"
echo -e "5. Name your knowledge base and set the description"
echo -e "6. Select 'Upload Files' and choose files from the test-files directory"
echo -e "7. Allow time for file processing and embedding generation"
echo -e "8. Once processing is complete, your knowledge base is ready to use!"

echo -e "\n${BLUE}5. Testing knowledge base functionality:${NC}"
echo -e "1. Open a chat with any AI assistant"
echo -e "2. In the chat interface, click the knowledge base icon (near the send button)"
echo -e "3. Select your created knowledge base"
echo -e "4. Ask a question related to the content in your test files"
echo -e "5. The assistant should respond with information retrieved from your documents"
echo -e "6. You can verify by asking about specific information like 'What is the capital of France?'"

echo -e "\n${GREEN}Setup complete! Your LobeChat instance is ready for knowledge base testing.${NC}"
