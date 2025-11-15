#!/bin/bash

DB_NAME="bd"
LOG_FILE="/tmp/final_technical_monitor_$(date +%Y%m%d_%H%M%S).log"

echo "=== TECHNICAL DATABASE MONITORING ===" > $LOG_FILE
echo "Timestamp: $(date)" >> $LOG_FILE
echo "Database: $DB_NAME" >> $LOG_FILE
echo "===========================================" >> $LOG_FILE

echo -e "\n--- SYSTEM OVERVIEW ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    db_size as \"Database Size\",
    total_connections as \"Connections\",
    active_connections as \"Active\", 
    waiting_locks as \"Waiting Locks\",
    unused_indexes as \"Unused Indexes\",
    total_dead_tuples as \"Dead Tuples\"
FROM technical_monitoring;" >> $LOG_FILE

echo -e "\n--- WAL & TRANSACTIONS ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    current_wal_lsn as \"WAL LSN\",
    total_commits as \"Commits\",
    total_rollbacks as \"Rollbacks\",
    checksum_failures as \"Checksum Errors\",
    archive_mode as \"Archive Mode\"
FROM wal_monitoring;" >> $LOG_FILE

echo -e "\n--- DATABASE STATISTICS ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    total_commits as \"Commits\",
    total_rollbacks as \"Rollbacks\",
    cache_hit_ratio as \"Cache Hit %\",
    tuples_inserted as \"Inserts\",
    tuples_updated as \"Updates\",
    tuples_deleted as \"Deletes\"
FROM database_stats_monitoring;" >> $LOG_FILE

echo -e "\n--- VACUUM MONITORING ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    table_name as \"Table\",
    live_tuples as \"Live\",
    dead_tuples as \"Dead\", 
    dead_percent as \"Dead %\",
    autovacuum_age as \"AutoVacuum Age\"
FROM vacuum_monitoring 
ORDER BY dead_percent DESC
LIMIT 8;" >> $LOG_FILE

echo -e "\n--- LOCKS MONITORING ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    locktype as \"Lock Type\",
    mode as \"Mode\",
    granted as \"Granted\",
    lock_count as \"Count\"
FROM locks_monitoring 
WHERE lock_count > 0
ORDER BY lock_count DESC
LIMIT 8;" >> $LOG_FILE

echo -e "\n--- INDEX USAGE ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    table_name as \"Table\",
    index_name as \"Index\",
    scans as \"Scans\",
    index_size as \"Size\",
    usage_status as \"Status\"
FROM index_usage_monitoring 
WHERE usage_status IN ('UNUSED', 'RARELY_USED')
ORDER BY index_size DESC
LIMIT 12;" >> $LOG_FILE

echo -e "\n--- BUFFER CACHE ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    COALESCE(heap_hit_ratio, 0) as \"Heap Hit %\",
    COALESCE(index_hit_ratio, 0) as \"Index Hit %\",
    heap_blocks_read as \"Heap Reads\",
    index_blocks_read as \"Index Reads\"
FROM buffer_cache_monitoring;" >> $LOG_FILE

echo -e "\n--- LONG TRANSACTIONS ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    username as \"User\",
    application_name as \"App\",
    transaction_age as \"Age\",
    LEFT(current_query, 50) as \"Query\"
FROM long_transactions_monitoring 
WHERE transaction_age > '00:00:05'::interval
ORDER BY transaction_age DESC
LIMIT 6;" >> $LOG_FILE

echo -e "\n--- TABLESPACES ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    tablespace_name as \"Tablespace\",
    size as \"Size\",
    tables_count as \"Tables\"
FROM tablespace_monitoring;" >> $LOG_FILE

echo -e "\n--- SYSTEM CONFIGURATION ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    shared_buffers as \"Shared Buffers\",
    work_mem as \"Work Mem\",
    maintenance_work_mem as \"Maintenance Mem\",
    max_connections as \"Max Connections\",
    max_wal_size as \"Max WAL Size\"
FROM system_resources_monitoring,
(SELECT setting as max_wal_size FROM pg_settings WHERE name = 'max_wal_size') wal;" >> $LOG_FILE

echo -e "\n=== MONITORING COMPLETE ===" >> $LOG_FILE

echo "Final technical monitoring saved: $LOG_FILE"
echo ""
cat $LOG_FILE