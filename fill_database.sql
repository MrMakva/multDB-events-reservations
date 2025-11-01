-- Скрипт заполнения базы данных до 10к элементов
DO $$
DECLARE
    i INTEGER;
    user_count INTEGER := 2000;
    event_count INTEGER := 500;
    booking_count INTEGER := 7000;
    transaction_count INTEGER := 10000;
    random_user_id INTEGER;
    random_event_id INTEGER;
    random_booking_id INTEGER;
    random_payment_method INTEGER;
    event_date TIMESTAMP;
BEGIN
    -- Очистка таблиц (если нужно)
    TRUNCATE TABLE Transactions, Bookings, Events, Users, PaymentMethods RESTART IDENTITY CASCADE;

    -- Заполнение методов оплаты
    INSERT INTO PaymentMethods (method_name, description) VALUES
    ('Наличка', 'Оплата наличными средствами'),
    ('Карта', 'Оплата банковской картой'),
    ('Онлайн', 'Онлайн перевод'),
    ('Криптовалюта', 'Оплата криптовалютой'),
    ('Мобильный', 'Мобильный платеж');

    -- Заполнение пользователей (2000)
    FOR i IN 1..user_count LOOP
        INSERT INTO Users (name, email) 
        VALUES (
            'Пользователь ' || i || ' ' || 
            CASE WHEN random() < 0.5 THEN 'Иванов' ELSE 'Петров' END,
            'user' || i || '@' || 
            CASE 
                WHEN random() < 0.3 THEN 'gmail.com'
                WHEN random() < 0.6 THEN 'yandex.ru'
                ELSE 'mail.ru'
            END
        );
    END LOOP;

    -- Заполнение событий (500)
    FOR i IN 1..event_count LOOP
        event_date := NOW() + (random() * 365 * INTERVAL '1 day');
        
        INSERT INTO Events (название, дата, место) 
        VALUES (
            CASE 
                WHEN random() < 0.2 THEN 'Концерт ' || 
                    CASE 
                        WHEN random() < 0.25 THEN 'рок-группы'
                        WHEN random() < 0.5 THEN 'джазового оркестра'
                        WHEN random() < 0.75 THEN 'симфонического оркестра'
                        ELSE 'поп-исполнителя'
                    END
                WHEN random() < 0.4 THEN 'Выставка ' || 
                    CASE 
                        WHEN random() < 0.3 THEN 'современного искусства'
                        WHEN random() < 0.6 THEN 'фотографии'
                        ELSE 'скульптуры'
                    END
                WHEN random() < 0.6 THEN 'Спектакль "' || 
                    CASE 
                        WHEN random() < 0.25 THEN 'Гамлет'
                        WHEN random() < 0.5 THEN 'Ревизор'
                        WHEN random() < 0.75 THEN 'Чайка'
                        ELSE 'Вишневый сад'
                    END || '"'
                WHEN random() < 0.8 THEN 'Конференция по ' || 
                    CASE 
                        WHEN random() < 0.3 THEN 'IT технологиям'
                        WHEN random() < 0.6 THEN 'маркетингу'
                        ELSE 'дизайну'
                    END
                ELSE 'Фестиваль ' || 
                    CASE 
                        WHEN random() < 0.5 THEN 'еды'
                        ELSE 'музыки'
                    END
            END,
            event_date,
            CASE 
                WHEN random() < 0.2 THEN 'Концертный зал ' || i
                WHEN random() < 0.4 THEN 'Театр ' || 
                    CASE 
                        WHEN random() < 0.5 THEN 'Большой'
                        ELSE 'Малый'
                    END
                WHEN random() < 0.6 THEN 'Выставочный центр ' || 
                    CASE 
                        WHEN random() < 0.5 THEN 'Северный'
                        ELSE 'Южный'
                    END
                WHEN random() < 0.8 THEN 'Кинозал ' || i
                ELSE 'Стадион ' || 
                    CASE 
                        WHEN random() < 0.5 THEN 'Центральный'
                        ELSE 'Олимпийский'
                    END
            END
        );
    END LOOP;

    -- Заполнение бронирований (7000)
    FOR i IN 1..booking_count LOOP
        random_user_id := 1 + floor(random() * user_count);
        random_event_id := 1 + floor(random() * event_count);
        
        INSERT INTO Bookings (user_id, event_id, status, date) 
        VALUES (
            random_user_id,
            random_event_id,
            CASE 
                WHEN random() < 0.7 THEN 'confirmed'
                WHEN random() < 0.85 THEN 'pending'
                WHEN random() < 0.95 THEN 'cancelled'
                ELSE 'completed'
            END,
            NOW() - (random() * 90 * INTERVAL '1 day')
        );
    END LOOP;

    -- Заполнение транзакций (10000)
    FOR i IN 1..transaction_count LOOP
        random_booking_id := 1 + floor(random() * booking_count);
        random_payment_method := 1 + floor(random() * 5);
        
        INSERT INTO Transactions (сумма, статус, booking_id, payment_method_id, время) 
        VALUES (
            ROUND((50 + random() * 1950)::numeric, 2), -- Сумма от 50 до 2000
            CASE 
                WHEN random() < 0.8 THEN 'completed'
                WHEN random() < 0.9 THEN 'pending'
                WHEN random() < 0.95 THEN 'failed'
                ELSE 'refunded'
            END,
            random_booking_id,
            random_payment_method,
            NOW() - (random() * 60 * INTERVAL '1 day')
        );
    END LOOP;


    -- Заполнение категорий (10)
    FOR i IN 1..10 LOOP
        INSERT INTO Categories (название) VALUES ('Категория ' || i);
    END LOOP;

    RAISE NOTICE 'База данных успешно заполнена!';
    RAISE NOTICE 'Пользователей: %', user_count;
    RAISE NOTICE 'Событий: %', event_count;
    RAISE NOTICE 'Бронирований: %', booking_count;
    RAISE NOTICE 'Транзакций: %', transaction_count;
END $$;
