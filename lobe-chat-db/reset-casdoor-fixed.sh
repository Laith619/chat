#!/bin/bash

# This script resets the LobeChat database services and connects to external Casdoor
# 1. Resets PostgreSQL database for LobeChat
# 2. Ensures proper MinIO setup
# 3. Checks connectivity to external Casdoor service

set -e

echo "⚠️ This script will reset the LobeChat database and restart services!"
echo "All existing LobeChat data will be lost. Make sure you have backups if needed."
echo ""
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Stop all containers
echo "Stopping all containers..."
docker-compose down

# Print disk space info
echo "Checking available disk space..."
df -h .

# Clean up Docker resources
echo "Cleaning up Docker resources to free disk space..."
docker system prune -f

# Start PostgreSQL first
echo "Starting PostgreSQL first..."
docker-compose up -d postgresql

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker-compose exec postgresql pg_isready -U postgres; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

# Reset the LobeChat database (optional)
read -p "Do you want to reset the LobeChat database? (y/n): " -n 1 -r reset_db
echo ""
if [[ $reset_db =~ ^[Yy]$ ]]; then
    echo "Recreating LobeChat database..."
    docker-compose exec postgresql psql -U postgres -c "DROP DATABASE IF EXISTS ${LOBE_DB_NAME:-lobechat};"
    docker-compose exec postgresql psql -U postgres -c "CREATE DATABASE ${LOBE_DB_NAME:-lobechat} WITH OWNER postgres;"
    echo "LobeChat database has been reset."
fi

# Check connectivity to external Casdoor
echo "Checking connectivity to external Casdoor..."
casdoor_url=$(grep AUTH_CASDOOR_ISSUER .env | cut -d'=' -f2)
if curl -s --head "$casdoor_url" > /dev/null; then
    echo "✅ External Casdoor is accessible at $casdoor_url"
    
    # Verify OIDC configuration
    echo "Verifying Casdoor OIDC configuration..."
    if curl -s "$casdoor_url/.well-known/openid-configuration" | grep -q '"issuer"'; then
        echo "✅ Casdoor OIDC configuration verified!"
    else
        echo "⚠️ Could not verify Casdoor OIDC configuration. Please check your Casdoor setup."
    fi
else
    echo "❌ Could not connect to external Casdoor at $casdoor_url"
    echo "Please ensure your Casdoor server is running and accessible."
    echo "Continuing anyway, but authentication might fail."
fi

# Start all services
echo "Starting all services..."
docker-compose up -d

echo "Waiting for all services to start (20 seconds)..."
sleep 20

# Verify all services are running
echo "Checking service status:"
docker-compose ps

echo ""
echo "Reset process complete! You should now be able to log in using your Casdoor credentials."
echo ""
echo "To view LobeChat logs for debugging:"
echo "docker-compose logs -f lobe"
echo ""
echo "If you experience authentication errors, verify:"
echo "1. Your Casdoor server at $casdoor_url is running"
echo "2. The client ID and secret in .env match what's configured in Casdoor"
echo "3. The redirect URI in Casdoor is set to http://localhost:3210/api/auth/callback/casdoor"
