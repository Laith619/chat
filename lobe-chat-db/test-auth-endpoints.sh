#!/bin/bash

# This script tests various authentication endpoints to verify the Casdoor setup

# Text colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing Casdoor Authentication Configuration${NC}"
echo "======================================================"

# Test OIDC Discovery endpoint
echo -e "\n${BLUE}1. Testing OIDC Discovery Endpoint${NC}"
casdoor_url=$(grep AUTH_CASDOOR_ISSUER .env | cut -d'=' -f2)
DISCOVERY=$(curl -s "$casdoor_url/.well-known/openid-configuration")
if [ $? -eq 0 ] && [ ! -z "$DISCOVERY" ]; then
    echo -e "${GREEN}✓ OIDC Discovery endpoint is working${NC}"
    
    # Extract and show the issuer
    ISSUER=$(echo $DISCOVERY | grep -o '"issuer":"[^"]*"')
    echo "   $ISSUER"
    
    # Check authorization endpoint
    AUTH_ENDPOINT=$(echo $DISCOVERY | grep -o '"authorization_endpoint":"[^"]*"')
    echo "   $AUTH_ENDPOINT"
    
    # Check token endpoint
    TOKEN_ENDPOINT=$(echo $DISCOVERY | grep -o '"token_endpoint":"[^"]*"')
    echo "   $TOKEN_ENDPOINT"
else
    echo -e "${RED}✗ OIDC Discovery endpoint is not working${NC}"
fi

# Test Casdoor admin login
echo -e "\n${BLUE}2. Testing Casdoor Admin Login${NC}"
ADMIN_TEST=$(curl -s -I "$casdoor_url/admin")
if [ $? -eq 0 ]; then
    HTTP_CODE=$(echo "$ADMIN_TEST" | grep "HTTP" | awk '{print $2}')
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
        echo -e "${GREEN}✓ Casdoor admin endpoint is accessible${NC}"
    else
        echo -e "${RED}✗ Casdoor admin returned HTTP code: $HTTP_CODE${NC}"
    fi
else
    echo -e "${RED}✗ Cannot connect to Casdoor admin${NC}"
fi

# Test client ID
echo -e "\n${BLUE}3. Verifying Client ID${NC}"
# First, check in docker-compose.yml
CLIENT_ID_COMPOSE=$(grep "clientId:" docker-compose.yml | head -1 | sed "s/.*clientId: '\([^']*\)'.*/\1/")
echo "   Docker Compose clientId: Using value from .env"

# Check in .env
CLIENT_ID_ENV=$(grep "AUTH_CASDOOR_ID" .env | head -1 | sed "s/AUTH_CASDOOR_ID=//")
echo "   Env file clientId: $CLIENT_ID_ENV"

# Check in init_data.json
CLIENT_ID_JSON=$(grep -o '"clientId": "[^"]*"' init_data.json | head -1 | sed 's/"clientId": "\([^"]*\)"/\1/')
echo "   Init data clientId: $CLIENT_ID_JSON"

# Verify consistency
if [ "$CLIENT_ID_COMPOSE" == "$CLIENT_ID_ENV" ] && [ "$CLIENT_ID_ENV" == "$CLIENT_ID_JSON" ]; then
    echo -e "${GREEN}✓ Client ID is consistent across all configuration files${NC}"
else
    echo -e "${RED}✗ Client ID is not consistent across configuration files${NC}"
fi

# Test redirect URI
echo -e "\n${BLUE}4. Verifying Redirect URI${NC}"
REDIRECT_URI=$(grep -o '"redirectUris":.*' init_data.json | head -1)
echo "   $REDIRECT_URI"

# Test LobeChat authentication endpoint
echo -e "\n${BLUE}5. Testing LobeChat Authentication Endpoint${NC}"
AUTH_TEST=$(curl -s -I http://localhost:3210/api/auth/signin)
if [ $? -eq 0 ]; then
    HTTP_CODE=$(echo "$AUTH_TEST" | grep "HTTP" | awk '{print $2}')
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
        echo -e "${GREEN}✓ LobeChat auth endpoint is accessible${NC}"
    else
        echo -e "${RED}✗ LobeChat auth endpoint returned HTTP code: $HTTP_CODE${NC}"
    fi
else
    echo -e "${RED}✗ Cannot connect to LobeChat auth endpoint${NC}"
fi

# Generate a test OAuth URL
echo -e "\n${BLUE}6. Testing OAuth URL Generation${NC}"
OAUTH_URL="$casdoor_url/login/oauth/authorize?response_type=code&client_id=$CLIENT_ID_ENV&redirect_uri=http%3A%2F%2Flocalhost%3A3210%2Fapi%2Fauth%2Fcallback%2Fcasdoor&scope=profile"
echo "   OAuth test URL: $OAUTH_URL"
echo "   Try opening this URL in your browser to test the OAuth flow manually"

echo -e "\n${BLUE}Test completed. Check the results above to identify any configuration issues.${NC}"
