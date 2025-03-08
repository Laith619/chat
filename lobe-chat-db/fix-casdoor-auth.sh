#!/bin/bash

# This script fixes Casdoor authentication by:
# 1. Completely resetting the Casdoor database and setup
# 2. Using a fully-specified JSON format that avoids parsing issues
# 3. Restoring database integrity for proper application loading
#
# Based on fix from https://github.com/lobehub/lobe-chat/pull/6714

set -e

echo "⚠️ This script will reset the Casdoor database and fix authentication!"
echo "All Casdoor data will be lost. Make sure you have backups if needed."
echo ""
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Detect platform
platform=$(uname -m)
if [[ "$platform" == "arm64" ]]; then
    # For ARM processors, we'll use AMD64 with emulation
    PLATFORM_TAG=""
    CASDOOR_VERSION="v1.399.0"
    PLATFORM="linux/amd64"
else
    PLATFORM_TAG=""
    CASDOOR_VERSION="v1.399.0"
    PLATFORM="linux/amd64"
fi

echo "Detected platform: $platform, using Casdoor version: $CASDOOR_VERSION with platform: $PLATFORM"

# Stop all containers
echo "Stopping all containers..."
docker-compose down

# Get PostgreSQL password from .env file
PG_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d '=' -f2)
if [ -z "$PG_PASSWORD" ]; then
    echo "Error: Could not find PostgreSQL password in .env file"
    exit 1
fi

# Remove Casdoor data directory if it exists
if [ -d "./casdoor-data" ]; then
    echo "Removing Casdoor data directory..."
    rm -rf ./casdoor-data
    mkdir -p ./casdoor-data
    echo "Casdoor data directory has been reset."
fi

# Create complete init_data.json with all required fields
echo "Creating comprehensive init_data.json..."
cat > init_data.json <<EOL
{
  "organizations": [
    {
      "owner": "admin",
      "name": "built-in",
      "createdTime": "2023-01-01T00:00:00Z",
      "displayName": "Built-in Organization",
      "websiteUrl": "https://lobehub.com",
      "passwordType": "plain",
      "passwordSalt": "",
      "createdIp": "127.0.0.1"
    }
  ],
  "applications": [
    {
      "owner": "admin",
      "name": "app-built-in",
      "createdTime": "2023-01-01T00:00:00Z",
      "displayName": "LobeChat",
      "logo": "https://lobehub.com/logo.png",
      "homepageUrl": "https://lobehub.com",
      "description": "LobeChat Authentication",
      "organization": "built-in",
      "enablePassword": true,
      "enableSignUp": true,
      "enableSigninSession": true,
      "enableAutoSignin": false,
      "enableCodeSignin": false,
      "enableSamlCompress": false,
      "clientId": "943e627d79d5dd8a22a1",
      "clientSecret": "6ec24ac304e92e160ef0d0656ecd86de8cb563f1",
      "redirectUris": "http://localhost:3210/api/auth/callback/casdoor",
      "tokenFormat": "JWT",
      "tokenFields": "",
      "expireInHours": 168,
      "refreshExpireInHours": 168,
      "signupUrl": "http://localhost:3210/signup",
      "signinUrl": "http://localhost:3210/signin",
      "forgetUrl": "http://localhost:3210/forget",
      "affiliationUrl": "",
      "termsOfUse": "",
      "signupItems": "Name,Email,Password",
      "grantTypes": "authorization_code",
      "signinMethods": "Password"
    }
  ],
  "users": [
    {
      "owner": "admin",
      "name": "admin",
      "createdTime": "2023-01-01T00:00:00Z",
      "password": "123456",
      "passwordSalt": "",
      "displayName": "Admin",
      "email": "admin@example.com",
      "phone": "",
      "address": [],
      "affiliation": "",
      "tag": "",
      "isAdmin": true,
      "isGlobalAdmin": true,
      "isForbidden": false
    }
  ]
}
EOL

# Create a directory for Casdoor temporary files
echo "Creating directory for Casdoor temporary files..."
mkdir -p casdoor-data/tmp

# Update docker-compose.yml to use the appropriate Casdoor version and platform
echo "Updating Casdoor version in docker-compose.yml..."
sed -i.bak "s#image: casbin/casdoor:.*#image: casbin/casdoor:$CASDOOR_VERSION#g" docker-compose.yml
sed -i.bak "s#platform: .*#platform: $PLATFORM#g" docker-compose.yml

# Check system disk space
echo "Checking available disk space..."
df -h .
echo "Cleaning up unnecessary Docker resources..."
docker system prune -f

# Start PostgreSQL first to ensure it's ready
echo "Starting PostgreSQL first..."
docker-compose up -d postgresql

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker-compose exec postgresql pg_isready -U postgres; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

# Drop and recreate Casdoor database
echo "Dropping and recreating Casdoor database..."
docker-compose exec postgresql psql -U postgres -c "DROP DATABASE IF EXISTS casdoor;"
docker-compose exec postgresql psql -U postgres -c "CREATE DATABASE casdoor WITH OWNER postgres;"

# Now start Casdoor for initialization
echo "Starting Casdoor for initialization..."
docker-compose up -d casdoor

echo "Waiting for Casdoor to initialize (20 seconds)..."
sleep 20

# Once initialization is complete, clear the init file
echo "Clearing init_data.json to prevent re-initialization..."
echo '{}' > init_data.json

# Start all containers using up -d to ensure everything is properly started
echo "Starting all services..."
docker-compose down
docker-compose up -d

echo "Waiting for services to start..."
sleep 15

echo ""
echo "Fix process complete! You should now be able to log in with:"
echo "Username: admin@example.com"
echo "Password: 123456"
echo ""
echo "To view Casdoor logs for debugging:"
echo "docker-compose logs -f casdoor"
echo ""
echo "To check the status of all services:"
echo "docker-compose ps" 