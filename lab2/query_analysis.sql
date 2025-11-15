-- query_analysis.sql
-- Анализ и оптимизация конкретных запросов

-- 1. Анализ самых дорогих запросов
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS cache_hit_ratio
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;

-- 2. EXPLAIN ANALYZE для топ-запросов

-- Пример анализа сложного запроса из business_queries
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT 
    e.title,
    COUNT(b.booking_id) as total_bookings,
    SUM(b.total_amount) as total_revenue,
    AVG(b.total_amount) as avg_booking_value
FROM Events e
LEFT JOIN Bookings b ON e.event_id = b.event_id
LEFT JOIN BookingStatus bs ON b.status_id = bs.status_id
WHERE bs.name = 'confirmed'
GROUP BY e.event_id, e.title
ORDER BY total_revenue DESC;

-- 3. Поиск отсутствующих индексов
SELECT
    tablename,
    attname,
    most_common_vals,
    most_common_freqs
FROM pg_stats
WHERE tablename IN ('bookings', 'events', 'users')
AND attname IN ('user_id', 'event_id', 'status_id', 'booking_date')
ORDER BY tablename, attname;

-- 4. Анализ эффективности существующих индексов
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_all_indexes 
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- 5. Запросы с полным сканированием таблиц (seq scan)
SELECT 
    schemaname,
    relname,
    seq_scan,
    seq_tup_read,
    seq_tup_read / seq_scan as avg_tuples_per_scan
FROM pg_stat_all_tables 
WHERE schemaname = 'public'
AND seq_scan > 0
ORDER BY seq_tup_read DESC 
LIMIT 10;