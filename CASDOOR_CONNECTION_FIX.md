# Casdoor Connection Fix

## Problem

Your LobeChat logs show the following warning:

```
Checking connection to external Casdoor...
Warning: Could not connect to external Casdoor at https://casdoor.hanthel.com
Please ensure your Casdoor server is running and accessible.
Casdoor OIDC configuration:
Could not fetch OIDC configuration
```

Additionally, there's a missing dependency in the container:

```
/bin/sh: curl: not found
```

These issues are preventing LobeChat from connecting to your Casdoor authentication service.

## Solutions

### 1. Using the Automated Script

Run the provided script to automatically address these issues:

```bash
./fix-lobe-chat-issues.sh
```

The script will:
- Install curl in the LobeChat container
- Test the connection to your Casdoor endpoint
- Disable Casdoor authentication if the connection fails (after asking for your confirmation)

### 2. Manual Configuration

#### Install curl in the container

1. Run the following commands:
   ```bash
   docker exec lobe-chat apt-get update
   docker exec lobe-chat apt-get install -y curl
   ```

#### Verify Casdoor Configuration

1. Check if your Casdoor server is running and accessible:
   ```bash
   curl -v https://casdoor.hanthel.com
   ```

2. If your Casdoor server is not running or accessible, you have two options:

   a) Start your Casdoor server and ensure it's accessible from the LobeChat container
   
   b) Disable Casdoor authentication by adding or updating in your `.env` file:
      ```
      ENABLE_OAUTH=false
      ```

3. If you want to continue using Casdoor, ensure these environment variables are properly set in your `.env` file:
   ```
   # Basic Casdoor config
   ENABLE_OAUTH=true
   CASDOOR_ENDPOINT=https://casdoor.hanthel.com
   CASDOOR_CLIENT_ID=your-client-id
   CASDOOR_CLIENT_SECRET=your-client-secret
   CASDOOR_ORGANIZATION_NAME=your-org-name
   CASDOOR_APPLICATION_NAME=your-app-name
   ```

4. Restart your containers:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Troubleshooting

If you continue to have issues with Casdoor:

1. Check if there are network issues between the LobeChat container and your Casdoor server
   
2. Verify that your Casdoor server's SSL certificate is valid (if using HTTPS)
   
3. Check your Casdoor server logs for any authentication or connection issues
   
4. Ensure your Casdoor application is properly configured to work with LobeChat

5. If all else fails, you can temporarily disable Casdoor authentication to use LobeChat with local authentication.

### Container Network Configuration

If your Casdoor server is running on the same host as LobeChat, you might need to use the host's IP address or a proper network configuration in Docker to allow the containers to communicate with each other. 