#!/bin/bash
# add_dead_tuples.sh

DB_NAME="bd"
LOG_FILE="/tmp/add_dead_tuples_$(date +%Y%m%d_%H%M%S).log"

echo "=== ADDING DEAD TUPLES TO DATABASE: $DB_NAME ===" > $LOG_FILE
echo "Started: $(date)" >> $LOG_FILE

# Проверяем текущее состояние до изменений
echo -e "\n--- CURRENT STATE (BEFORE) ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    relname as table_name,
    n_live_tup as live,
    n_dead_tup as dead,
    round(n_dead_tup::numeric / greatest(n_live_tup + n_dead_tup, 1) * 100, 1) as dead_percent
FROM pg_stat_all_tables 
WHERE schemaname = 'public'
AND n_live_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 10;" >> $LOG_FILE

# Выполняем SQL для создания мертвых строк
echo -e "\n--- EXECUTING DEAD TUPLES GENERATION ---" >> $LOG_FILE
psql -d $DB_NAME -f add_dead_tuples_to_bd.sql >> $LOG_FILE 2>&1

# Ждем обновления статистики
echo -e "\n--- WAITING FOR STATISTICS UPDATE ---" >> $LOG_FILE
sleep 5

# Проверяем состояние после изменений
echo -e "\n--- FINAL STATE (AFTER) ---" >> $LOG_FILE
psql -d $DB_NAME -c "
SELECT 
    relname as table_name,
    n_live_tup as live,
    n_dead_tup as dead,
    round(n_dead_tup::numeric / greatest(n_live_tup + n_dead_tup, 1) * 100, 1) as dead_percent,
    CASE 
        WHEN last_autovacuum IS NULL THEN 'NEVER'
        ELSE to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI')
    END as last_autovacuum
FROM pg_stat_all_tables 
WHERE schemaname = 'public'
AND n_live_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 10;" >> $LOG_FILE

echo -e "\n=== DEAD TUPLES ADDITION COMPLETE ===" >> $LOG_FILE
echo "Log saved: $LOG_FILE"

# Показываем краткий результат
echo ""
echo "✅ Dead tuples added to database: $DB_NAME"
echo "📊 Full log: $LOG_FILE"
echo ""
echo "Quick check:"
psql -d $DB_NAME -c "
SELECT 
    relname as table,
    n_dead_tup as dead_tuples,
    round(n_dead_tup::numeric / greatest(n_live_tup + n_dead_tup, 1) * 100, 1) as dead_percent
FROM pg_stat_all_tables 
WHERE schemaname = 'public' 
AND n_dead_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 5;"
