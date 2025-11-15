-- 04_minimal_data.sql

-- Вставка пользователей
INSERT INTO Users (email, first_name, last_name, phone)
SELECT 
    'user' || seq || '@example.com',
    'FirstName' || (seq % 10 + 1),
    'LastName' || (seq % 10 + 1),
    '+1-555-' || LPAD((seq % 1000)::TEXT, 4, '0')
FROM generate_series(1, 100) seq;

-- Вставка событий (исправлены venue_id и organizer_id - используем существующие)
INSERT INTO Events (title, description, event_date, venue_id, organizer_id, base_price)
SELECT 
    'Event ' || seq,
    'Description for event ' || seq,
    CURRENT_DATE + (seq * INTERVAL '5 days'),
    ((seq - 1) % 4) + 1, -- venue_id от 1 до 4 (существующие)
    ((seq - 1) % 4) + 1, -- organizer_id от 1 до 4 (существующие)
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 20) seq;

-- Вставка мест (если нужно для связей)
INSERT INTO Seats (venue_id, seat_row, seat_number, section)
SELECT 
    ((seq - 1) % 4) + 1,
    CHR(65 + ((seq - 1) % 26)) || (((seq - 1) / 26) % 10 + 1)::TEXT,
    (seq % 50) + 1,
    CASE 
        WHEN seq % 4 = 0 THEN 'Front'
        WHEN seq % 4 = 1 THEN 'Middle' 
        WHEN seq % 4 = 2 THEN 'Back'
        ELSE 'Balcony'
    END
FROM generate_series(1, 200) seq;

-- Вставка бронирований (ИСПРАВЛЕНО - используем status_id вместо status)
INSERT INTO Bookings (user_id, event_id, seat_id, ticket_type_id, status_id, booking_date, quantity, total_amount)
SELECT 
    ((seq - 1) % 100) + 1, -- user_id от 1 до 100
    ((seq - 1) % 20) + 1,  -- event_id от 1 до 20
    ((seq - 1) % 200) + 1, -- seat_id от 1 до 200
    ((seq - 1) % 4) + 1,   -- ticket_type_id от 1 до 4
    CASE 
        WHEN random() < 0.8 THEN 2 -- confirmed
        WHEN random() < 0.9 THEN 1 -- pending
        ELSE 3 -- cancelled
    END,
    CURRENT_DATE - (random() * 30 * INTERVAL '1 day'),
    1 + (seq % 4), -- quantity от 1 до 4
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 500) seq;

-- Генерация транзакций для подтвержденных бронирований (ИСПРАВЛЕНО)
INSERT INTO Transactions (booking_id, amount, method_id, status, transaction_time)
SELECT 
    b.booking_id,
    b.total_amount,
    ((b.booking_id - 1) % 4) + 1, -- method_id от 1 до 4
    CASE 
        WHEN b.status_id = 2 THEN 'completed'
        WHEN b.status_id = 1 THEN 'pending'
        ELSE 'failed'
    END,
    b.booking_date + INTERVAL '1 hour'
FROM Bookings b
WHERE b.status_id IN (1, 2); -- pending и confirmed

-- Вставка отзывов (ИСПРАВЛЕНО - rating должен быть от 1 до 5)
INSERT INTO Reviews (event_id, user_id, rating, comment, created_at)
SELECT
    ((seq - 1) % 20) + 1, -- event_id от 1 до 20
    ((seq - 1) % 100) + 1, -- user_id от 1 до 100
    (random() * 4 + 1)::INTEGER, -- rating от 1 до 5 (исправлено!)
    'Great event ' || (((seq - 1) % 20) + 1)::TEXT || '!',
    CURRENT_DATE - (random() * 90 * INTERVAL '1 day')
FROM generate_series(1, 50) seq;

-- Проверка вставленных данных
SELECT 
    (SELECT COUNT(*) FROM Users) as users_count,
    (SELECT COUNT(*) FROM Events) as events_count,
    (SELECT COUNT(*) FROM Bookings) as bookings_count,
    (SELECT COUNT(*) FROM Transactions) as transactions_count,
    (SELECT COUNT(*) FROM Reviews) as reviews_count;