#!/bin/bash

echo "=== POST-CRASH ANALYSIS ==="

if ! pgrep -x postgres > /dev/null; then
    echo "Starting PostgreSQL for recovery..."
    sudo service postgresql start

    for i in {1..15}; do
        if sudo -u postgres psql -c "SELECT 1;" &>/dev/null; then
            echo "PostgreSQL recovered successfully!"
            break
        fi
        echo "Waiting for recovery... ($i/15)"
        sleep 2
    done
fi

if ! sudo -u postgres psql -d crash_test -c "SELECT 1;" &>/dev/null; then
    echo "Database crash_test not accessible after recovery"
    exit 1
fi

echo ""
echo "=== RECOVERY LOGS ==="
sudo tail -10 /var/log/postgresql/postgresql-*.log 2>/dev/null | grep -E "recovery|redo|WAL|shut" | tail -5 || echo "Logs not available"

echo ""
echo "=== DATA STATE AFTER CRASH & RECOVERY ==="
sudo -u postgres psql -d crash_test -c "
    SELECT id, step, data, lsn 
    FROM crash_visible 
    ORDER BY id;
"

echo ""
echo "=== CRASH IMPACT SUMMARY ==="
sudo -u postgres psql -d crash_test -c "
    SELECT 
        'Total records recovered: ' || count(*) as total,
        'Committed transactions: ' || count(*) FILTER (WHERE step LIKE 'committed%') as committed,
        'Long starts (partial): ' || count(*) FILTER (WHERE step LIKE 'long_start%') as long_starts,
        'Long ends (lost): ' || count(*) FILTER (WHERE step LIKE 'long_end%') as long_ends
    FROM crash_visible;
"

echo ""
echo "=== WAL ANALYSIS ==="
sudo -u postgres psql -d crash_test -c "
    SELECT 'Current WAL LSN:', pg_current_wal_lsn() as current_lsn;
    SELECT 'WAL monitor entries:', count(*) FROM wal_monitor;
    
    SELECT 
        operation, 
        data_state,
        count(*) as count
    FROM wal_monitor 
    GROUP BY operation, data_state 
    ORDER BY operation, data_state;
"

echo ""
echo "ANALYSIS COMPLETE"
echo "   Look for differences between 'long_start_' and 'long_end_' records"
echo "   to see what was lost during the crash"