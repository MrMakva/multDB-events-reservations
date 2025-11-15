CREATE OR REPLACE VIEW active_transactions_commit_monitoring AS
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    to_char(backend_start, 'YYYY-MM-DD HH24:MI:SS') as backend_started,
    to_char(xact_start, 'YYYY-MM-DD HH24:MI:SS') as transaction_started,
    to_char(query_start, 'YYYY-MM-DD HH24:MI:SS') as query_started,
    state,
    wait_event_type,
    wait_event,
    LEFT(query, 100) as current_query,
    age(clock_timestamp(), xact_start) as transaction_age,
    CASE 
        WHEN state = 'idle in transaction' THEN 'IDLE_COMMIT_PENDING'
        WHEN state = 'active' AND query ~* '(COMMIT|ROLLBACK)' THEN 'COMMITTING'
        ELSE 'ACTIVE'
    END as transaction_status
FROM pg_stat_activity 
WHERE datname = 'bd'
AND xact_start IS NOT NULL
ORDER BY xact_start;

CREATE OR REPLACE VIEW transaction_logs_monitoring AS
SELECT 
    'Check log_statement setting' as info,
    (SELECT setting FROM pg_settings WHERE name = 'log_statement') as current_setting,
    'Enable log_statement=all for detailed query history' as recommendation;

CREATE OR REPLACE VIEW table_commit_stats AS
SELECT 
    schemaname,
    relname as table_name,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_tup_hot_upd as hot_updates,
    n_tup_ins + n_tup_upd + n_tup_del as total_writes,
    round(n_tup_hot_upd * 100.0 / nullif(n_tup_upd, 0), 2) as hot_update_pct,
    to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI') as last_autovacuum,
    to_char(last_autoanalyze, 'YYYY-MM-DD HH24:MI') as last_autoanalyze
FROM pg_stat_all_tables 
WHERE schemaname = 'public'
AND (n_tup_ins + n_tup_upd + n_tup_del) > 0
ORDER BY total_writes DESC;

CREATE OR REPLACE VIEW detailed_database_stats AS
SELECT 
    datname,
    xact_commit as total_commits,
    xact_rollback as total_rollbacks,
    blks_read as disk_reads,
    blks_hit as cache_hits,
    round(blks_hit * 100.0 / nullif(blks_hit + blks_read, 0), 2) as cache_hit_ratio,
    tup_returned as tuples_returned,
    tup_fetched as tuples_fetched,
    tup_inserted as tuples_inserted,
    tup_updated as tuples_updated,
    tup_deleted as tuples_deleted,
    conflicts as replication_conflicts,
    temp_files as temporary_files,
    temp_bytes as temporary_bytes,
    to_char(stats_reset, 'YYYY-MM-DD HH24:MI:SS') as stats_since
FROM pg_stat_database 
WHERE datname = 'bd';

CREATE OR REPLACE VIEW commit_locks_monitoring AS
SELECT 
    a.pid,
    a.usename,
    a.application_name,
    a.state,
    a.wait_event_type,
    a.wait_event,
    l.locktype,
    l.mode,
    l.granted,
    a.query_start,
    age(clock_timestamp(), a.query_start) as query_age,
    LEFT(a.query, 80) as blocking_query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE a.datname = 'bd'
AND l.mode IN ('ExclusiveLock', 'AccessExclusiveLock')
AND a.state = 'active'
ORDER BY query_age DESC;

CREATE OR REPLACE VIEW activity_trends_monitoring AS
SELECT 
    'current' as period,
    (SELECT xact_commit FROM pg_stat_database WHERE datname = 'bd') as commits,
    (SELECT xact_rollback FROM pg_stat_database WHERE datname = 'bd') as rollbacks,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'bd' AND state = 'active') as active_queries,
    (SELECT COUNT(*) FROM pg_locks WHERE granted = false) as waiting_locks
FROM pg_stat_database 
WHERE datname = 'bd';