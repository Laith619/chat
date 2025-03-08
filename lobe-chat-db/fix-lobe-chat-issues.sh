#!/bin/bash

# Script to fix LobeChat issues
# This script addresses various issues with LobeChat deployment

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat Issues Fix${NC}"
echo "==========================="

# 1. First check if containers are running
echo -e "\n${BLUE}1. Checking container status...${NC}"
if ! docker ps | grep -q "lobe-chat"; then
  echo -e "${YELLOW}LobeChat container is not running. Starting containers...${NC}"
  docker-compose up -d
  echo -e "${GREEN}✓ Containers started.${NC}"
else
  echo -e "${GREEN}✓ LobeChat container is already running.${NC}"
fi

# 2. Install curl in the LobeChat container
echo -e "\n${BLUE}2. Installing curl in the LobeChat container...${NC}"
docker exec lobe-chat apt-get update
docker exec lobe-chat apt-get install -y curl
echo -e "${GREEN}✓ Curl installed in the LobeChat container.${NC}"

# 3. Check and update OpenAI embedding model in the environment variables
echo -e "\n${BLUE}3. Updating OpenAI embedding model configuration...${NC}"

# Create a backup of the .env file if it exists
if [ -f ".env" ]; then
  cp .env .env.backup.$(date +%Y%m%d%H%M%S)
  echo -e "${GREEN}✓ Created backup of .env file.${NC}"
fi

# Check if .env file exists, if not create it
if [ ! -f ".env" ]; then
  touch .env
  echo -e "${YELLOW}Created new .env file.${NC}"
fi

# Update the embedding model in the .env file
if grep -q "LOBE_EMBEDDING_MODEL=" .env; then
  # Update existing embedding model setting
  sed -i.bak 's/LOBE_EMBEDDING_MODEL=.*/LOBE_EMBEDDING_MODEL=text-embedding-ada-002/' .env
  echo -e "${GREEN}✓ Updated embedding model to text-embedding-ada-002.${NC}"
else
  # Add embedding model setting if it doesn't exist
  echo "LOBE_EMBEDDING_MODEL=text-embedding-ada-002" >> .env
  echo -e "${GREEN}✓ Added embedding model setting to .env file.${NC}"
fi

# 4. Check Casdoor connection
echo -e "\n${BLUE}4. Checking Casdoor configuration...${NC}"
CASDOOR_ENDPOINT=$(grep "CASDOOR_ENDPOINT" .env | cut -d '=' -f2)

if [ -z "$CASDOOR_ENDPOINT" ]; then
  echo -e "${YELLOW}No Casdoor endpoint configured. Disabling Casdoor...${NC}"
  
  # Disable Casdoor by setting the config to false
  if grep -q "ENABLE_OAUTH=" .env; then
    sed -i.bak 's/ENABLE_OAUTH=.*/ENABLE_OAUTH=false/' .env
  else
    echo "ENABLE_OAUTH=false" >> .env
  fi
  
  echo -e "${GREEN}✓ Disabled Casdoor authentication.${NC}"
else
  echo -e "${YELLOW}Casdoor endpoint is configured: $CASDOOR_ENDPOINT${NC}"
  echo -e "${YELLOW}Testing connection to Casdoor...${NC}"
  
  if curl -s --connect-timeout 5 "$CASDOOR_ENDPOINT" > /dev/null; then
    echo -e "${GREEN}✓ Successfully connected to Casdoor endpoint.${NC}"
  else
    echo -e "${RED}✗ Could not connect to Casdoor endpoint.${NC}"
    echo -e "${YELLOW}Would you like to disable Casdoor authentication? (y/n)${NC}"
    read -p "" disable_casdoor
    
    if [[ $disable_casdoor =~ ^[Yy]$ ]]; then
      if grep -q "ENABLE_OAUTH=" .env; then
        sed -i.bak 's/ENABLE_OAUTH=.*/ENABLE_OAUTH=false/' .env
      else
        echo "ENABLE_OAUTH=false" >> .env
      fi
      echo -e "${GREEN}✓ Disabled Casdoor authentication.${NC}"
    else
      echo -e "${YELLOW}Casdoor authentication remains enabled. Please check your Casdoor server.${NC}"
    fi
  fi
fi

# 5. Restart the containers to apply changes
echo -e "\n${BLUE}5. Restarting containers to apply changes...${NC}"
docker-compose down
docker-compose up -d

echo -e "\n${GREEN}✓ All fixes have been applied!${NC}"
echo -e "LobeChat should now be running with the fixed configuration."
echo -e "You can check the logs with: ${YELLOW}docker-compose logs -f lobe-chat${NC}"
echo -e "If you still have issues, please check your OpenAI API key and other provider configurations." 