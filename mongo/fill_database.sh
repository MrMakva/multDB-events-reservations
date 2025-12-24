#!/bin/bash

echo "=== ЗАПОЛНЕНИЕ БАЗЫ ДАННЫХ ТЕСТОВЫМИ ДАННЫМИ ==="

if ! pgrep mongod > /dev/null; then
    echo "Ошибка: MongoDB не запущен"
    echo "Запустите MongoDB командой:"
    echo "mongod --dbpath ~/mongo_data --fork --logpath ~/mongo.log"
    exit 1
fi

echo "1. Создание базы данных и коллекций..."
mongosh --quiet << 'EOF'
use event_booking_system
db.dropDatabase()

// Создаем коллекции
db.createCollection("events")
db.createCollection("users")
db.createCollection("bookings")
db.createCollection("reviews")
db.createCollection("venues")
db.createCollection("organizers")

print("✓ Коллекции созданы")
EOF

echo "2. Генерация тестовых данных..."
mongosh --quiet << 'EOF'
use event_booking_system

print("Добавление организаторов...")
db.organizers.insertMany([
    {
        name: "Кремлевские концерты",
        email: "kremlin@concerts.ru",
        phone: "+74951234567",
        description: "Организация концертов в Кремле"
    },
    {
        name: "Спорт-арена",
        email: "info@sport-arena.ru",
        phone: "+74959876543",
        description: "Организация спортивных мероприятий"
    }
])

print("Добавление мест проведения...")
db.venues.insertMany([
    {
        name: "Кремлевский дворец",
        address: "Москва, Кремль",
        capacity: 6000
    },
    {
        name: "Стадион Лужники", 
        address: "Москва, Лужнецкая наб., 24",
        capacity: 81000
    }
])

print("Добавление пользователей...")
db.users.insertMany([
    {
        email: "ivan.ivanov@example.com",
        name: "Иван Иванов",
        phone: "+79161234567",
        stats: {
            total_bookings: 2,
            total_spent: 25000
        }
    },
    {
        email: "maria.petrova@example.com", 
        name: "Мария Петрова",
        phone: "+79167654321",
        stats: {
            total_bookings: 1,
            total_spent: 15000
        }
    }
])

print("Добавление мероприятий...")
db.events.insertMany([
    {
        title: "Новогодний концерт в Кремле",
        description: "Гала-концерт с участием звезд эстрады",
        date: new Date("2024-12-31T21:00:00Z"),
        venue_id: db.venues.findOne({name: "Кремлевский дворец"})._id,
        organizer_id: db.organizers.findOne({name: "Кремлевские концерты"})._id,
        categories: ["концерт", "новогодний"],
        status: "published",
        capacity: 800,
        available_seats: 650
    },
    {
        title: "Футбольный матч: Россия - Германия", 
        description: "Товарищеский матч сборных",
        date: new Date("2024-12-20T19:00:00Z"),
        venue_id: db.venues.findOne({name: "Стадион Лужники"})._id,
        organizer_id: db.organizers.findOne({name: "Спорт-арена"})._id,
        categories: ["спорт", "футбол"],
        status: "published",
        capacity: 1000,
        available_seats: 850
    }
])

print("Добавление бронирований...")
var event1 = db.events.findOne({title: "Новогодний концерт в Кремле"})
var event2 = db.events.findOne({title: "Футбольный матч: Россия - Германия"})
var user1 = db.users.findOne({email: "ivan.ivanov@example.com"})
var user2 = db.users.findOne({email: "maria.petrova@example.com"})

db.bookings.insertMany([
    {
        user_id: user1._id,
        event_id: event1._id,
        ticket_type: "Standard",
        quantity: 2,
        total_amount: 10000,
        status: "confirmed",
        payment_method: "card"
    },
    {
        user_id: user1._id,
        event_id: event2._id, 
        ticket_type: "VIP",
        quantity: 1,
        total_amount: 15000,
        status: "confirmed",
        payment_method: "online"
    },
    {
        user_id: user2._id,
        event_id: event1._id,
        ticket_type: "Standard",
        quantity: 1,
        total_amount: 5000,
        status: "confirmed",
        payment_method: "cash"
    }
])

print("Добавление отзывов...")
db.reviews.insertMany([
    {
        event_id: event1._id,
        user_id: user1._id,
        rating: 5,
        comment: "Отличный концерт! Организация на высшем уровне."
    },
    {
        event_id: event2._id,
        user_id: user1._id,
        rating: 4,
        comment: "Хороший матч, но было холодно на стадионе."
    }
])

print("✓ Все данные добавлены")
EOF

echo "3. Проверка данных..."
mongosh --quiet << 'EOF'
use event_booking_system

print("=== СВОДКА ДАННЫХ ===")

var collections = ["organizers", "venues", "users", "events", "bookings", "reviews"]
collections.forEach(function(col) {
    var count = db[col].countDocuments()
    print(col + ": " + count + " документов")
})

print("\n=== ПРИМЕРЫ ДАННЫХ ===")

print("Мероприятия:")
db.events.find({}, {title: 1, date: 1, categories: 1, available_seats: 1}).forEach(printjson)

print("\nПользователи:")
db.users.find({}, {name: 1, email: 1, "stats.total_bookings": 1}).forEach(printjson)

print("\nБронирования:")
db.bookings.find({}, {ticket_type: 1, quantity: 1, total_amount: 1, status: 1}).forEach(printjson)

print("\n✓ База данных успешно заполнена!")
EOF

echo ""
echo "=== ГОТОВО ==="
echo "База данных 'event_booking_system' заполнена тестовыми данными."
echo ""
echo "Для проверки подключитесь к MongoDB:"
echo "mongosh event_booking_system"
echo ""
echo "Примеры команд:"
echo "show collections"
echo "db.events.find().pretty()"
echo "db.users.find().pretty()"
echo "db.bookings.count()"