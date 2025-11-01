#!/bin/bash

echo "=== LIVE MONITOR ==="
echo "Monitoring database activity until manually stopped with Ctrl+C"
echo ""

while true; do
    clear
    echo "$(date +%H:%M:%S)"
    echo "=== DATABASE STATUS ==="
    
    if pgrep -x postgres > /dev/null; then
        echo "PostgreSQL: RUNNING"

        if sudo -u postgres psql -d crash_test -c "SELECT 1;" &>/dev/null; then
            echo "Active transactions in crash_test:"
            
            sudo -u postgres psql -d crash_test -c "
                SELECT 
                    pid,
                    left(query, 50) as query_part,
                    state,
                    pg_current_wal_lsn() as current_lsn
                FROM pg_stat_activity 
                WHERE datname = 'crash_test'
                AND query NOT LIKE '%pg_stat_activity%'
                ORDER BY state DESC;
            " 2>/dev/null || echo "No active transactions visible"
            
            echo ""
            echo "=== DATA PROGRESS ==="
            sudo -u postgres psql -d crash_test -c "
                SELECT 'Total records:', count(*) as count FROM crash_visible;
                SELECT 'Last LSN:', pg_current_wal_lsn() as lsn;
            " 2>/dev/null
            
        else
            echo "Database crash_test not accessible"
        fi
        
        echo ""
        echo "=== WAL STATUS ==="
        WAL_FILES=$(sudo ls -1 /var/lib/postgresql/*/main/pg_wal/ 2>/dev/null | grep -c wal || echo "0")
        echo "WAL files: $WAL_FILES"
        
    else
        echo "PostgreSQL: STOPPED"
        echo "Database was killed - run './analyze_after_crash.sh' for recovery analysis"
        break
    fi
    
    echo ""
    echo "Press Ctrl+C to stop monitoring"
    sleep 3
done