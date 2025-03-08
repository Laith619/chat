# LobeChat Implementation Guide

## Current Implementation Status

- **Authentication**: Working with external Casdoor at https://casdoor.hanthel.com
- **Database**: Running with PostgreSQL and PGVector for vector search
- **Storage**: Using MinIO for file and knowledge base storage
- **File Upload**: Fixed with CORS configuration
- **Knowledge Base**: Ready for use with proper configuration

## Key Components

1. **Docker Services**:
   - LobeChat API & Frontend
   - PostgreSQL Database with PGVector
   - MinIO S3-compatible Storage
   - SearXNG Search

2. **Authentication**:
   - Using external Casdoor server
   - Login with Casdoor credentials

3. **Storage**:
   - MinIO for file storage
   - S3-compatible API
   - Properly configured CORS for uploads

## How to Use This Implementation

### Starting the Service

The simplest way to start all services with the proper configuration is:

```bash
cd lobe-chat-db
./restart-with-fixes.sh
```

This script will:
1. Stop all running services
2. Apply configuration fixes
3. Start PostgreSQL first
4. Verify Casdoor connectivity
5. Start all other services
6. Apply direct MinIO CORS configuration
7. Check for errors in logs

### Alternative Startup Methods

If you prefer to start the services manually:

```bash
cd lobe-chat-db
docker-compose down
docker-compose up -d
```

If you encounter issues with file uploads or knowledge base:

```bash
cd lobe-chat-db
./fix-minio-cors.sh
```

If you have Casdoor connectivity issues:

```bash
cd lobe-chat-db
./fix-casdoor-connection.sh
```

## System Access

- **LobeChat**: http://localhost:3210
  - Login with your Casdoor credentials

- **MinIO Console**: http://localhost:9001
  - Username: minio_admin
  - Password: minio_password123 (from .env file)

## Using the Knowledge Base

1. **Access Knowledge Base**:
   - Log in to LobeChat
   - Navigate to the Knowledge tab (book icon in sidebar)

2. **Create Knowledge Base**:
   - Click "Create Knowledge Base"
   - Enter a name and description

3. **Upload Documents**:
   - Select the knowledge base
   - Click "Upload Files"
   - Choose files from your computer
   - Supported formats: PDF, TXT, Markdown, HTML, etc.

4. **Use in Conversations**:
   - Start a chat with an assistant
   - Enable the knowledge base icon near the input box
   - Ask questions that reference your uploaded content

## Sample Documents

Sample test documents are available in the `test-files` directory:

```bash
cd lobe-chat-db
ls test-files
```

To create more test files:

```bash
cd lobe-chat-db
./setup-knowledge-base.sh
```

## Troubleshooting

### Authentication Issues

If you have trouble logging in:

1. Check connectivity to Casdoor:
   ```bash
   curl -I https://casdoor.hanthel.com
   ```

2. Verify OIDC configuration:
   ```bash
   curl https://casdoor.hanthel.com/.well-known/openid-configuration
   ```

3. Run the connection diagnostic script:
   ```bash
   ./fix-casdoor-connection.sh
   ```

### File Upload Issues

If you can't upload files:

1. Check MinIO is running:
   ```bash
   docker-compose ps | grep minio
   ```

2. Verify CORS configuration:
   ```bash
   curl -I -X OPTIONS -H "Origin: http://localhost:3210" http://localhost:9000/lobe/
   ```

3. Run the CORS fix script:
   ```bash
   ./fix-minio-cors.sh
   ```

### Database Issues

If you encounter database errors:

1. Check PostgreSQL is running:
   ```bash
   docker-compose ps | grep postgres
   ```

2. Reset the database (warning: this deletes all data):
   ```bash
   ./reset-lobe-with-external-casdoor.sh
   ```

## System Maintenance

### Updating Services

To update to a newer version:

1. Pull the latest changes:
   ```bash
   git pull
   ```

2. Rebuild containers:
   ```bash
   docker-compose build
   ```

3. Restart with fixes:
   ```bash
   ./restart-with-fixes.sh
   ```

### Backup and Restore

To back up your data:

1. Database:
   ```bash
   docker-compose exec postgresql pg_dump -U postgres lobechat > lobechat_backup.sql
   ```

2. MinIO data:
   ```bash
   tar -czf s3_data_backup.tar.gz s3_data/
   ```

To restore:

1. Database:
   ```bash
   cat lobechat_backup.sql | docker-compose exec -T postgresql psql -U postgres lobechat
   ```

2. MinIO data:
   ```bash
   tar -xzf s3_data_backup.tar.gz
   ```

## Security Considerations

This implementation has been configured for local/internal use. For production deployment, consider:

1. Enabling HTTPS for all services
2. Using stronger passwords
3. Implementing network security rules
4. Setting up regular backups
5. Monitoring logs for unusual activity

## Next Steps

To further enhance this implementation:

1. Set up automated backups
2. Configure additional AI models
3. Customize the UI
4. Implement user role management
5. Add monitoring and alerting
