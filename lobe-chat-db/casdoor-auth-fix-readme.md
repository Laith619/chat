# LobeChat with External Casdoor Authentication

This document explains how to use an external Casdoor server with LobeChat for authentication.

## Configuration Overview

We've configured LobeChat to use an external Casdoor server instead of running Casdoor locally. This provides several benefits:

1. **Centralized Authentication**: Use one Casdoor instance for multiple applications
2. **Improved Stability**: Separate authentication from your main application
3. **Better Security**: Isolated authentication service with its own security measures
4. **Easier Maintenance**: Update authentication without affecting the main application

## Applied Changes

### 1. External Casdoor Integration

- Removed local Casdoor container from docker-compose.yml
- Updated environment variables to point to the external Casdoor server:
  ```
  AUTH_CASDOOR_ISSUER=https://casdoor.hanthel.com
  AUTH_CASDOOR_ID=d861ef0c326a57eeb642
  AUTH_CASDOOR_SECRET=cdc5739bb525b67143108b532bad992127008b9e
  AUTH_CASDOOR_ENDPOINT=https://casdoor.hanthel.com
  ```

### 2. Updated Container Dependencies

- Modified LobeChat container to check external Casdoor connectivity
- Removed dependencies on local Casdoor service
- Enhanced startup script to verify external Casdoor accessibility

### 3. Enhanced Tools

- Created new reset script (`reset-lobe-with-external-casdoor.sh`) that works with external Casdoor
- Updated test script to verify connectivity with external Casdoor server
- Improved logging and error handling for authentication issues

## How to Apply the Configuration

1. Ensure you have the updated files:
   - `.env` - Contains external Casdoor configuration
   - `docker-compose.yml` - Updated without Casdoor service
   - `reset-lobe-with-external-casdoor.sh` - Script to reset and restart services

2. Configure your external Casdoor server:
   - Register LobeChat as an application in Casdoor
   - Set the redirect URI to `http://localhost:3210/api/auth/callback/casdoor`
   - Copy the client ID and secret to your `.env` file

3. Run the reset script to apply all changes:
   ```bash
   ./reset-lobe-with-external-casdoor.sh
   ```

4. The script will:
   - Stop all containers
   - Check connectivity to your external Casdoor server
   - Reset the LobeChat database (optional)
   - Start all services in the correct order

## Testing & Troubleshooting Tools

- Use `test-auth-endpoints.sh` to verify your setup:
  - Tests connectivity to external Casdoor
  - Verifies OIDC configuration
  - Checks LobeChat authentication endpoints
  - Generates a test OAuth URL for manual verification

## Troubleshooting

### Issue: "invalid client_id" error

1. **Clear browser cookies and cache**
   - Try using an incognito/private browsing window
   - Previous authentication cookies might interfere with the new configuration

2. **Verify OIDC configuration**
   ```bash
   curl https://casdoor.hanthel.com/.well-known/openid-configuration
   ```
   - Confirm the issuer matches your Casdoor URL
   - Verify the authorization_endpoint and token_endpoint URLs

3. **Check Casdoor logs**
   ```bash
   # Access your external Casdoor server logs
   # This depends on how you've deployed Casdoor
   ```
   - Look for any error messages related to OAuth authentication

4. **Review LobeChat logs**
   ```bash
   docker-compose logs -f lobe
   ```
   - Check for authentication flow messages (prefixed with `[Auth]`)

### Issue: Connection to external Casdoor fails

1. **Check network connectivity**
   ```bash
   curl -I https://casdoor.hanthel.com
   ```
   - Verify your Docker containers can reach the external Casdoor server

2. **Verify DNS resolution**
   ```bash
   nslookup casdoor.hanthel.com
   ```
   - Ensure domain name resolves correctly

3. **Check SSL/TLS certificates**
   - Ensure certificates are valid and trusted
   - Add the `-k` flag to curl commands if using self-signed certificates for testing

## Technical Details

### Network Architecture

- LobeChat and other services run in Docker containers with local networking
- Casdoor runs externally (either self-hosted or as a service)
- Communication happens over HTTPS for security

### Authentication Flow

1. User accesses LobeChat at `http://localhost:3210`
2. LobeChat redirects to external Casdoor at `https://casdoor.hanthel.com/login/oauth/authorize`
3. After successful login, Casdoor redirects back to LobeChat's callback URL
4. LobeChat exchanges the authorization code for an access token
5. User is authenticated and can access all features

### Environment Variables

Key environment variables for authentication:
- `AUTH_CASDOOR_ID`: Client ID registered in Casdoor
- `AUTH_CASDOOR_SECRET`: Client secret for authentication
- `AUTH_CASDOOR_ISSUER`: URL of external Casdoor server
- `AUTH_CASDOOR_ENDPOINT`: Same as ISSUER for external deployment

## Additional Resources

- [Casdoor Documentation](https://casdoor.org/docs/overview)
- [NextAuth.js OAuth Provider Guide](https://next-auth.js.org/providers/oauth)
- [LobeChat Database Deployment Guide](https://github.com/lobehub/lobe-chat-database)
