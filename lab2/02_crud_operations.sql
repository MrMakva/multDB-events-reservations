CREATE OR REPLACE FUNCTION create_user(
    p_email VARCHAR, 
    p_first_name VARCHAR, 
    p_last_name VARCHAR
) RETURNS INTEGER AS $$
DECLARE
    new_id INTEGER;
BEGIN
    INSERT INTO Users (email, first_name, last_name) 
    VALUES (p_email, p_first_name, p_last_name)
    RETURNING user_id INTO new_id;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user(p_user_id INTEGER) 
RETURNS TABLE(user_id INT, email VARCHAR, first_name VARCHAR, last_name VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT u.user_id, u.email, u.first_name, u.last_name 
    FROM Users u WHERE u.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_event(
    p_title VARCHAR,
    p_description TEXT,
    p_event_date TIMESTAMP,
    p_base_price DECIMAL
) RETURNS INTEGER AS $$
DECLARE
    new_id INTEGER;
BEGIN
    INSERT INTO Events (title, description, event_date, base_price) 
    VALUES (p_title, p_description, p_event_date, p_base_price)
    RETURNING event_id INTO new_id;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_booking(
    p_user_id INTEGER,
    p_event_id INTEGER,
    p_total_amount DECIMAL
) RETURNS INTEGER AS $$
DECLARE
    new_id INTEGER;
BEGIN
    INSERT INTO Bookings (user_id, event_id, total_amount) 
    VALUES (p_user_id, p_event_id, p_total_amount)
    RETURNING booking_id INTO new_id;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;
