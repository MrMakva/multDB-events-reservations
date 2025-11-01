#!/bin/bash

echo "=== STARTING WORKLOAD (FIXED) ==="

if ! pgrep -x postgres > /dev/null; then
    echo "PostgreSQL is not running!"
    echo "Run: sudo service postgresql start"
    exit 1
fi

echo "Checking database accessibility..."
if ! sudo -u postgres psql -d crash_test -c "SELECT 1;" &>/dev/null; then
    echo "Database crash_test not accessible!"
    echo "Run './prepare_fixed.sh' first"
    exit 1
fi

echo "Database is accessible"
echo "Starting workload..."
echo "Press Ctrl+C to stop normally"

counter=1
while true; do
    echo "--- Batch $counter ---"

    sudo -u postgres psql -d crash_test -c "
        -- Быстрая коммитированная транзакция
        BEGIN;
        INSERT INTO crash_visible (step, data, lsn) 
        VALUES ('committed_$counter', 'Safe data $counter', pg_current_wal_lsn()::text);
        COMMIT;
    " 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "Connection lost - PostgreSQL was likely killed"
        break
    fi

    sudo -u postgres psql -d crash_test -c "
        BEGIN;
        INSERT INTO crash_visible (step, data, lsn) 
        VALUES ('long_start_$counter', 'Unsafe start $counter', pg_current_wal_lsn()::text);
        
        -- Долгая операция - здесь можно убить
        SELECT pg_sleep(2);
        
        INSERT INTO crash_visible (step, data, lsn) 
        VALUES ('long_end_$counter', 'Unsafe end $counter', pg_current_wal_lsn()::text);
        COMMIT;
    " 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo "Long transaction interrupted - PostgreSQL was killed"
        break
    fi

    if [ $((counter % 5)) -eq 0 ]; then
        echo "Progress: Batch $counter completed"
        sudo -u postgres psql -d crash_test -c "
            SELECT 'Total records:', count(*) FROM crash_visible;
        " 2>/dev/null
    fi
    
    counter=$((counter + 1))
    sleep 1
done

echo "Workload finished"
