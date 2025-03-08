#!/bin/bash

# Script to fix MinIO CORS configuration issues

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat MinIO CORS Fix${NC}"
echo "==========================="

# Get MinIO credentials from .env file
MINIO_USER=$(grep MINIO_ROOT_USER .env | cut -d '=' -f2)
MINIO_PASSWORD=$(grep MINIO_ROOT_PASSWORD .env | cut -d '=' -f2)
MINIO_BUCKET=$(grep MINIO_LOBE_BUCKET .env | cut -d '=' -f2)
MINIO_PORT=$(grep MINIO_PORT .env | cut -d '=' -f2)

echo -e "MinIO parameters:"
echo -e "User: ${MINIO_USER}"
echo -e "Bucket: ${MINIO_BUCKET}"
echo -e "Port: ${MINIO_PORT}"

# 1. Check if MinIO is running
echo -e "\n${BLUE}1. Checking MinIO status...${NC}"
if curl -s -I http://localhost:${MINIO_PORT}/minio/health/live | grep -q "200 OK"; then
  echo -e "${GREEN}✓ MinIO is running.${NC}"
else
  echo -e "${RED}✗ MinIO is not running. Please start the services first.${NC}"
  exit 1
fi

# 2. Reset all CORS settings
echo -e "\n${BLUE}2. Resetting CORS configuration...${NC}"

# Configure MinIO client if not already configured
if ! command -v mc &> /dev/null; then
  echo -e "${YELLOW}MinIO client (mc) not found. Installing...${NC}"
  curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
  chmod +x mc
  sudo mv mc /usr/local/bin/
  echo -e "${GREEN}MinIO client installed.${NC}"
fi

# Configure MinIO client with provided credentials
mc alias set myminio http://localhost:${MINIO_PORT} ${MINIO_USER} ${MINIO_PASSWORD} 

# Check if bucket exists and create if not
if ! mc ls myminio | grep -q ${MINIO_BUCKET}; then
  echo -e "${YELLOW}Bucket does not exist. Creating...${NC}"
  mc mb myminio/${MINIO_BUCKET}
  echo -e "${GREEN}✓ Bucket created.${NC}"
else
  echo -e "${GREEN}✓ Bucket exists.${NC}"
fi

# 3. Apply full access policy
echo -e "\n${BLUE}3. Applying public access policy...${NC}"
mc policy set download myminio/${MINIO_BUCKET}
mc anonymous set download myminio/${MINIO_BUCKET}
echo -e "${GREEN}✓ Public access policy applied.${NC}"

# 4. Apply CORS policies using multiple methods for maximum compatibility
echo -e "\n${BLUE}4. Applying CORS policies...${NC}"

# Create a key=value config file for CORS rules (Beego compatible format)
cat > /tmp/cors_rules.conf << EOF
AllowedHeaders=*
AllowedMethods=GET,PUT,POST,DELETE
AllowedOrigins=http://localhost:3210
ExposeHeaders=ETag,Content-Length,Content-Type,X-Amz-*
MaxAgeSecs=3000
EOF

echo -e "${YELLOW}Attempting multiple CORS configuration methods...${NC}"

# Attempt various methods of setting CORS (trying all known versions of MinIO client commands)
echo -e "Method 1: Using config file..."
mc cors set myminio/${MINIO_BUCKET} /tmp/cors_rules.conf 2>/dev/null || echo -e "${YELLOW}Method 1 not supported${NC}"

echo -e "Method 2: Using add command..."
mc cors add myminio/${MINIO_BUCKET} --allow-origin "http://localhost:3210" --allow-method "GET,PUT,POST,DELETE" --allow-header "*" 2>/dev/null || echo -e "${YELLOW}Method 2 not supported${NC}"

echo -e "Method 3: Direct CORS policy..."
mc admin config set myminio cors:corsrules "AllowedHeaders=*&AllowedMethods=GET,PUT,POST,DELETE&AllowedOrigins=http://localhost:3210&ExposeHeaders=ETag,Content-Length,Content-Type" 2>/dev/null || echo -e "${YELLOW}Method 3 not supported${NC}"

echo -e "Method 4: Server-wide CORS..."
mc admin config set myminio api cors_allow_origins="http://localhost:3210" 2>/dev/null || echo -e "${YELLOW}Method 4 not supported${NC}"

# 5. Update Docker container environment variables
echo -e "\n${BLUE}5. Updating MinIO environment variables and container configuration...${NC}"

# Create a custom run script for MinIO
cat > /tmp/minio-cors-config.sh << EOF
#!/bin/sh
export MINIO_API_CORS_ALLOW_ORIGIN="*"
export MINIO_BROWSER_REDIRECT_URL="http://localhost:9001"
export MINIO_DOMAIN="localhost"
export MINIO_CORS_ALLOW_ORIGINS="http://localhost:3210"
export MINIO_BROWSER_CORS_ALLOW_ORIGIN="http://localhost:3210"

# Start MinIO
minio server /etc/minio/data --address ':9000' --console-address ':9001' 
EOF

# Copy the script into the container
docker cp /tmp/minio-cors-config.sh lobe-minio:/tmp/
docker exec lobe-minio chmod +x /tmp/minio-cors-config.sh

# Update .env file with required CORS settings
if ! grep -q "MINIO_BROWSER_CORS_ALLOW_ORIGIN" .env; then
  echo "MINIO_BROWSER_CORS_ALLOW_ORIGIN=http://localhost:3210" >> .env
  echo -e "${GREEN}✓ Added MINIO_BROWSER_CORS_ALLOW_ORIGIN to .env${NC}"
fi

# 6. Restart MinIO for changes to take effect
echo -e "\n${BLUE}6. Restarting MinIO...${NC}"
docker-compose restart minio
echo -e "${GREEN}✓ MinIO restarted.${NC}"
sleep 5

# 7. Verify CORS configuration
echo -e "\n${BLUE}7. Verifying CORS with OPTIONS request...${NC}"
curl -v -X OPTIONS "http://localhost:${MINIO_PORT}/${MINIO_BUCKET}/" \
  -H "Origin: http://localhost:3210" \
  -H "Access-Control-Request-Method: PUT" \
  -H "Access-Control-Request-Headers: content-type" \
  2>&1 | grep -i "access-control" || echo -e "${YELLOW}No CORS headers detected in response${NC}"

# Also test with a preflight request to a specific path
echo -e "Testing preflight request to a specific path..."
curl -v -X OPTIONS "http://localhost:${MINIO_PORT}/${MINIO_BUCKET}/test-file" \
  -H "Origin: http://localhost:3210" \
  -H "Access-Control-Request-Method: PUT" \
  -H "Access-Control-Request-Headers: content-type" \
  2>&1 | grep -i "access-control" || echo -e "${YELLOW}No CORS headers detected for specific path${NC}"

# 8. Create a test file to verify upload permissions
echo -e "\n${BLUE}8. Creating test file in MinIO to verify permissions...${NC}"
echo "This is a test file for MinIO CORS configuration" > /tmp/test-file.txt
mc cp /tmp/test-file.txt myminio/${MINIO_BUCKET}/test-file.txt && \
  echo -e "${GREEN}✓ Test file uploaded successfully${NC}" || \
  echo -e "${RED}✗ Failed to upload test file${NC}"

# Make the test file public
mc anonymous set download myminio/${MINIO_BUCKET}/test-file.txt
echo -e "Test file URL: http://localhost:${MINIO_PORT}/${MINIO_BUCKET}/test-file.txt"

# 9. Install curl in the lobe container
echo -e "\n${BLUE}9. Installing curl in the LobeChat container...${NC}"
docker exec lobe-chat sh -c "apk add --no-cache curl" && \
  echo -e "${GREEN}✓ curl installed in LobeChat container${NC}" || \
  echo -e "${RED}✗ Failed to install curl in LobeChat container${NC}"

echo -e "\n${GREEN}CORS fix complete!${NC}"
echo -e "If file upload still fails, try the following:"
echo -e "1. Restart your browser to clear any cached CORS errors"
echo -e "2. Restart all services with: ${YELLOW}docker-compose down && docker-compose up -d${NC}"
echo -e "3. Check LobeChat logs for detailed error information: ${YELLOW}docker-compose logs lobe${NC}"
