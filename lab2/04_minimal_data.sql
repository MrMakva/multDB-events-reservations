
INSERT INTO Users (email, first_name, last_name, phone)
SELECT 
    'user' || seq || '@example.com',
    'FirstName' || seq,
    'LastName' || seq,
    '+1-555-' || LPAD(seq::TEXT, 4, '0')
FROM generate_series(1, 100) seq;


INSERT INTO Events (title, description, event_date, venue_id, organizer_id, base_price)
SELECT 
    'Event ' || seq,
    'Description for event ' || seq,
    CURRENT_DATE + (seq * INTERVAL '5 days'),
    (seq % 3) + 1,
    (seq % 3) + 1,
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 20) seq;


INSERT INTO Bookings (user_id, event_id, status, booking_date, total_amount)
SELECT 
    (random() * 99 + 1)::INTEGER,
    (random() * 19 + 1)::INTEGER,
    CASE 
        WHEN random() < 0.8 THEN 'confirmed'
        ELSE 'pending'
    END,
    CURRENT_DATE - (random() * 30 * INTERVAL '1 day'),
    ROUND((50 + random() * 200)::NUMERIC, 2)
FROM generate_series(1, 500) seq;

-- Generate transactions for confirmed bookings
INSERT INTO Transactions (booking_id, amount, status)
SELECT 
    booking_id,
    total_amount,
    'completed'
FROM Bookings 
WHERE status = 'confirmed';


INSERT INTO Reviews (event_id, user_id, rating, comment)
SELECT
    (random() * 19 + 1)::INTEGER,
    (random() * 99 + 1)::INTEGER,
    (random() * 5 + 1)::INTEGER,
    'Great event!'
FROM generate_series(1, 50) seq;
