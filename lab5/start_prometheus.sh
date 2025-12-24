#!/bin/bash

echo "=== ЗАПУСК PROMETHEUS И GRAFANA ==="
echo ""

if ! command -v docker &> /dev/null; then
    echo " Docker не установлен. Установите Docker:"
    echo "   sudo apt-get update && sudo apt-get install docker.io docker-compose"
    exit 1
fi

if [ ! -f "/tmp/prometheus_export/postgres_metrics.prom" ]; then
    echo "Сбор метрик..."
    ./collect_prometheus_metrics.sh
fi

echo "Файл метрик создан:"
ls -la /tmp/prometheus_export/postgres_metrics.prom

echo "Остановка старых контейнеров..."
docker-compose down 2>/dev/null

echo "Запуск контейнеров..."
docker-compose up -d

echo ""
echo " Ожидание запуска сервисов..."
sleep 10

echo ""
echo " ВСЕ СЕРВИСЫ ЗАПУЩЕНЫ!"
echo ""
echo "=== ДОСТУП К СЕРВИСАМ ==="
echo " Prometheus: http://localhost:9090"
echo " Grafana:    http://localhost:3000"
echo "              Логин: admin"
echo "              Пароль: admin"
echo ""
echo "=== ПРОВЕРКА МЕТРИК ==="
echo "1. Откройте Prometheus: http://localhost:9090"
echo "2. Перейдите в раздел 'Graph'"
echo "3. Введите метрику: postgres_active_connections"
echo "4. Нажмите 'Execute'"
echo ""
echo "=== НАСТРОЙКА GRAFANA ==="
echo "1. Откройте Grafana: http://localhost:3000"
echo "2. Войдите (admin/admin)"
echo "3. Добавьте источник данных:"
echo "   - Тип: Prometheus"
echo "   - URL: http://prometheus:9090"
echo "4. Создайте новый Dashboard"
echo ""
echo "=== АВТОМАТИЧЕСКИЙ СБОР МЕТРИК ==="
echo "Для автоматического обновления добавьте в crontab:"
echo "*/5 * * * * $(pwd)/collect_prometheus_metrics.sh"
echo ""
echo "Текущие контейнеры:"
docker-compose ps
echo ""
echo "Для остановки выполните: docker-compose down"