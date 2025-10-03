
INSERT INTO Users (email, first_name, last_name, phone)
SELECT 
    'user' || seq || '@example.com',
    'FirstName' || (seq % 1000),
    'LastName' || (seq % 1000),
    '+1-555-' || LPAD((seq % 10000)::TEXT, 4, '0')
FROM generate_series(1, 100000) seq;

INSERT INTO Seats (venue_id, seat_row, seat_number, section)
SELECT 
    (seq % 4) + 1,
    CHR(65 + (seq % 26)) || ((seq / 26) % 10 + 1)::TEXT,
    (seq % 50) + 1,
    CASE 
        WHEN seq % 4 = 0 THEN 'Front'
        WHEN seq % 4 = 1 THEN 'Middle' 
        WHEN seq % 4 = 2 THEN 'Back'
        ELSE 'Balcony'
    END
FROM generate_series(1, 50000) seq;

INSERT INTO Events (title, description, event_date, venue_id, organizer_id, base_price)
SELECT 
    'Event ' || seq,
    'Description for event ' || seq,
    CURRENT_DATE + (seq % 365 * INTERVAL '1 day') + (random() * 180 * INTERVAL '1 day'),
    (seq % 4) + 1,
    (seq % 4) + 1,
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 10000) seq;

INSERT INTO Bookings (user_id, event_id, seat_id, ticket_type_id, status_id, booking_date, quantity, total_amount)
SELECT 
    (seq % 100000) + 1,
    (seq % 10000) + 1,
    (seq % 50000) + 1,
    (seq % 4) + 1,
    CASE 
        WHEN random() < 0.7 THEN 2 
        WHEN random() < 0.9 THEN 1
        ELSE 3
    END,
    CURRENT_DATE - (seq % 365 * INTERVAL '1 day') - (random() * 180 * INTERVAL '1 day'),
    1 + (seq % 4),
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 3000000) seq;

INSERT INTO Transactions (booking_id, amount, method_id, status, transaction_time)
SELECT 
    b.booking_id,
    b.total_amount,
    (b.booking_id % 4) + 1,
    CASE 
        WHEN b.status_id = 2 THEN 'completed'
        WHEN b.status_id = 1 THEN 'pending'
        ELSE 'failed'
    END,
    b.booking_date + INTERVAL '1 hour'
FROM Bookings b
WHERE b.booking_id <= 2500000;

INSERT INTO Refunds (transaction_id, refund_amount, refund_reason, status)
SELECT 
    t.transaction_id,
    t.amount * 0.8,
    CASE 
        WHEN seq % 5 = 0 THEN 'Event cancelled'
        WHEN seq % 5 = 1 THEN 'User request'
        WHEN seq % 5 = 2 THEN 'Double booking'
        WHEN seq % 5 = 3 THEN 'Payment error'
        ELSE 'Other reason'
    END,
    CASE 
        WHEN random() < 0.8 THEN 'processed'
        ELSE 'pending'
    END
FROM Transactions t
JOIN Bookings b ON t.booking_id = b.booking_id
WHERE b.status_id = 3 AND t.transaction_id <= 50000;

INSERT INTO Reviews (event_id, user_id, rating, comment, created_at)
SELECT 
    (seq % 10000) + 1,
    (seq % 100000) + 1,
    1 + (seq % 5),
    'Comment for event ' || (seq % 10000 + 1) || ' by user ' || (seq % 100000 + 1),
    CURRENT_DATE - (seq % 90 * INTERVAL '1 day')
FROM generate_series(1, 400000) seq;

INSERT INTO EventLogs (user_id, action, table_name, record_id, details)
SELECT 
    (seq % 100000) + 1,
    CASE 
        WHEN seq % 4 = 0 THEN 'CREATE'
        WHEN seq % 4 = 1 THEN 'UPDATE'
        WHEN seq % 4 = 2 THEN 'DELETE'
        ELSE 'VIEW'
    END,
    CASE 
        WHEN seq % 5 = 0 THEN 'Bookings'
        WHEN seq % 5 = 1 THEN 'Events'
        WHEN seq % 5 = 2 THEN 'Users'
        WHEN seq % 5 = 3 THEN 'Transactions'
        ELSE 'Reviews'
    END,
    (seq % 1000000) + 1,
    '{"ip": "192.168.1.' || (seq % 255 + 1) || '", "user_agent": "Browser ' || (seq % 10) || '"}'
FROM generate_series(1, 800000) seq;