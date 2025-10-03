-- 1. Aggregating queries
-- Total revenue per event
SELECT 
    e.title,
    COUNT(b.booking_id) as total_bookings,
    SUM(b.total_amount) as total_revenue,
    AVG(b.total_amount) as avg_booking_value
FROM Events e
LEFT JOIN Bookings b ON e.event_id = b.event_id
WHERE b.status = 'confirmed'
GROUP BY e.event_id, e.title
ORDER BY total_revenue DESC;

-- 2. User activity statistics
SELECT 
    u.email,
    COUNT(b.booking_id) as bookings_count,
    SUM(b.total_amount) as total_spent,
    MAX(b.booking_date) as last_booking_date
FROM Users u
LEFT JOIN Bookings b ON u.user_id = b.user_id
GROUP BY u.user_id, u.email
ORDER BY total_spent DESC;

-- 3. Window functions - User ranking by spending
SELECT 
    u.email,
    SUM(b.total_amount) as total_spent,
    RANK() OVER (ORDER BY SUM(b.total_amount) DESC) as spending_rank,
    NTILE(4) OVER (ORDER BY SUM(b.total_amount) DESC) as spending_quartile
FROM Users u
JOIN Bookings b ON u.user_id = b.user_id
WHERE b.status = 'confirmed'
GROUP BY u.user_id, u.email
ORDER BY total_spent DESC;

-- 4. Monthly revenue trend
SELECT 
    DATE_TRUNC('month', b.booking_date) as month,
    COUNT(b.booking_id) as bookings_count,
    SUM(b.total_amount) as monthly_revenue,
    AVG(SUM(b.total_amount)) OVER (
        ORDER BY DATE_TRUNC('month', b.booking_date) 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as moving_avg_3months
FROM Bookings b
WHERE b.status = 'confirmed'
GROUP BY DATE_TRUNC('month', b.booking_date)
ORDER BY month;

-- 5. Join 2 tables: Users + Bookings
SELECT 
    u.first_name || ' ' || u.last_name as user_name,
    b.booking_date,
    b.total_amount,
    b.status
FROM Users u
JOIN Bookings b ON u.user_id = b.user_id
ORDER BY b.booking_date DESC;

-- 6. Join 3 tables: Users + Bookings + Events
SELECT 
    u.email,
    e.title as event_name,
    b.booking_date,
    b.total_amount
FROM Users u
JOIN Bookings b ON u.user_id = b.user_id
JOIN Events e ON b.event_id = e.event_id
WHERE b.status = 'confirmed'
ORDER BY b.booking_date DESC;

-- 7. Join 3 tables: Events + Bookings + Transactions
SELECT 
    e.title,
    COUNT(b.booking_id) as confirmed_bookings,
    SUM(t.amount) as total_revenue,
    AVG(t.amount) as avg_transaction
FROM Events e
JOIN Bookings b ON e.event_id = b.event_id
JOIN Transactions t ON b.booking_id = t.booking_id
WHERE b.status = 'confirmed' AND t.status = 'completed'
GROUP BY e.event_id, e.title;

-- 8. Join 4 tables: Users + Bookings + Events + Transactions
SELECT 
    u.email,
    e.title,
    b.booking_date,
    t.amount,
    t.transaction_time
FROM Users u
JOIN Bookings b ON u.user_id = b.user_id
JOIN Events e ON b.event_id = e.event_id
JOIN Transactions t ON b.booking_id = t.booking_id
WHERE t.status = 'completed'
ORDER BY t.transaction_time DESC;

-- 9. Join 5 tables: Users + Bookings + Events + Venues + Organizers
SELECT 
    u.email,
    e.title as event_name,
    v.name as venue_name,
    o.name as organizer_name,
    b.booking_date,
    b.total_amount
FROM Users u
JOIN Bookings b ON u.user_id = b.user_id
JOIN Events e ON b.event_id = e.event_id
JOIN Venues v ON e.venue_id = v.venue_id
JOIN Organizers o ON e.organizer_id = o.organizer_id
WHERE b.status = 'confirmed'
ORDER BY b.booking_date DESC;
