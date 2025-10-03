#!/bin/bash

echo "=== WSL PostgreSQL Setup ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Start PostgreSQL service
echo "Starting PostgreSQL service..."
sudo service postgresql start

# Check if PostgreSQL is running
if sudo service postgresql status | grep -q "active (running)"; then
    echo -e "${GREEN}✓ PostgreSQL is running${NC}"
else
    echo -e "${RED}✗ PostgreSQL failed to start${NC}"
    echo "Trying to initialize database cluster..."
    sudo pg_ctlcluster 14 main start  # Замените 14 на вашу версию
fi

# Setup authentication for WSL
echo "Setting up WSL authentication..."
PG_HBA_CONF="/etc/postgresql/*/main/pg_hba.conf"

# Backup original config
sudo cp $PG_HBA_CONF ${PG_HBA_CONF}.backup

# Set trust authentication for local connections
sudo sed -i 's/local.*all.*all.*peer/local   all             all                                     trust/g' $PG_HBA_CONF
sudo sed -i 's/host.*all.*all.*127.0.0.1\/32.*md5/host    all             all             127.0.0.1\/32            trust/g' $PG_HBA_CONF

# Restart to apply changes
sudo service postgresql restart

# Wait for service to be ready
sleep 3

# Test connection as current user
echo "Testing connection..."
if psql -U postgres -c "SELECT version();" 2>/dev/null; then
    echo -e "${GREEN}✓ Connection successful${NC}"
else
    # Try with sudo
    echo "Trying with sudo..."
    sudo -u postgres psql -c "SELECT version();"
fi

echo "WSL setup completed!"