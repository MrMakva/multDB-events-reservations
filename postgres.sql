-- Таблица пользователей
CREATE TABLE Users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица методов оплаты
CREATE TABLE PaymentMethods (
    payment_method_id SERIAL PRIMARY KEY,
    method_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- Таблица событий
CREATE TABLE Events (
    event_id SERIAL PRIMARY KEY,
    название VARCHAR(255) NOT NULL,
    дата TIMESTAMP NOT NULL,
    место VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица бронирований
CREATE TABLE Bookings (
    booking_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES Users(user_id),
    event_id INTEGER NOT NULL REFERENCES Events(event_id),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица транзакций
CREATE TABLE Transactions (
    transaction_id SERIAL PRIMARY KEY,
    сумма DECIMAL(10,2) NOT NULL,
    статус VARCHAR(50) NOT NULL,
    время TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    booking_id INTEGER NOT NULL REFERENCES Bookings(booking_id),
    payment_method_id INTEGER NOT NULL REFERENCES PaymentMethods(payment_method_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);