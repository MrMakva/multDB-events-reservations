#!/bin/bash

DB_NAME="bd"
LOG_FILE="/tmp/final_technical_monitor_$(date +%Y%m%d_%H%M%S).log"
PROMETHEUS_DIR="/tmp/prometheus_export"
PROMETHEUS_FILE="${PROMETHEUS_DIR}/postgres_metrics.prom"

# Создаем директорию для Prometheus если не существует (используем /tmp чтобы избежать проблем с правами)
mkdir -p "$PROMETHEUS_DIR"

echo "=== TECHNICAL DATABASE MONITORING ===" > $LOG_FILE
echo "Timestamp: $(date)" >> $LOG_FILE
echo "Database: $DB_NAME" >> $LOG_FILE
echo "===========================================" >> $LOG_FILE

echo "# HELP postgres_monitoring_metrics PostgreSQL monitoring metrics" > $PROMETHEUS_FILE
echo "# TYPE postgres_monitoring_metrics gauge" >> $PROMETHEUS_FILE
echo "# Generated at $(date +%s)" >> $PROMETHEUS_FILE

create_monitoring_views() {
    echo "Creating/updating monitoring views..." >> $LOG_FILE
    
    # 1. SYSTEM OVERVIEW VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW technical_monitoring AS
    SELECT 
        pg_size_pretty(pg_database_size(current_database())) as db_size,
        (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()) as total_connections,
        (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND state = 'active') as active_connections,
        (SELECT count(*) FROM pg_locks WHERE granted = false) as waiting_locks,
        (SELECT count(*) FROM pg_stat_all_indexes WHERE idx_scan = 0 AND schemaname NOT LIKE 'pg_%' AND schemaname != 'information_schema') as unused_indexes,
        (SELECT COALESCE(sum(n_dead_tup), 0) FROM pg_stat_all_tables WHERE schemaname NOT LIKE 'pg_%' AND schemaname != 'information_schema') as total_dead_tuples;
    " >> $LOG_FILE 2>&1

    # 2. WAL MONITORING VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW wal_monitoring AS
    SELECT 
        pg_current_wal_lsn() as current_wal_lsn,
        (SELECT COALESCE(xact_commit, 0) FROM pg_stat_database WHERE datname = current_database()) as total_commits,
        (SELECT COALESCE(xact_rollback, 0) FROM pg_stat_database WHERE datname = current_database()) as total_rollbacks,
        COALESCE((SELECT checksum_failures FROM pg_stat_database WHERE datname = current_database()), 0) as checksum_failures,
        (SELECT setting FROM pg_settings WHERE name = 'archive_mode') as archive_mode;
    " >> $LOG_FILE 2>&1

    # 3. DATABASE STATS VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW database_stats_monitoring AS
    SELECT 
        COALESCE(xact_commit, 0) as total_commits,
        COALESCE(xact_rollback, 0) as total_rollbacks,
        ROUND(COALESCE(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 0), 2) as cache_hit_ratio,
        COALESCE(tup_inserted, 0) as tuples_inserted,
        COALESCE(tup_updated, 0) as tuples_updated,
        COALESCE(tup_deleted, 0) as tuples_deleted
    FROM pg_stat_database WHERE datname = current_database();
    " >> $LOG_FILE 2>&1

    # 4. VACUUM MONITORING VIEW (с данными из всех таблиц)
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW vacuum_monitoring AS
    SELECT 
        schemaname || '.' || relname as table_name,
        COALESCE(n_live_tup, 0) as live_tuples,
        COALESCE(n_dead_tup, 0) as dead_tuples,
        CASE 
            WHEN COALESCE(n_live_tup, 0) + COALESCE(n_dead_tup, 0) > 0 
            THEN ROUND(COALESCE(n_dead_tup, 0) * 100.0 / (COALESCE(n_live_tup, 0) + COALESCE(n_dead_tup, 0)), 2)
            ELSE 0
        END as dead_percent,
        COALESCE(age(now(), last_autovacuum), interval '0') as autovacuum_age
    FROM pg_stat_all_tables 
    WHERE schemaname NOT LIKE 'pg_%' 
    AND schemaname != 'information_schema'
    AND (n_live_tup > 0 OR n_dead_tup > 0)
    ORDER BY dead_percent DESC;
    " >> $LOG_FILE 2>&1

    # 5. LOCKS MONITORING VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW locks_monitoring AS
    SELECT 
        locktype,
        mode,
        granted,
        COUNT(*) as lock_count
    FROM pg_locks 
    GROUP BY locktype, mode, granted
    HAVING COUNT(*) > 0
    ORDER BY lock_count DESC;
    " >> $LOG_FILE 2>&1

    # 6. INDEX USAGE VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW index_usage_monitoring AS
    SELECT 
        schemaname || '.' || relname as table_name,
        indexrelname as index_name,
        COALESCE(idx_scan, 0) as scans,
        pg_size_pretty(COALESCE(pg_relation_size(indexrelid), 0)) as index_size,
        CASE 
            WHEN COALESCE(idx_scan, 0) = 0 THEN 'UNUSED'
            WHEN COALESCE(idx_scan, 0) < 100 THEN 'RARELY_USED'
            ELSE 'NORMAL'
        END as usage_status
    FROM pg_stat_all_indexes 
    WHERE schemaname NOT LIKE 'pg_%' 
    AND schemaname != 'information_schema'
    ORDER BY COALESCE(pg_relation_size(indexrelid), 0) DESC;
    " >> $LOG_FILE 2>&1

    # 7. BUFFER CACHE VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW buffer_cache_monitoring AS
    SELECT 
        ROUND(COALESCE(SUM(heap_blks_hit) * 100.0 / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0), 0), 2) as heap_hit_ratio,
        ROUND(COALESCE(SUM(idx_blks_hit) * 100.0 / NULLIF(SUM(idx_blks_hit) + SUM(idx_blks_read), 0), 0), 2) as index_hit_ratio,
        COALESCE(SUM(heap_blks_read), 0) as heap_blocks_read,
        COALESCE(SUM(idx_blks_read), 0) as index_blocks_read
    FROM pg_statio_all_tables 
    WHERE schemaname NOT LIKE 'pg_%' 
    AND schemaname != 'information_schema';
    " >> $LOG_FILE 2>&1

    # 8. LONG TRANSACTIONS VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW long_transactions_monitoring AS
    SELECT 
        COALESCE(usename, 'unknown') as username,
        COALESCE(application_name, 'unknown') as application_name,
        COALESCE(age(now(), xact_start), interval '0') as transaction_age,
        COALESCE(LEFT(query, 50), '') as current_query
    FROM pg_stat_activity 
    WHERE datname = current_database()
    AND xact_start IS NOT NULL
    AND state = 'active';
    " >> $LOG_FILE 2>&1

    # 9. TABLESPACE VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW tablespace_monitoring AS
    SELECT 
        spcname as tablespace_name,
        pg_size_pretty(COALESCE(pg_tablespace_size(spcname), 0)) as size,
        COALESCE((SELECT COUNT(*) FROM pg_tables WHERE tablespace = spcname), 0) as tables_count
    FROM pg_tablespace 
    WHERE spcname NOT LIKE 'pg_%';
    " >> $LOG_FILE 2>&1

    # 10. SYSTEM RESOURCES VIEW
    psql -d $DB_NAME -c "
    CREATE OR REPLACE VIEW system_resources_monitoring AS
    SELECT 
        (SELECT setting FROM pg_settings WHERE name = 'shared_buffers') as shared_buffers,
        (SELECT setting FROM pg_settings WHERE name = 'work_mem') as work_mem,
        (SELECT setting FROM pg_settings WHERE name = 'maintenance_work_mem') as maintenance_work_mem,
        (SELECT setting FROM pg_settings WHERE name = 'max_connections') as max_connections,
        (SELECT setting FROM pg_settings WHERE name = 'max_wal_size') as max_wal_size;
    " >> $LOG_FILE 2>&1
    
    echo "Monitoring views created/updated successfully." >> $LOG_FILE
}

create_monitoring_views

add_prometheus_metric() {
    local query="$1"
    local metric_name="$2"
    local value=$(psql -d $DB_NAME -t -A -c "$query" 2>/dev/null | tr -d '\r')
    if [ -n "$value" ] && [[ "$value" =~ ^[-]?[0-9]+\.?[0-9]*$ ]]; then
        echo "postgres_${metric_name}{database=\"$DB_NAME\"} $value" >> $PROMETHEUS_FILE
        return 0
    else
        return 1
    fi
}

execute_and_log_query() {
    local section="$1"
    local query="$2"
    echo -e "\n--- $section ---" >> $LOG_FILE
    psql -d $DB_NAME -c "$query" 2>&1 | grep -v "CREATE VIEW" >> $LOG_FILE
}

# 1. SYSTEM OVERVIEW
execute_and_log_query "SYSTEM OVERVIEW" "
SELECT 
    db_size as \"Database Size\",
    total_connections as \"Connections\",
    active_connections as \"Active\", 
    waiting_locks as \"Waiting Locks\",
    unused_indexes as \"Unused Indexes\",
    total_dead_tuples as \"Dead Tuples\"
FROM technical_monitoring;"

add_prometheus_metric "SELECT total_connections FROM technical_monitoring;" "system_total_connections"
add_prometheus_metric "SELECT active_connections FROM technical_monitoring;" "system_active_connections"
add_prometheus_metric "SELECT waiting_locks FROM technical_monitoring;" "system_waiting_locks"
add_prometheus_metric "SELECT unused_indexes FROM technical_monitoring;" "system_unused_indexes"
add_prometheus_metric "SELECT total_dead_tuples FROM technical_monitoring;" "system_dead_tuples"

# 2. WAL & TRANSACTIONS
execute_and_log_query "WAL & TRANSACTIONS" "
SELECT 
    current_wal_lsn as \"WAL LSN\",
    total_commits as \"Commits\",
    total_rollbacks as \"Rollbacks\",
    checksum_failures as \"Checksum Errors\",
    archive_mode as \"Archive Mode\"
FROM wal_monitoring;"

add_prometheus_metric "SELECT total_commits FROM wal_monitoring;" "wal_total_commits"
add_prometheus_metric "SELECT total_rollbacks FROM wal_monitoring;" "wal_total_rollbacks"

# 3. DATABASE STATISTICS
execute_and_log_query "DATABASE STATISTICS" "
SELECT 
    total_commits as \"Commits\",
    total_rollbacks as \"Rollbacks\",
    cache_hit_ratio as \"Cache Hit %\",
    tuples_inserted as \"Inserts\",
    tuples_updated as \"Updates\",
    tuples_deleted as \"Deletes\"
FROM database_stats_monitoring;"

add_prometheus_metric "SELECT total_commits FROM database_stats_monitoring;" "db_total_commits"
add_prometheus_metric "SELECT total_rollbacks FROM database_stats_monitoring;" "db_total_rollbacks"
add_prometheus_metric "SELECT cache_hit_ratio FROM database_stats_monitoring;" "db_cache_hit_ratio"
add_prometheus_metric "SELECT tuples_inserted FROM database_stats_monitoring;" "db_tuples_inserted"
add_prometheus_metric "SELECT tuples_updated FROM database_stats_monitoring;" "db_tuples_updated"
add_prometheus_metric "SELECT tuples_deleted FROM database_stats_monitoring;" "db_tuples_deleted"

# 4. VACUUM MONITORING
execute_and_log_query "VACUUM MONITORING" "
SELECT 
    table_name as \"Table\",
    live_tuples as \"Live\",
    dead_tuples as \"Dead\", 
    dead_percent as \"Dead %\",
    autovacuum_age as \"AutoVacuum Age\"
FROM vacuum_monitoring 
ORDER BY dead_percent DESC NULLS LAST
LIMIT 8;"

# 5. LOCKS MONITORING
execute_and_log_query "LOCKS MONITORING" "
SELECT 
    locktype as \"Lock Type\",
    mode as \"Mode\",
    granted as \"Granted\",
    lock_count as \"Count\"
FROM locks_monitoring 
WHERE lock_count > 0
ORDER BY lock_count DESC
LIMIT 8;"

# 6. INDEX USAGE
execute_and_log_query "INDEX USAGE" "
SELECT 
    table_name as \"Table\",
    index_name as \"Index\",
    scans as \"Scans\",
    index_size as \"Size\",
    usage_status as \"Status\"
FROM index_usage_monitoring 
WHERE usage_status IN ('UNUSED', 'RARELY_USED')
ORDER BY index_size DESC
LIMIT 12;"

# 7. BUFFER CACHE
execute_and_log_query "BUFFER CACHE" "
SELECT 
    COALESCE(heap_hit_ratio, 0) as \"Heap Hit %\",
    COALESCE(index_hit_ratio, 0) as \"Index Hit %\",
    heap_blocks_read as \"Heap Reads\",
    index_blocks_read as \"Index Reads\"
FROM buffer_cache_monitoring;"

add_prometheus_metric "SELECT COALESCE(heap_hit_ratio, 0) FROM buffer_cache_monitoring;" "buffer_heap_hit_ratio"
add_prometheus_metric "SELECT COALESCE(index_hit_ratio, 0) FROM buffer_cache_monitoring;" "buffer_index_hit_ratio"

# 8. LONG TRANSACTIONS
execute_and_log_query "LONG TRANSACTIONS" "
SELECT 
    username as \"User\",
    application_name as \"App\",
    transaction_age as \"Age\",
    LEFT(current_query, 50) as \"Query\"
FROM long_transactions_monitoring 
WHERE transaction_age > '00:00:05'::interval
ORDER BY transaction_age DESC
LIMIT 6;"

# 9. TABLESPACES
execute_and_log_query "TABLESPACES" "
SELECT 
    tablespace_name as \"Tablespace\",
    size as \"Size\",
    tables_count as \"Tables\"
FROM tablespace_monitoring;"

# 10. SYSTEM CONFIGURATION
execute_and_log_query "SYSTEM CONFIGURATION" "
SELECT 
    shared_buffers as \"Shared Buffers\",
    work_mem as \"Work Mem\",
    maintenance_work_mem as \"Maintenance Mem\",
    max_connections as \"Max Connections\",
    max_wal_size as \"Max WAL Size\"
FROM system_resources_monitoring;"

add_prometheus_metric "SELECT REPLACE(shared_buffers, 'kB', '')::integer * 1024 FROM system_resources_monitoring;" "config_shared_buffers_bytes"
add_prometheus_metric "SELECT REPLACE(work_mem, 'kB', '')::integer * 1024 FROM system_resources_monitoring;" "config_work_mem_bytes"
add_prometheus_metric "SELECT REPLACE(maintenance_work_mem, 'kB', '')::integer * 1024 FROM system_resources_monitoring;" "config_maintenance_work_mem_bytes"
add_prometheus_metric "SELECT max_connections::integer FROM system_resources_monitoring;" "config_max_connections"
add_prometheus_metric "SELECT REPLACE(max_wal_size, 'MB', '')::integer * 1024 * 1024 FROM system_resources_monitoring;" "config_max_wal_size_bytes"

add_prometheus_metric "SELECT pg_database_size(current_database());" "database_size_bytes"

echo "postgres_last_update_timestamp{database=\"$DB_NAME\"} $(date +%s)" >> $PROMETHEUS_FILE

echo -e "\n=== MONITORING COMPLETE ===" >> $LOG_FILE

echo "Final technical monitoring saved: $LOG_FILE"
echo "Prometheus metrics saved: $PROMETHEUS_FILE"
echo ""
echo "=== LOG PREVIEW ==="
cat $LOG_FILE

echo ""
echo "=== PROMETHEUS VISUALIZATION SETUP ==="
echo ""
echo "Для визуализации в Prometheus выполните следующие шаги:"
echo ""
echo "1. Установите Prometheus и Grafana если еще не установлены:"
echo "   sudo apt-get install prometheus grafana"
echo ""
echo "2. Добавьте в конфигурацию Prometheus (/etc/prometheus/prometheus.yml):"
echo "   Добавьте в раздел scrape_configs:"
echo "   - job_name: 'postgres_exporter'"
echo "     static_configs:"
echo "       - targets: ['localhost:9091']"
echo ""
echo "3. Установите и запустите node_exporter:"
echo "   sudo apt-get install prometheus-node-exporter"
echo "   sudo systemctl enable prometheus-node-exporter"
echo "   sudo systemctl start prometheus-node-exporter"
echo ""
echo "4. Настройте node_exporter для сбора кастомных метрик:"
echo "   В файле /etc/default/prometheus-node-exporter добавьте:"
echo "   ARGS=\"--collector.textfile.directory=/tmp/prometheus_export\""
echo "   sudo systemctl restart prometheus-node-exporter"
echo ""
echo "5. Настройте cron для регулярного выполнения скрипта:"
echo "   crontab -e"
echo "   Добавьте строку: */5 * * * * $(pwd)/$(basename $0)"
echo ""
echo "6. В Grafana создайте dashboard и добавьте метрики с префиксом 'postgres_'"
echo ""
echo "7. Текущие метрики доступны в файле: $PROMETHEUS_FILE"
echo "   Содержимое файла метрик:"
echo "   =========================="
cat $PROMETHEUS_FILE

