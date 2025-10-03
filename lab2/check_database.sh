#!/bin/bash

echo "=== Database Verification Script ==="

DB_NAME="event_booking"

echo "1. Checking database structure..."
sudo -u postgres psql -d $DB_NAME -c "
-- Check tables existence
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
"

echo ""
echo "2. Checking row counts..."
sudo -u postgres psql -d $DB_NAME -c "
SELECT 
    schemaname,
    relname as table_name,
    n_live_tup as row_count
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;
"

echo ""
echo "3. Checking table sizes..."
sudo -u postgres psql -d $DB_NAME -c "
SELECT 
    table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as total_size,
    pg_size_pretty(pg_relation_size(quote_ident(table_name))) as table_size,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name)) - pg_relation_size(quote_ident(table_name))) as index_size
FROM information_schema.tables 
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY pg_total_relation_size(quote_ident(table_name)) DESC;
"

echo ""
echo "4. Sample data from each table:"
echo "--- Users (first 3 records) ---"
sudo -u postgres psql -d $DB_NAME -c "SELECT user_id, email, first_name, last_name FROM users LIMIT 3;"

echo ""
echo "--- Events (first 3 records) ---"
sudo -u postgres psql -d $DB_NAME -c "SELECT event_id, title, event_date, base_price FROM events LIMIT 3;"

echo ""
echo "--- Bookings (first 3 records) ---"
sudo -u postgres psql -d $DB_NAME -c "SELECT booking_id, user_id, event_id, status, total_amount FROM bookings LIMIT 3;"

echo ""
echo "--- Transactions (first 3 records) ---"
sudo -u postgres psql -d $DB_NAME -c "SELECT transaction_id, booking_id, amount, status FROM transactions LIMIT 3;"

echo ""
echo "--- Reviews (first 3 records) ---"
sudo -u postgres psql -d $DB_NAME -c "SELECT review_id, event_id, user_id, rating FROM reviews LIMIT 3;"
