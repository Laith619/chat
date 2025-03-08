#!/bin/bash

# Script to manually register the LobeChat application in the Casdoor database
# This is a workaround for cases where the init_data.json approach doesn't work

set -e

echo "This script will manually register the LobeChat application in Casdoor"
echo ""

# Get PostgreSQL password from .env file
PG_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d '=' -f2)
if [ -z "$PG_PASSWORD" ]; then
    echo "Error: Could not find PostgreSQL password in .env file"
    exit 1
fi

# Make sure PostgreSQL is running
if ! docker ps | grep -q lobe-postgres; then
    echo "PostgreSQL container is not running. Starting containers..."
    docker-compose up -d postgresql
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to start..."
    until docker-compose exec postgresql pg_isready -U postgres; do
      echo "PostgreSQL is unavailable - sleeping"
      sleep 1
    done
    echo "PostgreSQL is ready"
fi

echo "Registering LobeChat application in Casdoor..."

# The SQL to insert/update the application
SQL="
-- First, check if the application exists
DO \$\$
BEGIN
    IF EXISTS (SELECT 1 FROM application WHERE name = 'app-built-in') THEN
        -- Update existing application
        UPDATE application 
        SET 
            client_id = '943e627d79d5dd8a22a1',
            client_secret = '6ec24ac304e92e160ef0d0656ecd86de8cb563f1',
            redirect_uris = '{\"http://localhost:3210/api/auth/callback/casdoor\"}',
            token_format = 'JWT',
            expire_in_hours = 168,
            refresh_expire_in_hours = 168,
            organization = 'built-in'
        WHERE name = 'app-built-in';
        
        RAISE NOTICE 'Application updated successfully';
    ELSE
        -- Insert new application
        INSERT INTO application (
            owner, name, created_time, display_name, logo, homepage_url, description,
            organization, enable_password, enable_signup, enable_signin_session, enable_auto_signin,
            enable_code_signin, enable_saml_compress, client_id, client_secret, redirect_uris, token_format,
            token_fields, expire_in_hours, refresh_expire_in_hours, signup_url, signin_url, forget_url, 
            grant_types, signin_methods
        ) VALUES (
            'admin', 'app-built-in', NOW(), 'LobeChat', 'https://lobehub.com/logo.png', 'https://lobehub.com',
            'LobeChat Authentication', 'built-in', true, true, true, false, false, false, 
            '943e627d79d5dd8a22a1', '6ec24ac304e92e160ef0d0656ecd86de8cb563f1', 
            '{\"http://localhost:3210/api/auth/callback/casdoor\"}', 'JWT', '{}', 168, 168,
            'http://localhost:3210/signup', 'http://localhost:3210/signin', 'http://localhost:3210/forget',
            '{\"authorization_code\"}', '{\"Password\"}'
        );
        
        RAISE NOTICE 'Application inserted successfully';
    END IF;
END \$\$;
"

# Execute the SQL
docker-compose exec postgresql psql -U postgres -d casdoor -c "${SQL}"

echo "LobeChat application registration complete"
echo "You can now restart Casdoor with: docker-compose restart casdoor" 