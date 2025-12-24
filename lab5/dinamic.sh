#!/bin/bash
# dynamic_metrics_collector.sh

DB_NAME="bd"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_HOST="localhost"
DB_PORT="5432"
PROMETHEUS_FILE="/tmp/prometheus_export/postgres_metrics.prom"

echo "Запуск динамического сбора метрик PostgreSQL"
echo "База данных: $DB_NAME@$DB_HOST:$DB_PORT"
echo "Файл метрик: $PROMETHEUS_FILE"
echo "Для остановки нажмите Ctrl+C"
echo ""

mkdir -p /tmp/prometheus_export
chmod 777 /tmp/prometheus_export 2>/dev/null || true

execute_query() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$1" 2>/dev/null || echo "0"
}

COUNTER=0

while true; do
    COUNTER=$((COUNTER + 1))
    CURRENT_TIME=$(date '+%H:%M:%S')
    
    echo "=== Цикл $COUNTER ($CURRENT_TIME) ==="

    echo "Получаем метрики из PostgreSQL..."
    ACTIVE=$(execute_query "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND state = 'active';")
    TOTAL_CONN=$(execute_query "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$DB_NAME';")
    CACHE_HIT=$(execute_query "SELECT ROUND(COALESCE(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 0), 2) FROM pg_stat_database WHERE datname = '$DB_NAME';")
    DB_SIZE=$(execute_query "SELECT pg_database_size('$DB_NAME');")
    COMMITS=$(execute_query "SELECT xact_commit FROM pg_stat_database WHERE datname = '$DB_NAME';")
    ROLLBACKS=$(execute_query "SELECT xact_rollback FROM pg_stat_database WHERE datname = '$DB_NAME';")
    WAITING_LOCKS=$(execute_query "SELECT COUNT(*) FROM pg_locks WHERE NOT granted;")
    DEAD_TUPLES=$(execute_query "SELECT COALESCE(SUM(n_dead_tup), 0) FROM pg_stat_all_tables WHERE schemaname NOT LIKE 'pg_%';")
    INSERTED=$(execute_query "SELECT tup_inserted FROM pg_stat_database WHERE datname = '$DB_NAME';")
    UPDATED=$(execute_query "SELECT tup_updated FROM pg_stat_database WHERE datname = '$DB_NAME';")

    TEST_COUNTER=$COUNTER
    LOAD_AVERAGE=$(cat /proc/loadavg | cut -d' ' -f1 2>/dev/null || echo "0.0")

    cat > $PROMETHEUS_FILE << METRICS
# HELP postgres_active_connections Number of active connections
# TYPE postgres_active_connections gauge
postgres_active_connections{database="$DB_NAME"} $ACTIVE

# HELP postgres_total_connections Total number of connections
# TYPE postgres_total_connections gauge
postgres_total_connections{database="$DB_NAME"} $TOTAL_CONN

# HELP postgres_cache_hit_ratio Cache hit ratio percentage
# TYPE postgres_cache_hit_ratio gauge
postgres_cache_hit_ratio{database="$DB_NAME"} $CACHE_HIT

# HELP postgres_database_size_bytes Database size in bytes
# TYPE postgres_database_size_bytes gauge
postgres_database_size_bytes{database="$DB_NAME"} $DB_SIZE

# HELP postgres_total_commits Total number of commits
# TYPE postgres_total_commits counter
postgres_total_commits{database="$DB_NAME"} $COMMITS

# HELP postgres_total_rollbacks Total number of rollbacks
# TYPE postgres_total_rollbacks counter
postgres_total_rollbacks{database="$DB_NAME"} $ROLLBACKS

# HELP postgres_waiting_locks Number of waiting locks
# TYPE postgres_waiting_locks gauge
postgres_waiting_locks{database="$DB_NAME"} $WAITING_LOCKS

# HELP postgres_dead_tuples Number of dead tuples
# TYPE postgres_dead_tuples gauge
postgres_dead_tuples{database="$DB_NAME"} $DEAD_TUPLES

# HELP postgres_tuples_inserted Number of tuples inserted
# TYPE postgres_tuples_inserted counter
postgres_tuples_inserted{database="$DB_NAME"} $INSERTED

# HELP postgres_tuples_updated Number of tuples updated
# TYPE postgres_tuples_updated counter
postgres_tuples_updated{database="$DB_NAME"} $UPDATED

# HELP postgres_tuples_deleted Number of tuples deleted
# TYPE postgres_tuples_deleted counter
postgres_tuples_deleted{database="$DB_NAME"} $DELETED

# HELP postgres_test_counter Test counter that always increases
# TYPE postgres_test_counter counter
postgres_test_counter{database="$DB_NAME"} $TEST_COUNTER

# HELP postgres_cycle_counter Cycle counter for debugging
# TYPE postgres_cycle_counter counter
postgres_cycle_counter{database="$DB_NAME"} $COUNTER

# HELP postgres_load_average System load average
# TYPE postgres_load_average gauge
postgres_load_average{database="$DB_NAME"} $LOAD_AVERAGE

# HELP postgres_metrics_update_time Time of last metrics update
# TYPE postgres_metrics_update_time gauge
postgres_metrics_update_time{database="$DB_NAME"} $(date +%s)
METRICS

    if [ -f "$PROMETHEUS_FILE" ]; then
        FILE_SIZE=$(wc -l < "$PROMETHEUS_FILE")
        echo "   Файл создан ($FILE_SIZE строк)"
        echo "   Активные подключения: $ACTIVE"
        echo "   Всего подключений: $TOTAL_CONN"
        echo "   Коммиты: $COMMITS"
        echo "   Тестовый счетчик: $TEST_COUNTER"
        echo "   Время: $(date '+%H:%M:%S')"

        if command -v docker >/dev/null 2>&1 && docker ps | grep -q node-exporter; then
            echo "   Проверка Docker контейнера..."
            if docker exec node-exporter ls /custom_metrics/postgres_metrics.prom >/dev/null 2>&1; then
                echo " Файл доступен в контейнере"
            else
                echo " Файл НЕ доступен в контейнере"
            fi
        fi
    else
        echo "Ошибка: файл не создан!"
        echo "   Проверьте права на запись в /tmp/prometheus_export/"
        ls -la /tmp/prometheus_export/ 2>/dev/null || echo "Директория не существует"
    fi
    
    echo ""
    
    # Ждем 5 секунд перед следующим обновлением
    sleep 5
done