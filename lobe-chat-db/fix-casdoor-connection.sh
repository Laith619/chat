#!/bin/bash

# Script to fix Casdoor connection issues

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat Casdoor Connection Fix${NC}"
echo "====================================="

# Get Casdoor config from .env file
AUTH_CASDOOR_ENDPOINT=$(grep AUTH_CASDOOR_ENDPOINT .env | cut -d '=' -f2)
AUTH_CASDOOR_ISSUER=$(grep AUTH_CASDOOR_ISSUER .env | cut -d '=' -f2)
AUTH_CASDOOR_ID=$(grep AUTH_CASDOOR_ID .env | cut -d '=' -f2)
AUTH_CASDOOR_SECRET=$(grep AUTH_CASDOOR_SECRET .env | cut -d '=' -f2)

echo -e "Current Casdoor configuration:"
echo -e "Endpoint: ${AUTH_CASDOOR_ENDPOINT}"
echo -e "Issuer: ${AUTH_CASDOOR_ISSUER}"
echo -e "Client ID: ${AUTH_CASDOOR_ID}"
echo -e "Client Secret: ${AUTH_CASDOOR_SECRET}"

# 1. Check if LobeChat container is running
echo -e "\n${BLUE}1. Checking LobeChat container status...${NC}"
if docker ps | grep -q "lobe-chat"; then
  echo -e "${GREEN}✓ LobeChat container is running.${NC}"
else
  echo -e "${RED}✗ LobeChat container is not running. Please start the services first.${NC}"
  exit 1
fi

# 2. Install curl in the LobeChat container
echo -e "\n${BLUE}2. Installing curl in the LobeChat container...${NC}"
docker exec lobe-chat sh -c "apk add --no-cache curl" && \
  echo -e "${GREEN}✓ curl installed in LobeChat container${NC}" || \
  echo -e "${RED}✗ Failed to install curl. Continuing anyway...${NC}"

# 3. Check access to external Casdoor from the host
echo -e "\n${BLUE}3. Checking access to external Casdoor from host...${NC}"
if curl -s --connect-timeout 10 -I "${AUTH_CASDOOR_ENDPOINT}" | grep -q "HTTP"; then
  echo -e "${GREEN}✓ External Casdoor is accessible from host.${NC}"
  CASDOOR_HOST_ACCESSIBLE=true
else
  echo -e "${RED}✗ External Casdoor is not accessible from host.${NC}"
  CASDOOR_HOST_ACCESSIBLE=false
fi

# 4. Check access to external Casdoor from the LobeChat container
echo -e "\n${BLUE}4. Checking access to external Casdoor from LobeChat container...${NC}"
if docker exec lobe-chat sh -c "curl -s --connect-timeout 10 -I ${AUTH_CASDOOR_ENDPOINT}" | grep -q "HTTP"; then
  echo -e "${GREEN}✓ External Casdoor is accessible from LobeChat container.${NC}"
  CASDOOR_CONTAINER_ACCESSIBLE=true
else
  echo -e "${RED}✗ External Casdoor is not accessible from LobeChat container.${NC}"
  CASDOOR_CONTAINER_ACCESSIBLE=false
fi

# 5. Check if DNS resolution works in the container
echo -e "\n${BLUE}5. Checking DNS resolution in LobeChat container...${NC}"
CASDOOR_HOST=$(echo $AUTH_CASDOOR_ENDPOINT | sed -E 's/https?:\/\///g' | sed -E 's/:.+//g' | sed -E 's/\/.+//g')
echo -e "Trying to resolve: ${CASDOOR_HOST}"

if docker exec lobe-chat sh -c "nslookup ${CASDOOR_HOST} 2>/dev/null || getent hosts ${CASDOOR_HOST} 2>/dev/null || dig ${CASDOOR_HOST} 2>/dev/null || host ${CASDOOR_HOST} 2>/dev/null" | grep -q "Address"; then
  echo -e "${GREEN}✓ Casdoor hostname resolves correctly in container.${NC}"
  DNS_WORKS=true
else
  echo -e "${RED}✗ Cannot resolve Casdoor hostname in container.${NC}"
  DNS_WORKS=false
fi

# 6. Check if OIDC configuration can be fetched
echo -e "\n${BLUE}6. Checking if OIDC configuration can be fetched...${NC}"
if curl -s --connect-timeout 10 "${AUTH_CASDOOR_ENDPOINT}/.well-known/openid-configuration" | grep -q "issuer"; then
  echo -e "${GREEN}✓ OIDC configuration can be fetched from external Casdoor.${NC}"
  OIDC_ACCESSIBLE=true
else
  echo -e "${RED}✗ Cannot fetch OIDC configuration from external Casdoor.${NC}"
  OIDC_ACCESSIBLE=false
fi

# 7. Add Casdoor host to container's /etc/hosts if DNS resolution fails
if [ "$DNS_WORKS" = false ] && [ "$CASDOOR_HOST_ACCESSIBLE" = true ]; then
  echo -e "\n${BLUE}7. Adding Casdoor host to container's /etc/hosts...${NC}"
  
  # Get IP address of the Casdoor host
  CASDOOR_IP=$(curl -s --connect-timeout 10 -4 "https://dns.google/resolve?name=${CASDOOR_HOST}&type=A" | grep -oP '"data":"[^"]*' | sed 's/"data":"//g')
  
  if [ -n "$CASDOOR_IP" ]; then
    echo -e "Resolved ${CASDOOR_HOST} to IP: ${CASDOOR_IP}"
    docker exec lobe-chat sh -c "echo '${CASDOOR_IP} ${CASDOOR_HOST}' >> /etc/hosts"
    echo -e "${GREEN}✓ Added Casdoor host to container's /etc/hosts.${NC}"
    
    # Verify the change worked
    echo -e "Verifying DNS resolution after /etc/hosts update..."
    if docker exec lobe-chat sh -c "ping -c 1 ${CASDOOR_HOST} 2>/dev/null"; then
      echo -e "${GREEN}✓ Can now ping Casdoor host from container.${NC}"
    else
      echo -e "${RED}✗ Still cannot ping Casdoor host from container.${NC}"
    fi
  else
    echo -e "${RED}✗ Could not resolve Casdoor host IP.${NC}"
  fi
fi

# 8. Generate a diagnostic report
echo -e "\n${BLUE}8. Generating diagnostic report...${NC}"
REPORT_FILE="casdoor-connection-report.txt"

cat > $REPORT_FILE << EOF
LobeChat Casdoor Connection Diagnostic Report
=============================================
Date: $(date)

Configuration:
- External Casdoor Endpoint: ${AUTH_CASDOOR_ENDPOINT}
- External Casdoor Issuer: ${AUTH_CASDOOR_ISSUER}
- Client ID: ${AUTH_CASDOOR_ID}

Connectivity Tests:
- External Casdoor accessible from host: $([ "$CASDOOR_HOST_ACCESSIBLE" = true ] && echo "Yes" || echo "No")
- External Casdoor accessible from container: $([ "$CASDOOR_CONTAINER_ACCESSIBLE" = true ] && echo "Yes" || echo "No")
- DNS resolution in container: $([ "$DNS_WORKS" = true ] && echo "Working" || echo "Not working")
- OIDC configuration accessible: $([ "$OIDC_ACCESSIBLE" = true ] && echo "Yes" || echo "No")

Container Network Information:
$(docker exec lobe-chat sh -c "ip addr 2>/dev/null || ifconfig 2>/dev/null")

Container DNS Settings:
$(docker exec lobe-chat sh -c "cat /etc/resolv.conf 2>/dev/null")

Container Hosts File:
$(docker exec lobe-chat sh -c "cat /etc/hosts 2>/dev/null")

EOF

echo -e "${GREEN}Diagnostic report saved to ${REPORT_FILE}${NC}"

# 9. Provide recommendations based on the diagnosis
echo -e "\n${BLUE}9. Recommendations:${NC}"

if [ "$CASDOOR_HOST_ACCESSIBLE" = true ] && [ "$CASDOOR_CONTAINER_ACCESSIBLE" = false ]; then
  echo -e "${YELLOW}There appears to be a network issue within the container.${NC}"
  echo -e "This could be due to DNS resolution or container network configuration."
  echo -e "Consider the following options:"
  echo -e "1. Add the Casdoor host to container's /etc/hosts file (we attempted this)"
  echo -e "2. Check if the external Casdoor server allows connections from the container's IP range"
  echo -e "3. Update the container's DNS settings in docker-compose.yml"
  
  # Generate a docker-compose update command
  cat > update-dns.sh << EOF
#!/bin/bash
sed -i '/lobe-chat:/,/networks:/s/network_mode:.*$/network_mode: bridge\n    dns:\n      - 8.8.8.8\n      - 8.8.4.4/' docker-compose.yml
EOF
  chmod +x update-dns.sh
  echo -e "A script has been created (update-dns.sh) to update the DNS settings in docker-compose.yml"
  
elif [ "$CASDOOR_HOST_ACCESSIBLE" = false ]; then
  echo -e "${RED}The external Casdoor server is not accessible.${NC}"
  echo -e "Please check that:"
  echo -e "1. The server at ${AUTH_CASDOOR_ENDPOINT} is running"
  echo -e "2. Your network allows connections to this server"
  echo -e "3. The URL is correct in your .env file"
fi

if [ "$OIDC_ACCESSIBLE" = false ]; then
  echo -e "${YELLOW}The OIDC configuration could not be fetched.${NC}"
  echo -e "This might indicate that:"
  echo -e "1. The Casdoor server is not configured for OIDC"
  echo -e "2. The OIDC endpoint is not at the standard location (/.well-known/openid-configuration)"
  echo -e "3. The Casdoor server might be running but not fully initialized"
fi

echo -e "\n${GREEN}Connection diagnostics complete!${NC}"
echo -e "If you need to restart the services with updated configuration:"
echo -e "1. Stop all services: ${YELLOW}docker-compose down${NC}"
echo -e "2. Apply any configuration changes"
echo -e "3. Start all services: ${YELLOW}docker-compose up -d${NC}"
