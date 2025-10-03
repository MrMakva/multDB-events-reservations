#!/bin/bash

echo "=== COMPREHENSIVE REQUIREMENTS CHECK ==="
echo ""

DB_NAME="event_booking"

# Function to run check and show result
run_check() {
    local description=$1
    local query=$2
    echo "🔍 $description"
    if sudo -u postgres psql -d $DB_NAME -c "$query" 2>/dev/null; then
        echo "✅ Успешно"
    else
        echo "❌ Ошибка"
    fi
    echo ""
}

echo "1. ПРОВЕРКА СТРУКТУРЫ БАЗЫ ДАННЫХ"
echo "================================="

run_check "Количество таблиц" "
SELECT COUNT(*) as total_tables 
FROM information_schema.tables 
WHERE table_schema = 'public';"

run_check "Список всех таблиц" "
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;"

echo "2. ПРОВЕРКА ОБЪЕМА ДАННЫХ"
echo "=========================="

run_check "Количество записей в таблицах" "
SELECT 
    relname as table_name,
    n_live_tup as row_count
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;"

run_check "Проверка главной таблицы Bookings (должно быть 3-3.5 млн)" "
SELECT 
    COUNT(*) as bookings_count,
    CASE 
        WHEN COUNT(*) BETWEEN 3000000 AND 3500000 THEN '✅ ТРЕБОВАНИЕ ВЫПОЛНЕНО'
        ELSE '❌ НЕ СООТВЕТСТВУЕТ ТРЕБОВАНИЯМ'
    END as status
FROM bookings;"

echo "3. ПРОВЕРКА БИЗНЕС-ЗАПРОСОВ"
echo "============================"

echo "3.1 АГРЕГИРУЮЩИЕ ЗАПРОСЫ (3-5)"
echo "-------------------------------"

run_check "Агрегирующий запрос 1: Общая статистика по мероприятиям" "
SELECT 
    COUNT(*) as total_events,
    SUM(b.total_amount) as total_revenue,
    AVG(b.total_amount) as avg_booking_value,
    MAX(b.total_amount) as max_booking,
    MIN(b.total_amount) as min_booking
FROM events e
JOIN bookings b ON e.event_id = b.event_id
WHERE b.status_id = 2;"

run_check "Агрегирующий запрос 2: Статистика по типам билетов" "
SELECT 
    tt.name as ticket_type,
    COUNT(b.booking_id) as bookings_count,
    AVG(b.total_amount) as avg_amount,
    SUM(b.total_amount) as total_revenue
FROM tickettypes tt
JOIN bookings b ON tt.ticket_type_id = b.ticket_type_id
GROUP BY tt.ticket_type_id, tt.name;"

run_check "Агрегирующий запрос 3: Ежемесячная статистика" "
SELECT 
    DATE_TRUNC('month', b.booking_date) as month,
    COUNT(b.booking_id) as total_bookings,
    SUM(b.total_amount) as monthly_revenue,
    AVG(b.total_amount) as avg_booking_value
FROM bookings b
WHERE b.status_id = 2
GROUP BY DATE_TRUNC('month', b.booking_date)
ORDER BY month
LIMIT 12;"

run_check "Агрегирующий запрос 4: Статистика по организаторам" "
SELECT 
    o.name as organizer,
    COUNT(e.event_id) as events_count,
    COUNT(b.booking_id) as total_bookings,
    SUM(b.total_amount) as total_revenue
FROM organizers o
LEFT JOIN events e ON o.organizer_id = e.organizer_id
LEFT JOIN bookings b ON e.event_id = b.event_id AND b.status_id = 2
GROUP BY o.organizer_id, o.name
ORDER BY total_revenue DESC;"

run_check "Агрегирующий запрос 5: Статистика по местам" "
SELECT 
    v.name as venue,
    s.section,
    COUNT(b.booking_id) as bookings_count,
    ROUND(COUNT(b.booking_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM bookings WHERE EXISTS (
        SELECT 1 FROM events e2 WHERE e2.event_id = bookings.event_id AND e2.venue_id = v.venue_id
    )), 0), 2) as percentage
FROM venues v
JOIN seats s ON v.venue_id = s.venue_id
LEFT JOIN bookings b ON s.seat_id = b.seat_id
GROUP BY v.venue_id, v.name, s.section
ORDER BY v.name, bookings_count DESC
LIMIT 10;"

echo "3.2 ОКОННЫЕ ФУНКЦИИ (3-5)"
echo "--------------------------"

run_check "Оконная функция 1: Ранжирование пользователей по тратам" "
SELECT 
    u.email,
    SUM(b.total_amount) as total_spent,
    RANK() OVER (ORDER BY SUM(b.total_amount) DESC) as spending_rank,
    NTILE(4) OVER (ORDER BY SUM(b.total_amount) DESC) as spending_quartile
FROM users u
JOIN bookings b ON u.user_id = b.user_id
WHERE b.status_id = 2
GROUP BY u.user_id, u.email
ORDER BY total_spent DESC
LIMIT 10;"

run_check "Оконная функция 2: Скользящее среднее выручки" "
SELECT 
    DATE(transaction_time) as day,
    SUM(amount) as daily_revenue,
    AVG(SUM(amount)) OVER (
        ORDER BY DATE(transaction_time) 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as weekly_avg_revenue
FROM transactions
WHERE status = 'completed'
GROUP BY DATE(transaction_time)
ORDER BY day
LIMIT 15;"

run_check "Оконная функция 3: Рейтинг мероприятий по организаторам" "
SELECT 
    o.name as organizer,
    e.title as event,
    COUNT(b.booking_id) as bookings_count,
    RANK() OVER (PARTITION BY e.organizer_id ORDER BY COUNT(b.booking_id) DESC) as rank_in_organizer,
    LAG(COUNT(b.booking_id)) OVER (PARTITION BY e.organizer_id ORDER BY COUNT(b.booking_id) DESC) as prev_booking_count
FROM events e
JOIN organizers o ON e.organizer_id = o.organizer_id
JOIN bookings b ON e.event_id = b.event_id
GROUP BY o.organizer_id, o.name, e.event_id, e.title
ORDER BY o.name, bookings_count DESC
LIMIT 15;"

run_check "Оконная функция 4: Кумулятивная выручка" "
SELECT 
    DATE_TRUNC('month', transaction_time) as month,
    SUM(amount) as monthly_revenue,
    SUM(SUM(amount)) OVER (ORDER BY DATE_TRUNC('month', transaction_time)) as cumulative_revenue
FROM transactions
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', transaction_time)
ORDER BY month
LIMIT 12;"

run_check "Оконная функция 5: Сравнение с средним по организатору" "
SELECT 
    e.title,
    o.name as organizer,
    SUM(t.amount) as event_revenue,
    AVG(SUM(t.amount)) OVER (PARTITION BY e.organizer_id) as avg_organizer_revenue,
    SUM(t.amount) - AVG(SUM(t.amount)) OVER (PARTITION BY e.organizer_id) as difference_from_avg
FROM events e
JOIN organizers o ON e.organizer_id = o.organizer_id
JOIN bookings b ON e.event_id = b.event_id
JOIN transactions t ON b.booking_id = t.booking_id
WHERE t.status = 'completed'
GROUP BY e.event_id, e.title, o.organizer_id, o.name
ORDER BY o.name, event_revenue DESC
LIMIT 10;"

echo "3.3 ЗАПРОСЫ С ОБЪЕДИНЕНИЕМ ТАБЛИЦ"
echo "================================="

echo "2 ТАБЛИЦЫ (2 запроса):"
run_check "Объединение 2 таблиц 1: Пользователи + Бронирования" "
SELECT 
    u.user_id,
    u.email,
    u.first_name,
    u.last_name,
    COUNT(b.booking_id) as total_bookings,
    MAX(b.booking_date) as last_booking_date
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
GROUP BY u.user_id, u.email, u.first_name, u.last_name
ORDER BY total_bookings DESC
LIMIT 10;"

run_check "Объединение 2 таблиц 2: Мероприятия + Отзывы" "
SELECT 
    e.event_id,
    e.title,
    e.event_date,
    ROUND(AVG(r.rating), 2) as avg_rating,
    COUNT(r.review_id) as reviews_count
FROM events e
LEFT JOIN reviews r ON e.event_id = r.event_id
GROUP BY e.event_id, e.title, e.event_date
HAVING COUNT(r.review_id) >= 1
ORDER BY avg_rating DESC
LIMIT 10;"

echo "3 ТАБЛИЦЫ (4 запроса):"
run_check "Объединение 3 таблиц 1: Бронирования + Пользователи + Мероприятия" "
SELECT 
    b.booking_id,
    u.first_name || ' ' || u.last_name as user_name,
    e.title as event_name,
    bs.name as status,
    b.total_amount
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN events e ON b.event_id = e.event_id
JOIN bookingstatus bs ON b.status_id = bs.status_id
ORDER BY b.booking_date DESC
LIMIT 10;"

run_check "Объединение 3 таблиц 2: Транзакции + Бронирования + Пользователи" "
SELECT 
    t.transaction_id,
    b.booking_id,
    u.email,
    pm.name as payment_method,
    t.amount,
    t.transaction_time
FROM transactions t
JOIN bookings b ON t.booking_id = b.booking_id
JOIN users u ON b.user_id = u.user_id
JOIN paymentmethods pm ON t.method_id = pm.method_id
WHERE t.status = 'completed'
ORDER BY t.transaction_time DESC
LIMIT 10;"

run_check "Объединение 3 таблиц 3: Отзывы + Пользователи + Мероприятия" "
SELECT 
    r.review_id,
    u.first_name || ' ' || u.last_name as user_name,
    e.title as event_name,
    r.rating,
    r.comment,
    r.created_at
FROM reviews r
JOIN users u ON r.user_id = u.user_id
JOIN events e ON r.event_id = e.event_id
WHERE r.rating >= 4
ORDER BY r.created_at DESC
LIMIT 10;"

run_check "Объединение 3 таблиц 4: Возвраты + Транзакции + Бронирования" "
SELECT 
    rf.refund_id,
    t.transaction_id,
    b.booking_id,
    rf.refund_amount,
    rf.refund_reason,
    rf.processed_at
FROM refunds rf
JOIN transactions t ON rf.transaction_id = t.transaction_id
JOIN bookings b ON t.booking_id = b.booking_id
WHERE rf.status = 'processed'
ORDER BY rf.processed_at DESC
LIMIT 10;"

echo "4 ТАБЛИЦЫ (1 запрос):"
run_check "Объединение 4 таблиц: Бронирования + Пользователи + Мероприятия + Места" "
SELECT 
    b.booking_id,
    u.email,
    e.title as event_name,
    v.name as venue_name,
    s.seat_row || '-' || s.seat_number as seat_location,
    s.section,
    tt.name as ticket_type,
    b.total_amount,
    b.booking_date
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN events e ON b.event_id = e.event_id
JOIN venues v ON e.venue_id = v.venue_id
JOIN seats s ON b.seat_id = s.seat_id
JOIN tickettypes tt ON b.ticket_type_id = tt.ticket_type_id
WHERE b.status_id = 2
ORDER BY e.event_date, s.seat_row, s.seat_number
LIMIT 10;"

echo "5 ТАБЛИЦ (1 запрос):"
run_check "Объединение 5 таблиц: Полная аналитика мероприятий" "
SELECT 
    e.event_id,
    e.title,
    o.name as organizer,
    v.name as venue,
    v.city,
    e.event_date,
    COUNT(DISTINCT b.booking_id) as total_bookings,
    COUNT(DISTINCT r.review_id) as total_reviews,
    ROUND(AVG(r.rating), 2) as avg_rating,
    SUM(t.amount) as total_revenue,
    COUNT(DISTINCT CASE WHEN bs.name = 'cancelled' THEN b.booking_id END) as cancelled_bookings
FROM events e
JOIN organizers o ON e.organizer_id = o.organizer_id
JOIN venues v ON e.venue_id = v.venue_id
LEFT JOIN bookings b ON e.event_id = b.event_id
LEFT JOIN bookingstatus bs ON b.status_id = bs.status_id
LEFT JOIN transactions t ON b.booking_id = t.booking_id AND t.status = 'completed'
LEFT JOIN reviews r ON e.event_id = r.event_id
GROUP BY e.event_id, e.title, o.name, v.name, v.city, e.event_date
HAVING COUNT(DISTINCT b.booking_id) > 0
ORDER BY total_revenue DESC
LIMIT 10;"

echo "4. ПРОВЕРКА 'ЖИВЫХ' ДАННЫХ"
echo "==========================="

run_check "Проверка связей между таблицами" "
SELECT 
    'Users → Bookings' as relation,
    COUNT(DISTINCT u.user_id) as total_users,
    COUNT(DISTINCT b.user_id) as users_with_bookings,
    ROUND(COUNT(DISTINCT b.user_id) * 100.0 / COUNT(DISTINCT u.user_id), 2) as percentage
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id

UNION ALL

SELECT 
    'Events → Bookings',
    COUNT(DISTINCT e.event_id),
    COUNT(DISTINCT b.event_id),
    ROUND(COUNT(DISTINCT b.event_id) * 100.0 / COUNT(DISTINCT e.event_id), 2)
FROM events e
LEFT JOIN bookings b ON e.event_id = b.event_id

UNION ALL

SELECT 
    'Bookings → Transactions',
    COUNT(DISTINCT b.booking_id),
    COUNT(DISTINCT t.booking_id),
    ROUND(COUNT(DISTINCT t.booking_id) * 100.0 / COUNT(DISTINCT b.booking_id), 2)
FROM bookings b
LEFT JOIN transactions t ON b.booking_id = t.booking_id;"

echo "=== ПРОВЕРКА ЗАВЕРШЕНА ==="
