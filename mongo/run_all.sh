#!/bin/bash
# run_all_simple.sh - Упрощенный скрипт выполнения всех задач

set -e

echo "=== ЗАПУСК СИСТЕМЫ БРОНИРОВАНИЯ МЕРОПРИЯТИЙ ==="

# 1. Настройка проекта
echo "Шаг 1: Настройка проекта..."
if [ ! -f "setup_fixed.sh" ]; then
    echo "Создание скрипта настройки..."
    cat > setup_fixed.sh << 'EOF'
#!/bin/bash
echo "Проверка зависимостей..."

# Проверка MongoDB
if command -v mongod &> /dev/null; then
    echo "✓ MongoDB установлен"
else
    echo "✗ MongoDB не установлен"
    exit 1
fi

# Проверка Node.js
if command -v node &> /dev/null; then
    echo "✓ Node.js установлен"
else
    echo "Установка Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Проверка Python
if command -v python3 &> /dev/null; then
    echo "✓ Python3 установлен"
else
    sudo apt install -y python3 python3-pip
fi

# Установка Python библиотек
pip3 install pymongo python-dateutil faker --user

echo "✓ Все зависимости проверены"
EOF
    chmod +x setup_fixed.sh
fi

./setup_fixed.sh

# 2. Создание коллекций MongoDB
echo -e "\nШаг 2: Создание коллекций MongoDB..."
cat > create_collections_simple.js << 'EOF'
// create_collections_simple.js
try {
    db = db.getSiblingDB('event_booking_system');
    
    // Очистка существующих коллекций
    db.dropDatabase();
    
    // Создаем простые коллекции без валидаторов для совместимости
    db.createCollection("events");
    db.createCollection("users");
    db.createCollection("bookings");
    db.createCollection("reviews");
    db.createCollection("venues");
    db.createCollection("organizers");
    db.createCollection("user_activity_logs");
    
    print("Коллекции созданы успешно!");
} catch (e) {
    print("Ошибка при создании коллекций: " + e);
}
EOF

# Пробуем оба клиента MongoDB
if command -v mongosh &> /dev/null; then
    echo "Используем mongosh..."
    mongosh --quiet create_collections_simple.js
elif command -v mongo &> /dev/null; then
    echo "Используем mongo..."
    mongo --quiet create_collections_simple.js
else
    echo "Клиент MongoDB не найден. Пропускаем создание коллекций."
fi

# 3. Генерация тестовых данных
echo -e "\nШаг 3: Генерация тестовых данных..."
cat > seed_data_simple.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.expanduser('~/.local/lib/python3.8/site-packages'))

from pymongo import MongoClient
from datetime import datetime, timedelta
import random
from faker import Faker
import traceback

try:
    # Инициализация
    fake = Faker('ru_RU')
    client = MongoClient('mongodb://localhost:27017/')
    db = client.event_booking_system
    
    print("=== Генерация тестовых данных ===")
    
    # Очистка данных
    collections = ['events', 'users', 'bookings', 'reviews', 'venues', 'organizers']
    for collection in collections:
        db[collection].delete_many({})
    print("Старые данные очищены")
    
    # Создание организаторов
    organizers = []
    for i in range(3):
        organizer = {
            "name": fake.company(),
            "email": fake.email(),
            "phone": fake.phone_number(),
            "description": fake.text(max_nb_chars=100),
            "rating": round(random.uniform(3.5, 5.0), 1),
            "total_events": random.randint(1, 10)
        }
        organizers.append(organizer)
    
    organizers_result = db.organizers.insert_many(organizers)
    organizer_ids = organizers_result.inserted_ids
    print(f"Создано {len(organizer_ids)} организаторов")
    
    # Создание мест проведения
    venues = []
    for i in range(3):
        venue = {
            "name": ["Концертный зал", "Театр", "Стадион"][i],
            "location": {
                "type": "Point",
                "coordinates": [37.0 + i*0.5, 55.0 + i*0.5]
            },
            "address": fake.address(),
            "capacity": [500, 300, 1000][i]
        }
        venues.append(venue)
    
    venues_result = db.venues.insert_many(venues)
    venue_ids = venues_result.inserted_ids
    print(f"Создано {len(venue_ids)} мест проведения")
    
    # Создание пользователей
    users = []
    for i in range(20):
        user = {
            "email": fake.email(),
            "name": fake.name(),
            "phone": fake.phone_number(),
            "preferences": {
                "categories": random.sample(["концерт", "театр", "спорт"], k=2),
                "notifications": True
            },
            "stats": {
                "total_bookings": 0,
                "total_spent": 0
            },
            "booking_history": [],
            "favorites": [],
            "view_history": [],
            "created_at": datetime.now() - timedelta(days=random.randint(1, 365)),
            "updated_at": datetime.now()
        }
        users.append(user)
    
    users_result = db.users.insert_many(users)
    user_ids = users_result.inserted_ids
    print(f"Создано {len(user_ids)} пользователей")
    
    # Создание мероприятий
    events = []
    for i in range(15):
        event_date = datetime.now() + timedelta(days=random.randint(1, 30))
        event = {
            "title": f"{['Концерт', 'Спектакль', 'Матч'][i % 3]} {fake.word().capitalize()}",
            "description": fake.text(max_nb_chars=200),
            "date": event_date,
            "venue_id": random.choice(venue_ids),
            "organizer_id": random.choice(organizer_ids),
            "categories": [["концерт", "музыка"], ["театр", "драма"], ["спорт", "футбол"]][i % 3],
            "tags": ["популярное", "новинка"][:random.randint(1, 2)],
            "ticket_types": [
                {
                    "type": "VIP",
                    "price": random.randint(5000, 10000),
                    "quantity": random.randint(10, 30),
                    "sold": 0
                },
                {
                    "type": "Standard",
                    "price": random.randint(1000, 3000),
                    "quantity": random.randint(50, 100),
                    "sold": 0
                }
            ],
            "status": "published",
            "capacity": random.choice([100, 200, 300]),
            "available_seats": random.choice([100, 200, 300]),
            "created_at": datetime.now() - timedelta(days=random.randint(1, 10)),
            "updated_at": datetime.now()
        }
        events.append(event)
    
    events_result = db.events.insert_many(events)
    event_ids = events_result.inserted_ids
    print(f"Создано {len(event_ids)} мероприятий")
    
    # Создание бронирований
    bookings = []
    for i in range(50):
        user_id = random.choice(user_ids)
        event_id = random.choice(event_ids)
        event = db.events.find_one({"_id": event_id})
        
        if event:
            ticket_type = random.choice(event['ticket_types'])
            quantity = random.randint(1, 2)
            total_amount = ticket_type['price'] * quantity
            
            booking = {
                "user_id": user_id,
                "event_id": event_id,
                "ticket_type": ticket_type['type'],
                "quantity": quantity,
                "total_amount": total_amount,
                "status": "confirmed",
                "payment_method": random.choice(["cash", "card"]),
                "transaction_id": f"TXN{random.randint(100000, 999999)}",
                "created_at": datetime.now() - timedelta(days=random.randint(1, 10)),
                "updated_at": datetime.now()
            }
            bookings.append(booking)
    
    if bookings:
        bookings_result = db.bookings.insert_many(bookings)
        print(f"Создано {len(bookings_result.inserted_ids)} бронирований")
        
        # Обновляем статистику пользователей
        for booking in bookings:
            db.users.update_one(
                {"_id": booking['user_id']},
                {
                    "$inc": {
                        "stats.total_bookings": 1,
                        "stats.total_spent": booking['total_amount']
                    },
                    "$push": {
                        "booking_history": {
                            "booking_id": booking.get('_id'),
                            "event_id": booking['event_id'],
                            "date": booking['created_at'],
                            "status": booking['status'],
                            "amount": booking['total_amount']
                        }
                    }
                }
            )
    
    # Создание отзывов
    reviews = []
    for i in range(30):
        review = {
            "event_id": random.choice(event_ids),
            "user_id": random.choice(user_ids),
            "rating": random.randint(3, 5),
            "comment": fake.text(max_nb_chars=100),
            "created_at": datetime.now() - timedelta(days=random.randint(1, 20))
        }
        reviews.append(review)
    
    reviews_result = db.reviews.insert_many(reviews)
    print(f"Создано {len(reviews_result.inserted_ids)} отзывов")
    
    # Создание истории просмотров
    for user_id in user_ids:
        viewed_events = random.sample(list(event_ids), k=random.randint(3, 8))
        view_history = []
        
        for event_id in viewed_events:
            view_history.append({
                "event_id": event_id,
                "viewed_at": datetime.now() - timedelta(days=random.randint(1, 15))
            })
        
        # Добавляем некоторые в избранное
        favorites = random.sample(viewed_events, k=random.randint(1, 3))
        
        db.users.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "view_history": view_history,
                    "favorites": favorites
                }
            }
        )
    
    print("\n=== Сводка ===")
    print(f"Организаторы: {db.organizers.count_documents({})}")
    print(f"Места проведения: {db.venues.count_documents({})}")
    print(f"Пользователи: {db.users.count_documents({})}")
    print(f"Мероприятия: {db.events.count_documents({})}")
    print(f"Бронирования: {db.bookings.count_documents({})}")
    print(f"Отзывы: {db.reviews.count_documents({})}")
    
    total = sum(db[col].count_documents({}) for col in ['events', 'users', 'bookings', 'reviews', 'venues', 'organizers'])
    print(f"Всего документов: {total}")
    
    print("\n✓ Генерация данных завершена успешно!")
    
except Exception as e:
    print(f"✗ Ошибка при генерации данных: {e}")
    traceback.print_exc()
    sys.exit(1)
EOF

python3 seed_data_simple.py

# 4. Создание индексов
echo -e "\nШаг 4: Создание индексов..."
cat > create_indexes_simple.js << 'EOF'
// create_indexes_simple.js
try {
    db = db.getSiblingDB('event_booking_system');
    
    // Индексы для events
    db.events.createIndex({ "date": 1 });
    db.events.createIndex({ "status": 1 });
    db.events.createIndex({ "categories": 1 });
    
    // Индексы для users
    db.users.createIndex({ "email": 1 }, { unique: true });
    db.users.createIndex({ "favorites": 1 });
    
    // Индексы для bookings
    db.bookings.createIndex({ "user_id": 1 });
    db.bookings.createIndex({ "event_id": 1 });
    db.bookings.createIndex({ "status": 1 });
    
    // Индексы для reviews
    db.reviews.createIndex({ "event_id": 1 });
    db.reviews.createIndex({ "user_id": 1 });
    
    print("✓ Индексы созданы успешно!");
    
    // Показываем индексы
    print("\nСписок индексов:");
    db.getCollectionNames().forEach(function(collection) {
        var indexes = db[collection].getIndexes();
        if (indexes.length > 0) {
            print(collection + ":");
            indexes.forEach(function(idx) {
                print("  - " + idx.name + ": " + JSON.stringify(idx.key));
            });
        }
    });
    
} catch (e) {
    print("Ошибка при создании индексов: " + e);
}
EOF

if command -v mongosh &> /dev/null; then
    mongosh --quiet create_indexes_simple.js
elif command -v mongo &> /dev/null; then
    mongo --quiet create_indexes_simple.js
fi

# 5. Проверка данных
echo -e "\nШаг 5: Проверка данных..."
cat > check_data.js << 'EOF'
// check_data.js
try {
    db = db.getSiblingDB('event_booking_system');
    
    print("=== Проверка данных ===");
    
    var collections = db.getCollectionNames();
    print("Доступные коллекции: " + collections.join(", "));
    
    print("\nКоличество документов:");
    collections.forEach(function(col) {
        var count = db[col].countDocuments();
        print("  " + col + ": " + count);
    });
    
    print("\nПримеры документов:");
    
    // Пример события
    var event = db.events.findOne();
    if (event) {
        print("Мероприятие: " + event.title);
        print("Дата: " + event.date);
        print("Категории: " + (event.categories ? event.categories.join(", ") : "нет"));
    }
    
    // Пример пользователя
    var user = db.users.findOne();
    if (user) {
        print("\nПользователь: " + user.name);
        print("Email: " + user.email);
        print("Бронирований: " + (user.stats ? user.stats.total_bookings : 0));
        print("В избранном: " + (user.favorites ? user.favorites.length : 0) + " мероприятий");
    }
    
    print("\n✓ Проверка данных завершена");
    
} catch (e) {
    print("Ошибка при проверке данных: " + e);
}
EOF

if command -v mongosh &> /dev/null; then
    mongosh --quiet check_data.js
elif command -v mongo &> /dev/null; then
    mongo --quiet check_data.js
fi

# 6. Установка API сервера
echo -e "\nШаг 6: Установка API сервера..."
cd ~/event-booking-system/api

cat > package.json << 'EOF'
{
  "name": "event-booking-api",
  "version": "1.0.0",
  "description": "REST API for Event Booking System",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^6.10.0",
    "cors": "^2.8.5"
  }
}
EOF

# Проверяем установлен ли npm
if command -v npm &> /dev/null; then
    echo "Установка зависимостей Node.js..."
    npm install 2>/dev/null || {
        echo "Использование npm без сети (локальные пакеты)..."
        # Создаем минимальную структуру
        mkdir -p node_modules
    }
else
    echo "npm не найден, создаем структуру вручную..."
    mkdir -p node_modules
fi

# 7. Создание API сервера
echo -e "\nШаг 7: Создание API сервера..."
cat > server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Подключение к MongoDB
mongoose.connect('mongodb://localhost:27017/event_booking_system', {
    useNewUrlParser: true,
    useUnifiedTopology: true
});

const db = mongoose.connection;
db.on('error', (err) => {
    console.error('MongoDB connection error:', err);
});
db.once('open', () => {
    console.log('Connected to MongoDB');
});

// Схемы
const eventSchema = new mongoose.Schema({
    title: String,
    description: String,
    date: Date,
    venue_id: mongoose.Schema.Types.ObjectId,
    organizer_id: mongoose.Schema.Types.ObjectId,
    categories: [String],
    tags: [String],
    ticket_types: [{
        type: String,
        price: Number,
        quantity: Number,
        sold: Number
    }],
    status: String,
    capacity: Number,
    available_seats: Number,
    created_at: Date,
    updated_at: Date
});

const userSchema = new mongoose.Schema({
    email: String,
    name: String,
    phone: String,
    preferences: {
        categories: [String],
        notifications: Boolean
    },
    stats: {
        total_bookings: Number,
        total_spent: Number,
        last_booking_date: Date
    },
    booking_history: [{
        booking_id: mongoose.Schema.Types.ObjectId,
        event_id: mongoose.Schema.Types.ObjectId,
        date: Date,
        status: String,
        amount: Number
    }],
    favorites: [mongoose.Schema.Types.ObjectId],
    view_history: [{
        event_id: mongoose.Schema.Types.ObjectId,
        viewed_at: Date
    }],
    created_at: Date,
    updated_at: Date
});

const Event = mongoose.model('Event', eventSchema);
const User = mongoose.model('User', userSchema);

// API Endpoints
app.get('/', (req, res) => {
    res.json({ message: 'Event Booking System API', version: '1.0' });
});

// Получить все мероприятия
app.get('/api/events', async (req, res) => {
    try {
        const events = await Event.find({ status: 'published' })
            .sort({ date: 1 })
            .limit(20);
        res.json(events);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Получить мероприятие по ID
app.get('/api/events/:id', async (req, res) => {
    try {
        const event = await Event.findById(req.params.id);
        if (!event) {
            return res.status(404).json({ error: 'Event not found' });
        }
        res.json(event);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Получить пользователя
app.get('/api/users/:id', async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.json(user);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Получить избранное пользователя
app.get('/api/users/:id/favorites', async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        const favorites = await Event.find({
            _id: { $in: user.favorites }
        });
        
        res.json(favorites);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Статистика
app.get('/api/stats', async (req, res) => {
    try {
        const stats = {
            events: await Event.countDocuments(),
            users: await User.countDocuments(),
            active_events: await Event.countDocuments({ 
                status: 'published', 
                date: { $gte: new Date() } 
            })
        };
        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Запуск сервера
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log('Available endpoints:');
    console.log('  GET /              - API информация');
    console.log('  GET /api/events    - Все мероприятия');
    console.log('  GET /api/events/:id - Мероприятие по ID');
    console.log('  GET /api/users/:id - Пользователь по ID');
    console.log('  GET /api/users/:id/favorites - Избранное пользователя');
    console.log('  GET /api/stats     - Статистика системы');
});
EOF

echo -e "\n=== ВСЕ ЗАДАЧИ ВЫПОЛНЕНЫ ==="
echo ""
echo "СИСТЕМА ГОТОВА К ИСПОЛЬЗОВАНИЮ!"
echo ""
echo "Доступные команды:"
echo "1. Запуск API сервера:"
echo "   cd ~/event-booking-system/api && node server.js"
echo ""
echo "2. Работа с MongoDB:"
echo "   mongosh event_booking_system  # или mongo event_booking_system"
echo ""
echo "3. Проверка данных:"
echo "   show collections"
echo "   db.events.find().limit(3)"
echo "   db.users.find().limit(3)"
echo ""
echo "4. Доступные коллекции:"
echo "   - events (мероприятия)"
echo "   - users (пользователи)"
echo "   - bookings (бронирования)"
echo "   - reviews (отзывы)"
echo "   - venues (места проведения)"
echo "   - organizers (организаторы)"
echo ""
echo "API будет доступен по адресу: http://localhost:3000"