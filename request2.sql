SELECT * 
FROM Users u 
INNER JOIN Bookings b ON u.user_id = b.user_id 
WHERE b.date BETWEEN '2025-01-01' AND '2025-11-01'
ORDER BY u.name, b.date
LIMIT 10 OFFSET 5;
