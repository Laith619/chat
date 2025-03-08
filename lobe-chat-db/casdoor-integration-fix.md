# Casdoor Integration Fix Documentation

## Original Issues

We encountered several issues when trying to integrate Casdoor authentication with our LobeChat deployment:

1. **JavaScript Error in Login Page**: 
   ```
   TypeError: Cannot read properties of null (reading 'length')
   at n.value (LoginPage.js:560:21)
   ```

2. **OIDC Configuration Mismatch**: 
   ```
   [auth][error] r3: "response" body "issuer" property does not match the expected value
   ```

3. **Network/Connection Issues**: Docker container networking problems, especially with service discovery

4. **Database Initialization**: Casdoor not properly initializing with our init_data.json

## Attempted Solutions

### Attempt 1: Email Authentication (Failed)

We attempted to use NextAuth's email provider with SMTP settings:

```
# SMTP Settings for Email Authentication
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=laith.hanthel@gmail.com
SMTP_PASSWORD=istg vghc kxco tela  # Gmail App Password
SMTP_FROM=laith.hanthel@gmail.com
```

**Result**: Email provider not supported by LobeChat database version
```
Error: [NextAuth] provider email is not supported
```

### Attempt 2: Client Mode (Worked but Limited)

We reverted to client mode without authentication:

```
NEXT_PUBLIC_SERVICE_MODE=client
# NEXT_PUBLIC_ENABLE_NEXT_AUTH=1
# NEXT_AUTH_SSO_PROVIDERS=casdoor
```

**Result**: Basic chat functionality worked, but file management and knowledge base features were unavailable with the warning:
```
The current deployment mode does not support file management
```

### Attempt 3: Specific Casdoor Version (In Progress)

We're trying a specific older version of Casdoor that might not have the JavaScript bug:

```yaml
casdoor:
  image: casbin/casdoor:v1.399.0
  # ...other configuration remains the same
```

### Attempt 4: Credentials Provider (In Progress)

We're also testing with the credentials provider instead of Casdoor:

```
# Enable NextAuth for authentication
NEXT_PUBLIC_ENABLE_NEXT_AUTH=1
# Try credentials provider as alternative to Casdoor
NEXT_AUTH_SSO_PROVIDERS=credentials
```

These last two attempts are being tested simultaneously as our next approach.

## Current Fix Approach

Based on our analysis, we're implementing the following fixes:

### 1. Environment Configuration

We've properly aligned all environment variables to ensure consistency:

```
# Casdoor Authentication Settings
AUTH_CASDOOR_ISSUER=http://localhost:8000
AUTH_CASDOOR_ID=943e627d79d5dd8a22a1
AUTH_CASDOOR_SECRET=6ec24ac304e92e160ef0d0656ecd86de8cb563f1
AUTH_CASDOOR_ENDPOINT=http://casdoor:8000
```

### 2. Casdoor Initialization

We've enhanced Casdoor initialization with:
- Explicit init data path: `--initDataPath=/init_data.json`
- Additional configuration parameters:
  ```
  CASDOOR_JDBC_CONNECTION_STRING: 'user=postgres password=${POSTGRES_PASSWORD} host=postgresql port=5432 sslmode=disable dbname=casdoor'
  CASDOOR_LOGS_DIR: '/var/lib/casdoor/logs'
  CASDOOR_SESSION_TIMEOUT: '72h'
  CASDOOR_FRONTEND_BASE_URL: 'http://localhost:8000'
  ```
- Health check to ensure Casdoor is properly initialized before LobeChat starts

### 3. Network Configuration

We've improved network configuration to ensure proper service discovery:
- Using consistent `network_mode: 'service:network-service'` for key services
- Properly exposing all necessary ports

### 4. Enhanced LobeChat Startup

We've added better startup logic to LobeChat:
- Waiting for Casdoor to be ready and checking its OIDC configuration
- Printing debug information for troubleshooting
- Properly setting Casdoor endpoint and issuer URLs

### 5. Consistent OIDC Configuration

We've ensured OIDC configuration consistency by:
- Setting `origin` and `serverUrl` to the same value in Casdoor
- Matching AUTH_CASDOOR_ISSUER with the value in /.well-known/openid-configuration
- Verifying redirect URIs in init_data.json match LobeChat's callback URL

## Test Results

### Test Date: March 6, 2025

1. **Service Initialization**:
   - PostgreSQL: ✅ Started successfully
   - Casdoor: ✅ Started successfully, but with frontend issues
   - LobeChat: ✅ Started and redirecting to Casdoor correctly

2. **Authentication Flow**:
   - OIDC Configuration: ✅ Looks correct, issuer matches expectations
   - Login Page Loading: ❌ Casdoor login page fails with JavaScript error
   - Credentials Submission: ❌ Unable to test due to login page error
   - Redirect Flow: ❌ Unable to test due to login page error

3. **Feature Verification**:
   - Chat Functionality: ✅ Basic chat works (in client mode)
   - File Management: ❌ Unable to test due to authentication failure
   - Knowledge Base: ❌ Unable to test due to authentication failure

### Persistent JavaScript Error

We're still encountering the same JavaScript error in the Casdoor login page:

```
TypeError: Cannot read properties of null (reading 'length')
    at n.value (LoginPage.js:560:21)
    at LoginPage.js:847:61
    at Array.map (<anonymous>)
    at n.value (LoginPage.js:847:38)
    at n.value (LoginPage.js:1152:17)
    at n.value (LoginPage.js:1276:24)
```

This suggests an issue with the compiled Casdoor frontend code rather than a configuration problem. The OIDC configuration and redirect handling appear to be working correctly, but the Casdoor UI itself has a JavaScript bug.

## Debugging Tips

If issues persist, try:

1. **Check Casdoor Logs**:
   ```bash
   docker-compose logs casdoor
   ```

2. **Verify OIDC Configuration**:
   ```bash
   curl http://localhost:8000/.well-known/openid-configuration
   ```

3. **Check LobeChat Authentication Errors**:
   ```bash
   docker-compose logs lobe | grep -i "auth\|authentication\|unauthorized"
   ```

4. **Browser Debug Tools**:
   - Open Developer Tools (F12)
   - Check Network tab for OIDC requests
   - Check Console for JavaScript errors
   - Review Application tab for cookies and session storage

## Next Steps for Ongoing Issues

Since the core issue appears to be with the Casdoor frontend code rather than our configuration, we have a few options:

1. **Try a Specific Version of Casdoor**:
   ```yaml
   casdoor:
     image: casbin/casdoor:v1.399.0  # Try an older or newer specific version
   ```

2. **Build a Custom Casdoor Image**:
   - Clone the Casdoor repository
   - Fix the JavaScript issue in the login page
   - Build a custom Docker image

3. **Use an Alternative Authentication Provider**:
   - `NEXT_AUTH_SSO_PROVIDERS=github` (requires GitHub OAuth credentials)
   - `NEXT_AUTH_SSO_PROVIDERS=google` (requires Google OAuth credentials)
   - `NEXT_AUTH_SSO_PROVIDERS=credentials` (username/password authentication)

4. **Report Issue to Casdoor and LobeChat**:
   - Create detailed issue reports with the specific error information
   - Ask about known compatibility issues between specific versions

5. **Continue Using Client Mode** temporarily until a stable authentication solution is found:
   ```
   NEXT_PUBLIC_SERVICE_MODE=client
   # NEXT_PUBLIC_ENABLE_NEXT_AUTH=1
   # NEXT_AUTH_SSO_PROVIDERS=casdoor
   ```

### Current Implementation Status

Based on further investigation, we identified a critical initialization error in Casdoor that's related to database schema issues:

```
[xorm] [warn] Table plan has column period but struct has not related field
panic: runtime error: invalid memory address or nil pointer dereference
[signal SIGSEGV: segmentation violation code=0x1 addr=0x80 pc=0x5e8b20]
```

This error occurs in the xorm database adapter during initialization, specifically when trying to sync the database schema. It suggests a mismatch between the database schema and the expected struct in the code.

#### Latest Fix Implementation (March 6, 2025, 3:14 PM)

We've implemented a fix inspired by the PR #6714 in the LobeChat repository ("🐛 fix: Casdoor re-init in on-click deployment"). Our solution:

1. **Improved Casdoor Initialization**: Modified the Casdoor startup process to handle database initialization more gracefully:
   ```yaml
   command: >
     /bin/sh -c "
       mkdir -p /var/lib/casdoor/logs
       # First try to run without the database creation to avoid the nil pointer error
       ./server --initDataPath=/init_data.json || (
         # If that fails, try with database creation
         echo 'Initial run failed, trying with database creation...'
         ./server --createDatabase=true --initDataPath=/init_data.json
       )
     "
   ```

2. **Using a Stable Version**: We're using Casdoor v1.399.0 which should provide better compatibility than the latest version (v1.855.0) that might have schema changes

This approach aims to solve the nil pointer dereference error by ensuring proper initialization order and using a more stable version of Casdoor.

### Remaining Concerns

If this approach doesn't work, we might need to:
1. Reset the Casdoor database completely to ensure a clean schema
2. Apply schema changes manually to align with the expected structure
3. Create a custom Docker image with patches to fix the database initialization

## Updated Solution After New Error Analysis (March 6, 2025, 3:30 PM)

After reviewing the detailed error logs, we've identified that the issue is more specific than originally thought. The nil pointer dereference is occurring in the xorm adapter's `createTable` method because the database engine initialization is failing.

### New Error Analysis

The error logs reveal several key issues:
1. Multiple schema mismatches between the database tables and Casdoor's internal structs
2. Critical error in `github.com/xorm-io/xorm.(*Engine).Sync2` passing a nil pointer
3. Failure in the Casbin adapter initialization process

### Enhanced Solution Approach

#### 1. Complete Database Reset

The most reliable solution appears to be starting with a completely fresh database:

```yaml
casdoor:
  # ... other settings ...
  environment:
    # Force a clean database creation
    CASDOOR_CREATE_DATABASE: 'true'
    CASDOOR_DROP_AND_CREATE_DATABASE: 'true'  # This will completely reset the database
  command: >
    /bin/sh -c "
      mkdir -p /var/lib/casdoor/logs
      echo 'Starting with clean database...'
      ./server --createDatabase=true --dropDatabase=true --initDataPath=/init_data.json
    "
```

#### 2. Version Compatibility Fix

We need to ensure complete compatibility between all components:

1. **Downgrade to a Compatible Version Set**:
   ```yaml
   casdoor:
     image: casbin/casdoor:v1.344.0  # An even older known-stable version
   ```

2. **Specify Exact xorm-adapter Version**:
   Create a custom Dockerfile for Casdoor that pins specific dependency versions:
   ```dockerfile
   FROM casbin/casdoor:v1.344.0
   
   # Force specific versions of problematic dependencies
   RUN go get github.com/xorm-io/xorm@v1.0.7
   RUN go get github.com/casdoor/xorm-adapter/v3@v3.0.1
   
   # Rebuild with pinned dependencies
   RUN go build -o server
   ```

#### 3. Alternative Authentication Method

If Casdoor continues to present issues, we should consider switching to a more stable authentication provider:

```
# Use a more stable authentication provider
NEXT_PUBLIC_ENABLE_NEXT_AUTH=1
NEXT_AUTH_SSO_PROVIDERS=credentials

# Or consider GitHub authentication if available
# NEXT_AUTH_SSO_PROVIDERS=github
# AUTH_GITHUB_ID=your_github_client_id
# AUTH_GITHUB_SECRET=your_github_client_secret
```

#### 4. Database Initialization Debugging

Add additional debug logging to understand the exact state of the database during initialization:

```yaml
casdoor:
  # ... other settings ...
  command: >
    /bin/sh -c "
      mkdir -p /var/lib/casdoor/logs
      echo 'Checking database connection...'
      # Use PostgreSQL client to verify connection and schema
      PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgresql -U postgres -d casdoor -c 'SELECT current_database(), current_user, version();'
      # Then start Casdoor with verbose logging
      ./server --createDatabase=true --dropDatabase=true --initDataPath=/init_data.json --debug=true
    "
```

#### 5. Database Pre-initialization

Create a separate initialization container that properly prepares the database schema before Casdoor tries to use it:

```yaml
services:
  casdoor-db-init:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    command: >
      /bin/bash -c "
        until PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgresql -U postgres -c 'SELECT 1'; do
          echo 'Waiting for PostgreSQL to start...'
          sleep 2
        done
        echo 'Creating Casdoor database and schema...'
        PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgresql -U postgres -c 'DROP DATABASE IF EXISTS casdoor;'
        PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgresql -U postgres -c 'CREATE DATABASE casdoor;'
        # Import a known-good schema dump if available
        # PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgresql -U postgres -d casdoor -f /casdoor-schema.sql
      "
    depends_on:
      - postgresql
    network_mode: 'service:network-service'
```

We'll prioritize implementing these solutions in the given order, starting with the complete database reset approach.

## Latest Progress Update (March 6, 2025, 4:20 PM)

We've made progress with the Casdoor integration, but have encountered a disk space issue. Here's the current status:

### Components Status:
1. **Casdoor Service**: ⚠️ Service starts but fails with disk space errors
2. **Login Page**: ❌ OIDC configuration returning 503 errors
3. **LobeChat**: ⚠️ Service starts but can't connect to Casdoor
4. **Database Connection**: ✅ Database initialized with required structure

### Current Error:
We're encountering a disk space error in Casdoor:

```
[SESSION]mkdir tmp/7: no space left on device
2025-03-06 16:17:09.742 [E]  invalid argument
2025-03-06 16:17:09.747 [D]  |      127.0.0.1| 503 |      7.698ms| nomatch| GET      /.well-known/openid-configuration
```

This error indicates that there's not enough disk space available for Casdoor to create temporary directories needed for session management. This is causing the OIDC endpoints to fail, which in turn prevents the authentication flow from working.

### Potential Solutions:

#### 1. Free up disk space
Run the following commands to clean up Docker resources and free disk space:

```bash
# Remove unused Docker resources
docker system prune -a

# Check disk space
df -h

# Check for large files in the project directory
du -h --max-depth=1 ./lobe-chat-db
```

#### 2. Use a volume for temporary storage
Update the docker-compose.yml to mount a host directory for temporary storage:

```yaml
casdoor:
  # ... existing config ...
  volumes:
    - ./init_data.json:/init_data.json
    - ./casdoor-data:/var/lib/casdoor
    - ./casdoor-tmp:/tmp  # Add this line to provide external tmp storage
```

#### 3. Modify Casdoor's temp directory
Change the Casdoor command to use a different temp directory:

```yaml
command: >
  /bin/sh -c "
    mkdir -p /var/lib/casdoor/logs
    mkdir -p /var/lib/casdoor/tmp
    export TMPDIR=/var/lib/casdoor/tmp
    echo 'Starting Casdoor with clean database...'
    ./server --createDatabase=true --dropDatabase=true --initDataPath=/init_data.json
  "
```

### Implementation Updates:
1. **Platform Compatibility**: Using AMD64 emulation for ARM platforms
2. **Version Selection**: Using Casdoor v1.399.0 for PostgreSQL compatibility
3. **SQL Syntax Error**: Fixed by upgrading from v1.115.0
4. **Disk Space**: Needs resolution before authentication can work

### Next Steps:
1. Address disk space issue using one of the solutions above
2. Restart services and verify OIDC configuration endpoints are accessible
3. Test login with admin credentials:
   - Username: admin@example.com
   - Password: 123456
4. Verify proper redirect back to LobeChat after login

### Other Issues:
The SearxNG errors about the secret key and worker processes remain non-critical and don't affect the core Casdoor integration.
