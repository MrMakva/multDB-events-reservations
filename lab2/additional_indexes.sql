-- additional_indexes.sql
-- Дополнительные индексы на основе анализа запросов

-- 1. Составные индексы для часто используемых фильтров
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_event_status_date 
ON Bookings(event_id, status_id, booking_date);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_user_status_date 
ON Bookings(user_id, status_id, booking_date);

-- 2. Индексы для сортировок
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_date_title 
ON Events(event_date, title);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_amount 
ON Bookings(total_amount);

-- 3. Частичные индексы для активных записей
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_active 
ON Bookings(booking_id) 
WHERE status_id IN (1, 2); -- только pending и confirmed

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_completed 
ON Transactions(transaction_time) 
WHERE status = 'completed';

-- 4. Индексы для полнотекстового поиска (если нужно)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_search 
ON Events USING gin(to_tsvector('english', title || ' ' || description));

-- 5. Индексы для JSONB полей в EventLogs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_eventlogs_action 
ON EventLogs(action, log_timestamp);

-- 6. Индексы для аналитических запросов
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_monthly 
ON Bookings(date_trunc('month', booking_date), status_id);

-- Анализируем таблицы после создания индексов
ANALYZE Bookings;
ANALYZE Events;
ANALYZE Transactions;