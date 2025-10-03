#!/bin/bash

echo "=== Simple Backup & Restore for WSL ==="

DB_NAME="event_booking"
BACKUP_FILE="event_booking_backup.sql"

echo "1. Creating backup using pg_dump with sudo..."
sudo -u postgres pg_dump $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "✅ Backup created: $BACKUP_FILE"
    echo "📦 Backup size: $(du -h $BACKUP_FILE | cut -f1)"
else
    echo "❌ Backup failed"
    exit 1
fi

echo ""
echo "2. Dropping database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null

echo ""
echo "3. Creating new database..."
sudo -u postgres createdb $DB_NAME

echo ""
echo "4. Restoring from backup..."
sudo -u postgres psql -d $DB_NAME -f $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "✅ Restore completed successfully"
else
    echo "❌ Restore failed"
    exit 1
fi

echo ""
echo "5. Verification..."
sudo -u postgres psql -d $DB_NAME -c "
SELECT 
    table_name,
    (xpath('/row/cnt/text()', query_to_xml(format('SELECT COUNT(*) as cnt FROM %I', table_name), false, true, '')))[1]::text::int as row_count
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY row_count DESC;"

echo ""
echo "=== COMPLETED ==="