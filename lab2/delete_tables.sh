#!/bin/bash

echo "=== Table Management ==="
echo "1. Delete specific table"
echo "2. Delete all tables"
echo "3. Show all tables"
read -p "Choose option (1/2/3): " choice

case $choice in
    1)
        read -p "Enter table name to delete: " table_name
        sudo -u postgres psql -d event_booking -c "DROP TABLE IF EXISTS $table_name CASCADE;"
        echo "Table $table_name deleted"
        ;;
    2)
        echo "Deleting ALL tables..."
        sudo -u postgres psql -d event_booking -c "
        DROP SCHEMA public CASCADE;
        CREATE SCHEMA public;
        GRANT ALL ON SCHEMA public TO postgres;
        GRANT ALL ON SCHEMA public TO public;"
        echo "All tables deleted"
        ;;
    3)
        echo "Current tables:"
        sudo -u postgres psql -d event_booking -c "\dt"
        ;;
    *)
        echo "Invalid option"
        ;;
esac
