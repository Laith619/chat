# LobeChat Server Deployment with External Casdoor

This repository contains configuration and tools for deploying LobeChat with PostgreSQL database, MinIO storage, and external Casdoor authentication.

## Overview

This setup provides a fully functional LobeChat instance with:

- **PostgreSQL Database** with PGVector for storing chat data and embeddings
- **MinIO Storage** for file uploads and knowledge base documents
- **External Casdoor Authentication** for user management
- **RAG Capabilities** with knowledge base functionality

## Architecture

The system uses a Docker Compose setup with the following components:

- **LobeChat**: Main application
- **PostgreSQL**: Database with vector search capabilities
- **MinIO**: S3-compatible storage service
- **External Casdoor**: Authentication service (hosted at https://casdoor.hanthel.com)

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Access to the external Casdoor instance

### Quick Start

1. **Start all services**:
   ```bash
   ./reset-lobe-with-external-casdoor.sh
   ```

2. **Test authentication connectivity**:
   ```bash
   ./test-auth-endpoints.sh
   ```

3. **Set up test files for the knowledge base**:
   ```bash
   ./setup-knowledge-base.sh
   ```

4. **Verify knowledge base functionality**:
   ```bash
   ./test-knowledge-base.sh
   ```

5. **Access LobeChat**:
   Open http://localhost:3210 in your browser

### Authentication

This setup uses an external Casdoor instance for authentication:

- **Casdoor URL**: https://casdoor.hanthel.com
- **Login Process**: When you click "Sign In" in LobeChat, you'll be redirected to the Casdoor login page
- **User Management**: All user accounts are managed through the Casdoor admin panel

### Knowledge Base Feature

The knowledge base functionality allows you to:

1. Upload documents (PDF, TXT, Markdown, HTML)
2. Have them automatically processed and embedded
3. Use their content to enhance AI responses

For detailed instructions on using the knowledge base:
- See `knowledge-base-guide.md`
- Run `./setup-knowledge-base.sh` to create test files
- Run `./test-knowledge-base.sh` to verify functionality

## Utility Scripts

This repository includes several scripts to help with setup and testing:

- `reset-lobe-with-external-casdoor.sh`: Reset and restart services
- `test-auth-endpoints.sh`: Test authentication connectivity
- `setup-knowledge-base.sh`: Create test files for knowledge base
- `test-knowledge-base.sh`: Verify knowledge base functionality

## Configuration Files

- `.env`: Environment variables for all services
- `docker-compose.yml`: Service definitions and configuration
- `init_data.json`: Initial data configuration (not used with external Casdoor)

## Documentation

- `lobe-chat-implementation-guide-updated.md`: Comprehensive implementation guide
- `casdoor-auth-fix-readme.md`: Details on the external Casdoor integration
- `knowledge-base-guide.md`: Instructions for using the knowledge base feature

## Troubleshooting

### Authentication Issues

1. **Cannot log in**: 
   - Verify the external Casdoor server is accessible
   - Check authentication configuration in `.env`
   - Clear browser cookies and try again
   - Use `test-auth-endpoints.sh` to verify connectivity

2. **"Invalid client_id" error**:
   - Verify that client ID and secret match between LobeChat and Casdoor
   - Check Casdoor application configuration for correct redirect URI

### Knowledge Base Issues

1. **Cannot upload files**:
   - Check MinIO is running: `docker-compose ps`
   - Verify MinIO bucket configuration
   - Check MinIO logs: `docker-compose logs minio`

2. **Embedding generation fails**:
   - Verify your OpenAI API key is valid
   - Check OpenAI API access in LobeChat logs: `docker-compose logs lobe`

3. **File processing stalls**:
   - Check disk space and system resources
   - Restart the LobeChat container: `docker-compose restart lobe`

## Maintenance

### Backups

Regularly backup:
1. PostgreSQL database
2. MinIO storage
3. Configuration files

### Updates

To update services:
1. Pull latest changes: `git pull`
2. Rebuild images: `docker-compose build`
3. Restart services: `docker-compose down && docker-compose up -d`

## Security Considerations

1. In production, change all default passwords
2. Implement HTTPS for all services
3. Restrict access to admin interfaces
4. Regularly update all components

## Next Steps

- [ ] Implement HTTPS for production
- [ ] Set up automated backups
- [ ] Configure additional AI models
- [ ] Optimize performance settings
