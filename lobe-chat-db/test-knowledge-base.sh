#!/bin/bash

# Script to test the knowledge base and document upload functionality in LobeChat
# This script verifies that the knowledge base is properly configured and working

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat Knowledge Base Test${NC}"
echo "====================================="

# 1. Make sure the test-files directory exists
echo -e "\n${BLUE}1. Checking test files directory...${NC}"
if [ ! -d "test-files" ]; then
  echo -e "${YELLOW}Creating test-files directory...${NC}"
  mkdir -p test-files
fi

# Count files in the test-files directory
FILE_COUNT=$(ls -1 test-files | wc -l)
if [ $FILE_COUNT -eq 0 ]; then
  echo -e "${YELLOW}No test files found. Run setup-knowledge-base.sh first to create test files.${NC}"
else
  echo -e "${GREEN}✓ Found $FILE_COUNT test files.${NC}"
fi

# 2. Verify MinIO is working and the bucket exists
echo -e "\n${BLUE}2. Checking MinIO storage...${NC}"

# Get MinIO credentials from .env file
MINIO_USER=$(grep MINIO_ROOT_USER .env | cut -d '=' -f2)
MINIO_PASSWORD=$(grep MINIO_ROOT_PASSWORD .env | cut -d '=' -f2)
MINIO_BUCKET=$(grep MINIO_LOBE_BUCKET .env | cut -d '=' -f2)
MINIO_PORT=$(grep MINIO_PORT .env | cut -d '=' -f2)

echo -e "Attempting to connect to MinIO..."
if curl -s -I http://localhost:${MINIO_PORT}/minio/health/live | grep -q "200 OK"; then
  echo -e "${GREEN}✓ MinIO service is running and healthy.${NC}"
else
  echo -e "${RED}✗ MinIO service is not available. Please check if it's running.${NC}"
  echo -e "Run 'docker-compose ps' to check the status of the MinIO container."
fi

# 3. Check PGVector extension in PostgreSQL
echo -e "\n${BLUE}3. Checking PostgreSQL vector database...${NC}"
PG_CHECK=$(docker-compose exec postgresql psql -U postgres -d ${LOBE_DB_NAME:-lobechat} -c '\dx vector' 2>/dev/null)

if echo "$PG_CHECK" | grep -q "vector"; then
  echo -e "${GREEN}✓ PGVector extension is enabled in PostgreSQL.${NC}"
else
  echo -e "${RED}✗ PGVector extension might not be enabled.${NC}"
  echo -e "This may affect the vector search functionality in knowledge bases."
fi

# 4. Check OpenAI API key for embeddings
echo -e "\n${BLUE}4. Checking OpenAI API key for embeddings...${NC}"
OPENAI_KEY=$(grep OPENAI_API_KEY .env | cut -d '=' -f2)
if [ -z "$OPENAI_KEY" ]; then
  echo -e "${RED}✗ No OpenAI API key found in .env file.${NC}"
  echo -e "Embeddings generation requires a valid OpenAI API key."
else
  echo -e "${GREEN}✓ OpenAI API key is configured.${NC}"
  
  # Basic key format validation
  if [[ $OPENAI_KEY == sk-* ]]; then
    echo -e "${GREEN}✓ OpenAI API key format looks valid.${NC}"
  else
    echo -e "${YELLOW}⚠️ OpenAI API key format may not be valid. It should start with 'sk-'.${NC}"
  fi
fi

# 5. Generate a test curl command to verify API access to LobeChat
echo -e "\n${BLUE}5. Testing LobeChat API access...${NC}"
LOBE_PORT=$(grep LOBE_PORT .env | cut -d '=' -f2)

echo -e "Checking LobeChat status..."
if curl -s -I http://localhost:${LOBE_PORT:-3210} | grep -q "200"; then
  echo -e "${GREEN}✓ LobeChat is accessible at http://localhost:${LOBE_PORT:-3210}.${NC}"
else
  echo -e "${RED}✗ LobeChat is not accessible. Check if the service is running.${NC}"
fi

# 6. Instructions for manually testing knowledge base
echo -e "\n${BLUE}6. Manual Testing Instructions${NC}"
echo -e "To test the knowledge base functionality:"
echo -e "1. Open LobeChat at http://localhost:${LOBE_PORT:-3210}"
echo -e "2. Log in using your Casdoor credentials at https://casdoor.hanthel.com"
echo -e "3. Navigate to the Knowledge page and create a new knowledge base"
echo -e "4. Upload files from the test-files directory"
echo -e "5. Once processing is complete, test with the following questions:"
echo -e "   • What is the verification token in the HTML test document?"
echo -e "   • What is the capital of Wakanda?"
echo -e "   • What is the smallest bone in the human body?"
echo -e "   • What is the chemical formula for water?"
echo -e "   • What is the JavaScript code for calculating Fibonacci numbers?"

echo -e "\n${BLUE}Test Summary${NC}"
echo -e "The following components have been checked:"
echo -e "• Test files directory and content"
echo -e "• MinIO storage service"
echo -e "• PostgreSQL vector database"
echo -e "• OpenAI API key configuration"
echo -e "• LobeChat accessibility"

echo -e "\n${GREEN}Knowledge base testing setup is complete!${NC}"
echo -e "Follow the manual testing instructions to verify that RAG functionality is working properly."
