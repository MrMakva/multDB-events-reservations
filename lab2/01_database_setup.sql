-- 1. Users
CREATE TABLE IF NOT EXISTS Users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Organizers
CREATE TABLE IF NOT EXISTS Organizers (
    organizer_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255),
    phone VARCHAR(20),
    description TEXT
);

-- 3. Venues
CREATE TABLE IF NOT EXISTS Venues (
    venue_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    capacity INTEGER,
    city VARCHAR(100)
);

-- 4. Events
CREATE TABLE IF NOT EXISTS Events (
    event_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_date TIMESTAMP NOT NULL,
    venue_id INTEGER REFERENCES Venues(venue_id),
    organizer_id INTEGER REFERENCES Organizers(organizer_id),
    base_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. TicketTypes
CREATE TABLE IF NOT EXISTS TicketTypes (
    ticket_type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    multiplier DECIMAL(3,2) DEFAULT 1.0
);

-- 6. Seats
CREATE TABLE IF NOT EXISTS Seats (
    seat_id SERIAL PRIMARY KEY,
    venue_id INTEGER REFERENCES Venues(venue_id),
    seat_row VARCHAR(10),
    seat_number INTEGER,
    section VARCHAR(50)
);

-- 7. BookingStatus
CREATE TABLE IF NOT EXISTS BookingStatus (
    status_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

-- 8. PaymentMethods
CREATE TABLE IF NOT EXISTS PaymentMethods (
    method_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

-- 9. Bookings (main table with 3M+ records)
CREATE TABLE IF NOT EXISTS Bookings (
    booking_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES Users(user_id),
    event_id INTEGER REFERENCES Events(event_id),
    seat_id INTEGER REFERENCES Seats(seat_id),
    ticket_type_id INTEGER REFERENCES TicketTypes(ticket_type_id),
    status_id INTEGER REFERENCES BookingStatus(status_id),
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    quantity INTEGER DEFAULT 1,
    total_amount DECIMAL(10,2)
);

-- 10. Transactions
CREATE TABLE IF NOT EXISTS Transactions (
    transaction_id SERIAL PRIMARY KEY,
    booking_id INTEGER REFERENCES Bookings(booking_id),
    amount DECIMAL(10,2) NOT NULL,
    method_id INTEGER REFERENCES PaymentMethods(method_id),
    status VARCHAR(50),
    transaction_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 11. Refunds
CREATE TABLE IF NOT EXISTS Refunds (
    refund_id SERIAL PRIMARY KEY,
    transaction_id INTEGER REFERENCES Transactions(transaction_id),
    refund_amount DECIMAL(10,2) NOT NULL,
    refund_reason TEXT,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50)
);

-- 12. Reviews
CREATE TABLE IF NOT EXISTS Reviews (
    review_id SERIAL PRIMARY KEY,
    event_id INTEGER REFERENCES Events(event_id),
    user_id INTEGER REFERENCES Users(user_id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 13. EventLogs
CREATE TABLE IF NOT EXISTS EventLogs (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES Users(user_id),
    action VARCHAR(100),
    table_name VARCHAR(50),
    record_id INTEGER,
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSONB
);

-- UserBookingHistory is implemented as a view rather than a table
CREATE OR REPLACE VIEW UserBookingHistory AS
SELECT 
    u.user_id,
    u.email,
    u.first_name,
    u.last_name,
    COUNT(b.booking_id) as total_bookings,
    SUM(b.total_amount) as total_spent,
    MAX(b.booking_date) as last_booking_date
FROM Users u
LEFT JOIN Bookings b ON u.user_id = b.user_id
GROUP BY u.user_id, u.email, u.first_name, u.last_name;

-- Insert reference data
INSERT INTO BookingStatus (name) VALUES 
('pending'), ('confirmed'), ('cancelled'), ('refunded');

INSERT INTO PaymentMethods (name) VALUES 
('cash'), ('card'), ('online'), ('bank_transfer');

INSERT INTO TicketTypes (name, multiplier) VALUES 
('Standard', 1.0), ('VIP', 2.5), ('Student', 0.7), ('Premium', 1.8);

INSERT INTO Venues (name, address, capacity, city) VALUES 
('Concert Hall', '123 Main St', 1500, 'New York'),
('Conference Center', '456 Business Ave', 500, 'San Francisco'),
('Stadium', '789 Sports Blvd', 50000, 'Los Angeles'),
('Theater', '321 Arts Street', 300, 'Chicago');

INSERT INTO Organizers (name, contact_email, phone, description) VALUES 
('Music Events Inc', 'music@events.com', '+1-555-MUSIC', 'Professional music event organizers'),
('Tech Conferences Ltd', 'tech@conferences.com', '+1-555-TECH', 'Technology conference specialists'),
('Sports Events Org', 'sports@events.com', '+1-555-SPORT', 'Sports event management'),
('Arts Foundation', 'arts@foundation.com', '+1-555-ARTS', 'Cultural and arts events');