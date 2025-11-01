SELECT * FROM users u
INNER JOIN bookings b ON u.user_id = b.user_id
INNER JOIN events e ON b.event_id = e.event_id
INNER JOIN transactions t ON b.booking_id = t.booking_id
WHERE e.дата BETWEEN '2025-01-01' AND '2025-11-01'
ORDER BY u.name, e.дата;

