#!/bin/bash

# Fix PostgreSQL - Complete Version
# This script addresses the missing directory issues in PostgreSQL container

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}LobeChat PostgreSQL Complete Fix${NC}"
echo "==========================="

# 1. Stop all containers
echo -e "\n${BLUE}1. Stopping all containers...${NC}"
docker-compose down
echo -e "${GREEN}✓ All containers stopped.${NC}"

# 2. Check data directory permissions
echo -e "\n${BLUE}2. Checking data directory...${NC}"
if [ -d "data" ]; then
  echo -e "${GREEN}✓ Data directory exists.${NC}"
  
  # Make a backup of the data directory
  echo -e "${YELLOW}Creating backup of PostgreSQL data...${NC}"
  if [ -d "data_backup" ]; then
    echo -e "${YELLOW}Removing old backup...${NC}"
    rm -rf data_backup
  fi
  
  cp -r data data_backup
  echo -e "${GREEN}✓ Data backup created in data_backup directory.${NC}"
  
  # Fix permissions on the data directory
  echo -e "${YELLOW}Fixing data directory permissions...${NC}"
  chmod -R 700 data
  echo -e "${GREEN}✓ Permissions fixed on data directory.${NC}"
  
  # Create all required PostgreSQL directories
  echo -e "${YELLOW}Creating required PostgreSQL directories...${NC}"
  mkdir -p data/pg_notify data/pg_replslot data/pg_tblspc data/pg_twophase data/pg_snapshots data/pg_logical/snapshots data/pg_logical/mappings data/pg_commit_ts
  chmod 700 data/pg_notify data/pg_replslot data/pg_tblspc data/pg_twophase data/pg_snapshots data/pg_logical/snapshots data/pg_logical/mappings data/pg_commit_ts
  echo -e "${GREEN}✓ Created required PostgreSQL directories.${NC}"
else
  echo -e "${RED}✗ Data directory not found.${NC}"
  echo -e "${YELLOW}Creating new data directory...${NC}"
  mkdir -p data
  chmod 700 data
  echo -e "${GREEN}✓ Created new data directory.${NC}"
  echo -e "${YELLOW}Note: A new database will be initialized. You will lose all previous data.${NC}"
fi

# 3. Start PostgreSQL with a special run command
echo -e "\n${BLUE}3. Starting PostgreSQL with fixed configuration...${NC}"

# Create a temporary docker-compose file for the database
cat > docker-compose.pg-only.yml << EOF
name: lobe-chat-database-pgfix
services:
  postgresql:
    image: pgvector/pgvector:pg17
    container_name: lobe-postgres
    ports:
      - '5433:5432'
    volumes:
      - './data:/var/lib/postgresql/data'
    environment:
      - 'POSTGRES_DB=${LOBE_DB_NAME:-lobechat}'
      - 'POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-securepassword123}'
      - 'POSTGRES_USER=postgres'
    command: postgres -c 'max_connections=100' -c 'shared_buffers=128MB'
    restart: always
    networks:
      - lobe-network

networks:
  lobe-network:
    driver: bridge
EOF

echo -e "${YELLOW}Starting PostgreSQL container only...${NC}"
docker-compose -f docker-compose.pg-only.yml up -d

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
for i in {1..30}; do
  if docker-compose -f docker-compose.pg-only.yml exec postgresql pg_isready -U postgres &> /dev/null; then
    echo -e "${GREEN}✓ PostgreSQL is now ready!${NC}"
    DB_READY=true
    break
  else
    echo -e "${YELLOW}Waiting for PostgreSQL to be ready... (attempt $i/30)${NC}"
    sleep 2
  fi
done

if [ "$DB_READY" != "true" ]; then
  echo -e "${RED}✗ PostgreSQL failed to start within the timeout period.${NC}"
  echo -e "${YELLOW}Checking container logs...${NC}"
  docker-compose -f docker-compose.pg-only.yml logs postgresql
  
  echo -e "${RED}There appears to be a persistent issue with the PostgreSQL container.${NC}"
  echo -e "${YELLOW}Would you like to completely reset the database? This will delete all data. (y/n)${NC}"
  read -p "" reset_db
  
  if [[ $reset_db =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Stopping PostgreSQL container...${NC}"
    docker-compose -f docker-compose.pg-only.yml down
    
    echo -e "${YELLOW}Removing data directory...${NC}"
    rm -rf data
    mkdir -p data/pg_notify data/pg_replslot data/pg_tblspc data/pg_twophase data/pg_snapshots data/pg_logical/snapshots data/pg_logical/mappings data/pg_commit_ts
    chmod 700 data data/pg_notify data/pg_replslot data/pg_tblspc data/pg_twophase data/pg_snapshots data/pg_logical/snapshots data/pg_logical/mappings data/pg_commit_ts
    
    echo -e "${YELLOW}Starting PostgreSQL with clean database...${NC}"
    docker-compose -f docker-compose.pg-only.yml up -d
    
    echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
    for i in {1..30}; do
      if docker-compose -f docker-compose.pg-only.yml exec postgresql pg_isready -U postgres &> /dev/null; then
        echo -e "${GREEN}✓ PostgreSQL is now ready with a fresh database!${NC}"
        break
      else
        echo -e "${YELLOW}Waiting for PostgreSQL to be ready... (attempt $i/30)${NC}"
        sleep 2
      fi
    done
  else
    echo -e "${YELLOW}Operation cancelled.${NC}"
    echo -e "${RED}PostgreSQL issues remain unresolved.${NC}"
    exit 1
  fi
fi

# 4. Initialize the database if needed
echo -e "\n${BLUE}4. Checking database schema...${NC}"
DB_NAME=${LOBE_DB_NAME:-lobechat}

# Check if our database exists
if docker-compose -f docker-compose.pg-only.yml exec postgresql psql -U postgres -lqt | grep -q $DB_NAME; then
  echo -e "${GREEN}✓ Database '$DB_NAME' exists.${NC}"
else
  echo -e "${YELLOW}Creating database '$DB_NAME'...${NC}"
  docker-compose -f docker-compose.pg-only.yml exec postgresql psql -U postgres -c "CREATE DATABASE $DB_NAME OWNER postgres;"
  echo -e "${GREEN}✓ Database created.${NC}"
fi

# Check for pgvector extension
PGVECTOR_CHECK=$(docker-compose -f docker-compose.pg-only.yml exec postgresql psql -U postgres -d $DB_NAME -c "SELECT * FROM pg_extension WHERE extname = 'vector';" -t | wc -l)

if [ "$PGVECTOR_CHECK" -gt 0 ]; then
  echo -e "${GREEN}✓ PGVector extension is installed.${NC}"
else
  echo -e "${YELLOW}Installing PGVector extension...${NC}"
  docker-compose -f docker-compose.pg-only.yml exec postgresql psql -U postgres -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;"
  echo -e "${GREEN}✓ PGVector extension installed.${NC}"
fi

# 5. Stop PostgreSQL and start full stack
echo -e "\n${BLUE}5. Stopping PostgreSQL standalone container...${NC}"
docker-compose -f docker-compose.pg-only.yml down
echo -e "${GREEN}✓ PostgreSQL container stopped.${NC}"

echo -e "\n${BLUE}6. Starting full application stack...${NC}"
docker-compose up -d

echo -e "${GREEN}PostgreSQL fix applied successfully!${NC}"
echo -e "All services should now be running properly."
echo -e "If you continue to experience issues:"
echo -e "1. Try running: ${YELLOW}docker-compose logs -f postgresql${NC}"
echo -e "2. You may need to recreate the database: ${YELLOW}rm -rf data/*${NC} then restart"
echo -e "3. Check if your disk has enough space and proper permissions" 