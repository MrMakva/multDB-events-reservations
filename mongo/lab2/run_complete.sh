#!/bin/bash

echo "=== ЗАПУСК ПОЛНОЙ ВЕРСИИ ВСЕХ ЗАДАНИЙ ==="

# Проверяем MongoDB
if ! command -v mongosh &> /dev/null; then
    echo "Установите MongoDB: https://www.mongodb.com/try/download/community"
    exit 1
fi

# Запускаем MongoDB если не запущен
if ! pgrep mongod > /dev/null; then
    echo "Запуск MongoDB в фоновом режиме..."
    mongod --dbpath ~/mongodb_data --fork --logpath /tmp/mongodb_complete.log
    sleep 3
fi

echo "Выполнение всех 8 заданий MongoDB..."
echo ""

# Запускаем скрипт
mongosh --quiet complete_tasks.js

echo ""
echo "✅ ВСЕ 8 ЗАДАНИЙ ВЫПОЛНЕНЫ!"
echo ""
echo "Проверка созданных коллекций:"
mongosh --quiet --eval "
db = db.getSiblingDB('event_booking_complete');
print('База: event_booking_complete');
db.getCollectionNames().forEach(c => {
    var count = db[c].countDocuments();
    print('  • ' + c + ': ' + count + ' документов');
});
"

echo ""
echo "Для очистки: mongosh --eval \"db.getSiblingDB('event_booking_complete').dropDatabase()\""