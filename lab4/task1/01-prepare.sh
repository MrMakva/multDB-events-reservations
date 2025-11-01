#!/bin/bash

echo "=== PREPARING CRASH TEST ==="

echo "=== CHECKING POSTGRESQL ==="
if ! pgrep -x postgres > /dev/null && ! pgrep -x postmaster > /dev/null; then
    echo "Starting PostgreSQL..."
    sudo service postgresql start
    sleep 5
fi

if ! sudo -u postgres psql -c "SELECT 1;" &>/dev/null; then
    echo "PostgreSQL is not responding"
    echo "Trying to restart PostgreSQL..."
    sudo service postgresql restart
    sleep 5
fi

echo "=== ENSURING DATABASE EXISTS ==="
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw crash_test; then
    echo "Creating crash_test database..."
    sudo -u postgres createdb crash_test
else
    echo "Database crash_test already exists"
fi

echo "=== CHECKING DATABASE ACCESS ==="
for i in {1..3}; do
    if sudo -u postgres psql -d crash_test -c "SELECT 1;" &>/dev/null; then
        echo "Database access confirmed"
        break
    else
        echo "Attempt $i: Cannot access crash_test database, retrying..."
        sleep 2
        if [ $i -eq 3 ]; then
            echo "All connection attempts failed"
            echo "Debug info:"
            sudo -u postgres psql -l
            sudo service postgresql status
            exit 1
        fi
    fi
done

echo "=== SETUP TEST TABLES ==="
sudo -u postgres psql -d crash_test -c "
    DROP TABLE IF EXISTS crash_visible CASCADE;
    CREATE TABLE crash_visible (
        id SERIAL PRIMARY KEY,
        step VARCHAR(50),
        data TEXT,
        lsn TEXT,
        created_at TIMESTAMP DEFAULT NOW()
    );

    DROP TABLE IF EXISTS wal_monitor CASCADE;
    CREATE TABLE wal_monitor (
        id SERIAL PRIMARY KEY,
        operation TEXT,
        data_state TEXT,
        lsn TEXT,
        event_time TIMESTAMP DEFAULT NOW()
    );

    -- Начальные данные
    INSERT INTO crash_visible (step, data, lsn) 
    VALUES ('initial_setup', 'Database ready for crash test', pg_current_wal_lsn()::text);

    INSERT INTO wal_monitor (operation, data_state, lsn) 
    VALUES ('SETUP COMPLETE', 'Ready for manual crash', pg_current_wal_lsn()::text);
"

echo "Setup completed successfully"

echo ""
echo "=== FINAL CHECK ==="
sudo -u postgres psql -d crash_test -c "
    SELECT 'Database:' as info, current_database();
    SELECT 'Records in crash_visible:', count(*) FROM crash_visible;
    SELECT 'Current WAL LSN:', pg_current_wal_lsn();
"