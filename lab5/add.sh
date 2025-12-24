#!/bin/bash

# Запуск: ./add.sh <длительность_в_секундах>

set -e

DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="bd"
DB_USER="postgres"
DB_PASSWORD="postgres"

DURATION=${1:-300}

echo "Начинаем нагрузочный тест PostgreSQL на $DURATION секунд..."
echo "Целевая БД: $DB_NAME"
echo "Метрики, которые будут затронуты:"
echo "  - Подключения (total/active connections)"
echo "  - WAL операции (commits/rollbacks)"
echo "  - Операции с данными (INSERT/UPDATE/DELETE)"
echo "  - Кэши (cache hit ratio)"
echo "  - Блокировки (waiting locks)"
echo "  - Размер БД"
echo ""

execute_sql() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$1" -t -q
}

echo "Создаем тестовые таблицы..."
execute_sql "
CREATE TABLE IF NOT EXISTS load_test_data (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS load_test_indexed (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    value INTEGER,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_load_test_name ON load_test_indexed(name);
CREATE INDEX IF NOT EXISTS idx_load_test_value ON load_test_indexed(value);
"

random_string() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 50
}

execute_dml_operations() {
    echo "  [DML] Выполняем операции INSERT/UPDATE/DELETE..."
    
    # INSERT операций
    for i in {1..50}; do
        execute_sql "INSERT INTO load_test_data (data) VALUES ('$(random_string)');" &
    done
    
    # UPDATE операций
    execute_sql "UPDATE load_test_data SET updated_at = NOW(), data = 'updated_$(date +%s%N)' WHERE id % 7 = 0;" &
    
    # DELETE операций (но не все, чтобы данные накапливались)
    execute_sql "DELETE FROM load_test_data WHERE id % 13 = 0 AND id > 100;" &
    
    # Вставка в индексированную таблицу
    execute_sql "INSERT INTO load_test_indexed (name, value, description) 
                 VALUES ('test_$(date +%s)', $(($RANDOM % 1000)), '$(random_string)');" &
    
    wait
}

execute_select_operations() {
    echo "  [SELECT] Выполняем сложные SELECT запросы..."
    
    for i in {1..30}; do
        execute_sql "SELECT COUNT(*) FROM load_test_data;" > /dev/null &
        execute_sql "SELECT * FROM load_test_data ORDER BY id DESC LIMIT 10;" > /dev/null &
        execute_sql "SELECT name, COUNT(*) FROM load_test_indexed GROUP BY name;" > /dev/null &
        execute_sql "SELECT * FROM load_test_indexed WHERE value BETWEEN 100 AND 200;" > /dev/null &
        execute_sql "EXPLAIN ANALYZE SELECT * FROM load_test_data WHERE data LIKE '%test%';" > /dev/null &
    done
    
    wait
}

execute_lock_operations() {
    echo "  [LOCK] Создаем блокировки..."

    execute_sql "BEGIN;
                 LOCK TABLE load_test_data IN EXCLUSIVE MODE;
                 SELECT pg_sleep(0.5);
                 COMMIT;" &

    execute_sql "BEGIN;
                 SELECT * FROM load_test_indexed FOR UPDATE;
                 SELECT pg_sleep(0.3);
                 COMMIT;" &
}

create_connections() {
    echo "  [CONNECTIONS] Создаем множественные подключения..."
    
    for i in {1..20}; do
        (
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
                -c "SELECT pg_sleep(0.$((i % 10))); SELECT 1;" > /dev/null 2>&1 &
        ) &
    done
}

execute_rollback_operations() {
    echo "  [ROLLBACK] Выполняем операции с откатом..."

    for i in {1..5}; do
        execute_sql "BEGIN;
                     INSERT INTO load_test_data (data) VALUES ('rollback_test_$i');
                     -- Преднамеренная ошибка
                     INSERT INTO nonexistent_table VALUES (1);
                     COMMIT;" 2>/dev/null &
        
        execute_sql "BEGIN;
                     INSERT INTO load_test_data (data) VALUES ('rollback_test2_$i');
                     ROLLBACK;" &
    done
    
    wait
}

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
CYCLE=0

echo "Запускаем цикл нагрузочного теста..."
echo "Будет выполнено примерно $((DURATION / 10)) циклов нагрузки"
echo ""

while [ $(date +%s) -lt $END_TIME ]; do
    CYCLE=$((CYCLE + 1))
    CURRENT_TIME=$(date +%s)
    TIME_LEFT=$((END_TIME - CURRENT_TIME))
    
    echo "=== Цикл $CYCLE (осталось $TIME_LEFT секунд) ==="

    execute_dml_operations &
    PID1=$!
    
    execute_select_operations &
    PID2=$!
    
    create_connections &
    PID3=$!

    if [ $((CYCLE % 3)) -eq 0 ]; then
        execute_lock_operations &
        PID4=$!
    fi
    
    if [ $((CYCLE % 5)) -eq 0 ]; then
        execute_rollback_operations &
        PID5=$!
    fi
    
    wait $PID1 $PID2 $PID3

    sleep 2

    if [ $((CYCLE % 5)) -eq 0 ]; then
        echo ""
        echo "Текущая статистика:"
        execute_sql "
        SELECT 
            (SELECT COUNT(*) FROM load_test_data) as total_rows,
            (SELECT COUNT(*) FROM load_test_indexed) as indexed_rows,
            (SELECT pg_database_size('$DB_NAME') / 1024 / 1024) as db_size_mb;
        "
        echo ""
    fi
done

echo ""
echo "========================================="
echo "Нагрузочный тест завершен!"
echo "Всего выполнено циклов: $CYCLE"
echo ""

echo "Финальная статистика БД:"
execute_sql "
SELECT 
    'load_test_data' as table_name, 
    COUNT(*) as row_count 
FROM load_test_data
UNION ALL
SELECT 
    'load_test_indexed' as table_name, 
    COUNT(*) as row_count 
FROM load_test_indexed;

SELECT 
    'Размер БД' as metric,
    pg_database_size('$DB_NAME') as bytes,
    pg_database_size('$DB_NAME') / 1024 / 1024 as mb;
"

echo ""
echo "Теперь проверьте метрики в Prometheus:"
echo "1. postgres_system_active_connections - должно быть больше 1"
echo "2. postgres_wal_total_commits - должно значительно увеличиться"
echo "3. postgres_db_tuples_inserted/updated/deleted - должны увеличиться"
echo "4. postgres_system_waiting_locks - могут быть кратковременные блокировки"
echo "5. postgres_database_size_bytes - должен увеличиться"
echo ""

# Очистка (опционально, закомментируйте если хотите сохранить данные)
# echo "Очищаем тестовые данные..."
# execute_sql "DROP TABLE IF EXISTS load_test_data; DROP TABLE IF EXISTS load_test_indexed;"