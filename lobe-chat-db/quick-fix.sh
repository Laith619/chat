#!/bin/bash

# Quick fix script for LobeChat issues
# This script applies essential fixes without restarting containers

# Colors for output formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat Quick Fix${NC}"
echo "====================="

# 1. Check if services are running
echo -e "\n${BLUE}1. Checking if services are running...${NC}"
RUNNING_CONTAINERS=$(docker-compose ps --services --filter "status=running" | wc -l)
if [ "$RUNNING_CONTAINERS" -lt 3 ]; then
  echo -e "${YELLOW}Not all containers are running. Starting minimal services...${NC}"
  docker-compose up -d minio
else
  echo -e "${GREEN}✓ Services are running.${NC}"
fi

# 2. Apply environment variable updates
echo -e "\n${BLUE}2. Updating environment variables...${NC}"

# Update .env file settings without restarting containers
sed -i.bak 's#S3_ENDPOINT=.*#S3_ENDPOINT=http://localhost:9000#g' .env
sed -i.bak 's#S3_PUBLIC_DOMAIN=.*#S3_PUBLIC_DOMAIN=http://localhost:9000#g' .env

if ! grep -q "S3_FORCE_PATH_STYLE=true" .env; then
  echo "S3_FORCE_PATH_STYLE=true" >> .env
  echo -e "${GREEN}✓ Added S3_FORCE_PATH_STYLE setting.${NC}"
fi

if ! grep -q "S3_SSL_ENABLED=false" .env; then
  echo "S3_SSL_ENABLED=false" >> .env
  echo -e "${GREEN}✓ Added S3_SSL_ENABLED setting.${NC}"
fi

if ! grep -q "MINIO_API_CORS_ALLOW_ORIGIN=.*" .env; then
  echo "MINIO_API_CORS_ALLOW_ORIGIN=*" >> .env
  echo -e "${GREEN}✓ Added MINIO_API_CORS_ALLOW_ORIGIN setting.${NC}"
fi

if ! grep -q "MINIO_BROWSER_CORS_ALLOW_ORIGIN=.*" .env; then
  echo "MINIO_BROWSER_CORS_ALLOW_ORIGIN=*" >> .env
  echo -e "${GREEN}✓ Added MINIO_BROWSER_CORS_ALLOW_ORIGIN setting.${NC}"
fi

# 3. Apply direct CORS configuration to running MinIO
echo -e "\n${BLUE}3. Applying CORS configuration directly to MinIO...${NC}"

if docker ps | grep -q "lobe-minio"; then
  echo -e "MinIO container is running, applying CORS configuration..."
  
  # Allow all origins for OPTIONS preflight
  docker exec lobe-minio sh -c 'export MINIO_API_CORS_ALLOW_ORIGIN="*"'
  docker exec lobe-minio sh -c 'export MINIO_BROWSER_CORS_ALLOW_ORIGIN="*"'
  docker exec lobe-minio sh -c 'export MINIO_CORS_ALLOW_ORIGINS="*"'
  
  # Test if MinIO is responding to CORS preflight
  CORS_CHECK=$(curl -s -I -X OPTIONS -H "Origin: http://localhost:3210" -H "Access-Control-Request-Method: PUT" http://localhost:9000/lobe/ | grep -i "access-control-allow-origin")
  
  if [ -n "$CORS_CHECK" ]; then
    echo -e "${GREEN}✓ CORS configuration verified: MinIO is accepting cross-origin requests!${NC}"
    echo -e "$CORS_CHECK"
  else
    echo -e "${YELLOW}⚠️ Could not verify CORS settings. Trying to restart MinIO...${NC}"
    docker-compose restart minio
    sleep 5
  fi
else
  echo -e "${YELLOW}⚠️ MinIO container is not running. Cannot apply CORS settings.${NC}"
fi

# 4. Create a simple HTML file to test MinIO upload
echo -e "\n${BLUE}4. Creating test file for manual upload testing...${NC}"

cat > test-upload.html << EOF
<!DOCTYPE html>
<html>
<head>
  <title>MinIO Upload Test</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
    .result { margin-top: 20px; padding: 10px; border: 1px solid #ddd; }
    button { padding: 10px; background: #4CAF50; color: white; border: none; cursor: pointer; }
    input[type="file"] { margin: 10px 0; }
  </style>
</head>
<body>
  <h1>MinIO Upload Test</h1>
  <div>
    <input type="file" id="fileInput" />
    <button onclick="uploadFile()">Upload to MinIO</button>
  </div>
  <div class="result" id="result">Results will appear here</div>

  <script>
    async function uploadFile() {
      const fileInput = document.getElementById('fileInput');
      const resultDiv = document.getElementById('result');
      
      if (!fileInput.files.length) {
        resultDiv.textContent = 'Please select a file first';
        return;
      }
      
      const file = fileInput.files[0];
      const formData = new FormData();
      formData.append('file', file);
      
      resultDiv.textContent = 'Uploading...';
      
      try {
        const response = await fetch('http://localhost:9000/lobe/' + file.name, {
          method: 'PUT',
          body: file,
          headers: {
            'Content-Type': file.type
          }
        });
        
        if (response.ok) {
          resultDiv.innerHTML = '<strong>Upload successful!</strong><br>' +
            'File URL: <a href="http://localhost:9000/lobe/' + file.name + '" target="_blank">' +
            'http://localhost:9000/lobe/' + file.name + '</a>';
        } else {
          resultDiv.textContent = 'Upload failed: ' + response.status + ' ' + response.statusText;
        }
      } catch (error) {
        resultDiv.textContent = 'Error: ' + error.message;
      }
    }
  </script>
</body>
</html>
EOF

echo -e "${GREEN}✓ Created test-upload.html for manual testing.${NC}"
echo -e "Open this file in your browser to test direct uploads to MinIO."

# 5. Update knowledge base guidance
echo -e "\n${BLUE}5. Checking for knowledge base test files...${NC}"
if [ -d "test-files" ]; then
  FILE_COUNT=$(ls -1 test-files 2>/dev/null | wc -l)
  if [ "$FILE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $FILE_COUNT test files in test-files directory.${NC}"
  else
    echo -e "${YELLOW}No test files found in test-files directory.${NC}"
    mkdir -p test-files
    echo "This is a test file for knowledge base." > test-files/test-document.txt
    echo -e "${GREEN}✓ Created a simple test file.${NC}"
  fi
else
  echo -e "${YELLOW}Creating test-files directory...${NC}"
  mkdir -p test-files
  echo "This is a test file for knowledge base." > test-files/test-document.txt
  echo -e "${GREEN}✓ Created test-files directory with a sample file.${NC}"
fi

echo -e "\n${GREEN}Quick fix applied!${NC}"
echo -e "Try using LobeChat now. If you still encounter issues, you can:"
echo -e "1. Run 'docker-compose restart minio' to restart MinIO"
echo -e "2. Clear your browser cache or use an incognito window"
echo -e "3. Check the logs with 'docker-compose logs -f lobe'"
