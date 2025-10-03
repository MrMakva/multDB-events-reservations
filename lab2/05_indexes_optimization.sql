CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON Bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_event_id ON Bookings(event_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON Bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_date ON Bookings(booking_date);

CREATE INDEX IF NOT EXISTS idx_events_date ON Events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_venue ON Events(venue_id);

CREATE INDEX IF NOT EXISTS idx_transactions_booking_id ON Transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON Transactions(status);

CREATE INDEX IF NOT EXISTS idx_reviews_event_id ON Reviews(event_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON Reviews(user_id);


CREATE INDEX IF NOT EXISTS idx_bookings_user_event ON Bookings(user_id, event_id);
CREATE INDEX IF NOT EXISTS idx_bookings_event_status ON Bookings(event_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_date_status ON Bookings(booking_date, status);


ANALYZE Users;
ANALYZE Events;
ANALYZE Bookings;
ANALYZE Transactions;
ANALYZE Reviews;


SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
