#!/bin/bash

# Enhanced script to reset Casdoor database to fix initialization issues
# This addresses the xorm adapter nil pointer dereference issue

set -e

echo "⚠️ WARNING: This script will delete and recreate the Casdoor database!"
echo "All Casdoor data will be lost. Make sure you have backups if needed."
echo ""
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Stop the containers
echo "Stopping containers..."
docker-compose down

# Get PostgreSQL password from .env file
PG_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d '=' -f2)
if [ -z "$PG_PASSWORD" ]; then
    echo "Error: Could not find PostgreSQL password in .env file"
    exit 1
fi

# Save the volume path
DATA_DIR="./data"

# Check if the data directory exists and has content
if [ -d "$DATA_DIR" ] && [ "$(ls -A $DATA_DIR)" ]; then
    echo "Starting PostgreSQL container only..."
    
    # Start PostgreSQL container only
    docker-compose up -d postgresql
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to start..."
    until docker-compose exec postgresql pg_isready -U postgres; do
      echo "PostgreSQL is unavailable - sleeping"
      sleep 1
    done
    
    echo "PostgreSQL is ready - performing database operations"
    
    # Connect to PostgreSQL and drop/recreate the casdoor database
    echo "Dropping existing Casdoor database..."
    docker-compose exec postgresql psql -U postgres -c "DROP DATABASE IF EXISTS casdoor;"
    
    echo "Creating fresh Casdoor database..."
    docker-compose exec postgresql psql -U postgres -c "CREATE DATABASE casdoor WITH OWNER postgres;"
    
    echo "Casdoor database has been reset."
    
    # Stop PostgreSQL
    docker-compose down postgresql
else
    echo "PostgreSQL data directory not found or empty. No reset needed."
fi

# Remove Casdoor data directory if it exists
if [ -d "./casdoor-data" ]; then
    echo "Removing Casdoor data directory..."
    rm -rf ./casdoor-data
    mkdir -p ./casdoor-data
    echo "Casdoor data directory has been reset."
fi

# Update docker-compose.yml to use clean database flags
echo "Ensuring docker-compose.yml has the correct configuration..."
if ! grep -q "CASDOOR_DROP_AND_CREATE_DATABASE" docker-compose.yml; then
    echo "Warning: CASDOOR_DROP_AND_CREATE_DATABASE flag not found in docker-compose.yml"
    echo "Please ensure the Casdoor service in docker-compose.yml includes:"
    echo "  - The --createDatabase=true --dropDatabase=true flags in the command"
    echo "  - CASDOOR_CREATE_DATABASE: 'true' and CASDOOR_DROP_AND_CREATE_DATABASE: 'true' environment variables"
fi

echo ""
echo "Database reset complete. You can now restart the containers with:"
echo "docker-compose up -d"
echo ""
echo "To view Casdoor logs for debugging:"
echo "docker-compose logs -f casdoor"
