-- add_dead_tuples_to_bd.sql
-- Добавление мертвых строк в основные таблицы базы bd

-- 1. Начинаем с бронирований (самая активная таблица)
INSERT INTO bookings (user_id, event_id, seat_id, ticket_type_id, status_id, booking_date, quantity, total_amount)
SELECT 
    (random() * 99 + 1)::INTEGER,
    (random() * 19 + 1)::INTEGER,
    (random() * 199 + 1)::INTEGER,
    (random() * 3 + 1)::INTEGER,
    1, -- pending
    CURRENT_DATE - (random() * 10 * INTERVAL '1 day'),
    (random() * 4 + 1)::INTEGER,
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 1000) seq;

-- 2. Обновляем часть записей для создания мертвых строк
UPDATE bookings 
SET status_id = 2, total_amount = total_amount * 1.1
WHERE booking_id IN (
    SELECT booking_id FROM bookings 
    WHERE status_id = 1 
    ORDER BY booking_id DESC 
    LIMIT 400
);

-- 3. Еще обновления для большего количества мертвых строк
UPDATE bookings 
SET quantity = quantity + 1, total_amount = total_amount * 1.05
WHERE status_id = 2 
AND booking_id IN (
    SELECT booking_id FROM bookings 
    WHERE status_id = 2 
    ORDER BY booking_id DESC 
    LIMIT 300
);

-- 4. Удаляем некоторые записи
DELETE FROM bookings 
WHERE status_id = 1 
AND booking_id IN (
    SELECT booking_id FROM bookings 
    WHERE status_id = 1 
    ORDER BY booking_id DESC 
    LIMIT 200
);

-- 5. Множественные обновления пользователей
UPDATE users 
SET phone = 'updated-' || user_id || '-' || floor(random() * 1000)::text
WHERE user_id % 7 = 0;

UPDATE users 
SET first_name = 'Updated_' || first_name,
    last_name = 'Modified_' || last_name
WHERE user_id % 5 = 0;

-- 6. Обновления событий
UPDATE events 
SET base_price = base_price * (0.9 + random() * 0.3),
    description = 'Updated: ' || description
WHERE event_id % 4 = 0;

-- 7. Обновления транзакций (если есть данные)
UPDATE transactions 
SET amount = amount * (0.95 + random() * 0.1),
    status = CASE WHEN random() < 0.3 THEN 'pending' ELSE status END
WHERE transaction_id IN (
    SELECT transaction_id FROM transactions 
    LIMIT 100
);

-- 8. Обновления отзывов
UPDATE reviews 
SET rating = GREATEST(1, LEAST(5, rating + (random() * 2 - 1)::INTEGER)),
    comment = 'Updated review: ' || comment
WHERE review_id % 3 = 0;

-- 9. Проверяем количество созданных мертвых строк
SELECT 
    relname as table_name,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    round(n_dead_tup::numeric / greatest(n_live_tup + n_dead_tup, 1) * 100, 1) as dead_percent,
    CASE 
        WHEN last_autovacuum IS NULL THEN 'NEVER'
        ELSE to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI')
    END as last_autovacuum
FROM pg_stat_all_tables 
WHERE schemaname = 'public'
AND n_live_tup > 0
ORDER BY n_dead_tup DESC;
