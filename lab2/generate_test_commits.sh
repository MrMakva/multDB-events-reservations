# generate_test_commits.sh
#!/bin/bash

echo "=== GENERATING TEST COMMITS FOR DEMONSTRATION ==="

# Создаем тестовые операции
psql -d bd -c "
-- Тестовые INSERT
INSERT INTO bookings (user_id, event_id, seat_id, ticket_type_id, status_id, total_amount)
SELECT 
    (random() * 99 + 1)::INTEGER,
    (random() * 19 + 1)::INTEGER,
    (random() * 199 + 1)::INTEGER,
    (random() * 3 + 1)::INTEGER,
    1,
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 5) seq;

-- Тестовые UPDATE
UPDATE bookings 
SET total_amount = total_amount * 1.1
WHERE booking_id IN (
    SELECT booking_id FROM bookings 
    WHERE status_id = 2 
    ORDER BY random() 
    LIMIT 3
);

-- Тестовые DELETE
DELETE FROM bookings 
WHERE status_id = 1 
AND booking_id IN (
    SELECT booking_id FROM bookings 
    WHERE status_id = 1 
    ORDER BY random() 
    LIMIT 2
);

-- Обновляем пользователей
UPDATE users 
SET phone = 'test-' || user_id
WHERE user_id IN (1, 5, 10);

-- Обновляем события
UPDATE events 
SET base_price = base_price * 1.05
WHERE event_id IN (1, 3, 5);
"

echo "=== TEST COMMITS GENERATED ==="