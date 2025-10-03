#!/bin/bash

echo "=== Event Booking Database Project ==="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DB_NAME="event_booking"

# Start PostgreSQL
echo "1. Starting PostgreSQL..."
sudo service postgresql start
sleep 2

# Create database
echo "2. Creating database '$DB_NAME'..."
sudo -u postgres createdb $DB_NAME 2>/dev/null && echo -e "${GREEN}✓ Database created${NC}" || echo -e "${YELLOW}Database might already exist${NC}"

# Function to execute SQL file
execute_sql() {
    local file=$1
    local description=$2
    
    echo -e "${YELLOW}Executing: $description...${NC}"
    if sudo -u postgres psql -d $DB_NAME -f "$file" 2>/dev/null; then
        echo -e "${GREEN}✓ Success: $description${NC}"
    else
        echo -e "${RED}✗ Error in: $description${NC}"
        return 1
    fi
}

# Step 1: Create database schema
execute_sql "01_database_setup.sql" "Database schema creation"

# Step 2: Create CRUD operations
execute_sql "02_crud_operations.sql" "CRUD operations"

# Step 3: Check if tables were created
echo "3. Checking created tables..."
sudo -u postgres psql -d $DB_NAME -c "\dt"

# Step 4: Ask about data generation
echo ""
echo -e "${YELLOW}4. Data Generation Options:${NC}"
echo "   1) Minimal test data (fast)"
echo "   2) Full dataset with 3M+ records (slow)"
echo "   3) Skip data generation"
read -p "Choose option (1/2/3): " data_option

case $data_option in
    1)
        echo "Generating minimal test data..."
        execute_sql "04_minimal_data.sql" "Minimal test data"
        ;;
    2)
        echo -e "${YELLOW}Generating full dataset (3M+ records)...${NC}"
        echo -e "${RED}This will take significant time and resources!${NC}"
        read -p "Are you sure? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            execute_sql "04_full_data_generation.sql" "Full data generation"
        else
            echo "Skipping full data generation"
        fi
        ;;
    *)
        echo "Skipping data generation"
        ;;
esac

# Step 5: Create business queries and indexes
execute_sql "03_business_queries.sql" "Business queries"
execute_sql "05_indexes_optimization.sql" "Indexes and optimization"

# Final check
echo "5. Final database status:"
sudo -u postgres psql -d $DB_NAME -c "
SELECT 
    schemaname,
    relname,
    n_live_tup as row_count
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC;
"

echo -e "${GREEN}=== Project Setup Completed! ===${NC}"
echo ""
echo "To connect to the database:"
echo "  sudo -u postgres psql -d $DB_NAME"
echo ""
echo "Sample commands:"
echo "  SELECT COUNT(*) FROM bookings;"
echo "  SELECT * FROM users LIMIT 5;"