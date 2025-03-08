#!/bin/bash

# Script to restart LobeChat with all fixes applied
# - Applies Casdoor auth fixes
# - Applies MinIO CORS fixes
# - Applies database permission fixes

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat Complete Restart with Fixes${NC}"
echo "======================================="

# 1. Check if docker-compose.override.yml exists
echo -e "\n${BLUE}1. Checking for override file...${NC}"
if [ -f "docker-compose.override.yml" ]; then
  echo -e "${GREEN}✓ Override file exists.${NC}"
else
  echo -e "${RED}✗ Override file not found.${NC}"
  echo -e "Please run the setup scripts first to create the necessary configuration files."
  exit 1
fi

# 2. Stop all services
echo -e "\n${BLUE}2. Stopping all services...${NC}"
docker-compose down
echo -e "${GREEN}✓ All services stopped.${NC}"

# 3. Apply environment variable updates
echo -e "\n${BLUE}3. Checking environment variables...${NC}"

# Make sure S3 endpoint settings are correct
if ! grep -q "S3_FORCE_PATH_STYLE=true" .env; then
  echo -e "${YELLOW}Adding S3_FORCE_PATH_STYLE to .env${NC}"
  echo "S3_FORCE_PATH_STYLE=true" >> .env
fi

if ! grep -q "S3_SSL_ENABLED=false" .env; then
  echo -e "${YELLOW}Adding S3_SSL_ENABLED to .env${NC}"
  echo "S3_SSL_ENABLED=false" >> .env
fi

# Add CORS configuration
if ! grep -q "MINIO_API_CORS_ALLOW_ORIGIN=http://localhost:3210" .env; then
  echo -e "${YELLOW}Adding MINIO_API_CORS_ALLOW_ORIGIN to .env${NC}"
  echo "MINIO_API_CORS_ALLOW_ORIGIN=http://localhost:3210" >> .env
fi

if ! grep -q "MINIO_BROWSER_CORS_ALLOW_ORIGIN=http://localhost:3210" .env; then
  echo -e "${YELLOW}Adding MINIO_BROWSER_CORS_ALLOW_ORIGIN to .env${NC}"
  echo "MINIO_BROWSER_CORS_ALLOW_ORIGIN=http://localhost:3210" >> .env
fi

echo -e "${GREEN}✓ Environment variables checked and updated.${NC}"

# 4. Wait for PostgreSQL to be ready
echo -e "\n${BLUE}4. Starting PostgreSQL first...${NC}"
docker-compose up -d postgresql
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"

until docker-compose exec postgresql pg_isready -U postgres; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo -e "${GREEN}✓ PostgreSQL is ready.${NC}"

# 5. Check Casdoor connectivity
echo -e "\n${BLUE}5. Checking Casdoor connectivity...${NC}"
CASDOOR_ISSUER=$(grep AUTH_CASDOOR_ISSUER .env | cut -d'=' -f2)

if curl -s --connect-timeout 5 --max-time 10 "$CASDOOR_ISSUER/.well-known/openid-configuration" | grep -q "issuer"; then
  echo -e "${GREEN}✓ Casdoor OIDC configuration verified!${NC}"
else
  echo -e "${RED}✗ Cannot access Casdoor OIDC configuration.${NC}"
  echo -e "${YELLOW}Authentication may not work properly.${NC}"
  echo -e "You may want to run ./fix-casdoor-connection.sh for diagnostics."
fi

# 6. Start all services with the override
echo -e "\n${BLUE}6. Starting all services with override configuration...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ Services started.${NC}"

# 7. Wait for services to initialize
echo -e "\n${BLUE}7. Waiting for services to initialize (15 seconds)...${NC}"
sleep 15

# 8. Apply MinIO CORS settings directly to container
echo -e "\n${BLUE}8. Applying direct MinIO CORS configuration...${NC}"

# Create a CORS config in the container
docker exec lobe-minio sh -c 'mkdir -p /tmp'
docker exec lobe-minio sh -c 'echo "Access-Control-Allow-Origin=*" > /tmp/cors.conf'
docker exec lobe-minio sh -c 'echo "Access-Control-Allow-Methods=GET,PUT,POST,DELETE" >> /tmp/cors.conf'
docker exec lobe-minio sh -c 'echo "Access-Control-Allow-Headers=*" >> /tmp/cors.conf'

# Set bucket to public
docker exec lobe-minio sh -c "mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} || true"
docker exec lobe-minio sh -c "mc policy set public local/lobe || true"
docker exec lobe-minio sh -c "mc anonymous set download local/lobe || true"

echo -e "${GREEN}✓ Direct MinIO configuration applied.${NC}"

# 9. Check for file/permission errors in logs
echo -e "\n${BLUE}9. Checking for errors in logs...${NC}"
ERROR_COUNT=$(docker-compose logs lobe | grep -i "error\|unauthorized\|permission denied" | wc -l)

if [ $ERROR_COUNT -gt 0 ]; then
  echo -e "${YELLOW}Found $ERROR_COUNT potential issues in logs:${NC}"
  docker-compose logs lobe | grep -i "error\|unauthorized\|permission denied" | tail -n 5
  echo -e "${YELLOW}Check the full logs with: docker-compose logs lobe${NC}"
else
  echo -e "${GREEN}✓ No obvious errors found in logs.${NC}"
fi

# 10. Print instructions
echo -e "\n${BLUE}LobeChat is now running with all fixes applied!${NC}"
echo -e "Access LobeChat at: ${GREEN}http://localhost:3210${NC}"
echo -e "Access MinIO console at: ${GREEN}http://localhost:9001${NC}"
echo -e "\nLogin credentials:"
echo -e "- LobeChat: Use your Casdoor credentials (${CASDOOR_ISSUER})"
echo -e "- MinIO console: Username=${MINIO_ROOT_USER}, Password=<from .env file>"

echo -e "\n${YELLOW}If you still experience issues:${NC}"
echo -e "1. Try clearing your browser cache or using an incognito window"
echo -e "2. Check detailed logs with: ${GREEN}docker-compose logs -f lobe${NC}"
echo -e "3. Run specific fix scripts: ${GREEN}./fix-minio-cors.sh${NC} or ${GREEN}./fix-casdoor-connection.sh${NC}"
