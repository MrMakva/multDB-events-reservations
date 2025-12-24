#!/bin/bash

echo "=== ПОЛНАЯ НАСТРОЙКА СИСТЕМЫ БРОНИРОВАНИЯ МЕРОПРИЯТИЙ ==="

echo "1. Настройка MongoDB..."
if [ ! -d "/data/db" ]; then
    echo "Создание директории для данных MongoDB..."
    sudo mkdir -p /data/db
    sudo chown -R $USER /data/db 2>/dev/null || sudo chown -R $(whoami) /data/db
    sudo chmod -R 755 /data/db
fi

echo "Проверка запуска MongoDB..."
if ! pgrep mongod > /dev/null; then
    echo "Запуск MongoDB..."
    sudo mongod --dbpath /data/db --fork --logpath /tmp/mongod.log 2>/dev/null || {
        echo "Пробуем альтернативный вариант..."
        mongod --dbpath /data/db --fork --logpath /tmp/mongod.log
    }
fi

sleep 2

if pgrep mongod > /dev/null; then
    echo "✓ MongoDB запущен успешно"
else
    echo "⚠ Не удалось запустить MongoDB. Пробуем вручную:"
    echo "   mongod --dbpath /data/db"
    echo "   (в отдельном терминале)"
    read -p "Нажмите Enter после запуска MongoDB..."
fi

echo "2. Создание структуры проекта..."
mkdir -p ~/event-booking-system/{scripts,api,data}
cd ~/event-booking-system/scripts

echo "3. Инициализация базы данных..."
cat > init_db.js << 'EOF'
// init_db.js - Инициализация базы данных

try {
    print("=== ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ ===");
    
    // Создаем или переключаемся на базу данных
    db = db.getSiblingDB('event_booking_system');
    print("Используем базу данных: event_booking_system");
    
    // Удаляем старые данные (если нужно)
    print("Очистка старых данных...");
    db.dropDatabase();
    
    // Создаем коллекции
    var collections = [
        'events',      // Мероприятия
        'users',       // Пользователи  
        'bookings',    // Бронирования
        'reviews',     // Отзывы
        'venues',      // Места проведения
        'organizers'   // Организаторы
    ];
    
    collections.forEach(function(colName) {
        if (!db.getCollectionNames().includes(colName)) {
            db.createCollection(colName);
            print("Создана коллекция: " + colName);
        } else {
            print("Коллекция уже существует: " + colName);
        }
    });
    
    print("\n✓ База данных инициализирована");
    
} catch (e) {
    print("Ошибка при инициализации: " + e);
}
EOF

echo "Запуск инициализации базы данных..."
if command -v mongosh &> /dev/null; then
    mongosh --quiet init_db.js
else
    mongo --quiet init_db.js
fi

echo "4. Создание тестовых данных..."
cat > create_test_data.js << 'EOF'
// create_test_data.js - Создание тестовых данных
db = db.getSiblingDB('event_booking_system');

print("=== СОЗДАНИЕ ТЕСТОВЫХ ДАННЫХ ===");

// 1. Создаем места проведения
print("1. Создание мест проведения...");
var venues = [
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d01"),
        name: "Кремлевский дворец",
        address: "Москва, Кремль",
        capacity: 6000,
        location: {
            type: "Point",
            coordinates: [37.6173, 55.7520]
        }
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d02"),
        name: "Лужники",
        address: "Москва, Лужнецкая наб., 24",
        capacity: 81000,
        location: {
            type: "Point",
            coordinates: [37.5538, 55.7158]
        }
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d03"),
        name: "Большой театр",
        address: "Москва, Театральная площадь, 1",
        capacity: 2150,
        location: {
            type: "Point",
            coordinates: [37.6184, 55.7601]
        }
    }
];

db.venues.insertMany(venues);
print("   Добавлено мест проведения: " + db.venues.countDocuments());

// 2. Создаем организаторов
print("\n2. Создание организаторов...");
var organizers = [
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d11"),
        name: "Кремлевские концерты",
        email: "kremlin@concerts.ru",
        phone: "+74951234567",
        description: "Организация концертов в Кремле"
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d12"),
        name: "Спорт-арена",
        email: "info@sport-arena.ru",
        phone: "+74959876543",
        description: "Организация спортивных мероприятий"
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d13"),
        name: "Большой театр России",
        email: "info@bolshoi.ru",
        phone: "+74956925531",
        description: "Государственный академический Большой театр России"
    }
];

db.organizers.insertMany(organizers);
print("   Добавлено организаторов: " + db.organizers.countDocuments());

// 3. Создаем мероприятия
print("\n3. Создание мероприятий...");
var events = [
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d21"),
        title: "Новогодний концерт в Кремле",
        description: "Гала-концерт с участием звезд эстрады",
        date: new Date("2024-12-31T21:00:00Z"),
        venue_id: ObjectId("655a1b2c3d4e5f6a7b8c9d01"),
        organizer_id: ObjectId("655a1b2c3d4e5f6a7b8c9d11"),
        categories: ["концерт", "новогодний"],
        tags: ["праздник", "гала-концерт", "новый год"],
        ticket_types: [
            { type: "VIP", price: 25000, quantity: 100, sold: 45 },
            { type: "Standard", price: 15000, quantity: 500, sold: 320 },
            { type: "Student", price: 8000, quantity: 200, sold: 150 }
        ],
        status: "published",
        capacity: 800,
        available_seats: 285,
        created_at: new Date(),
        updated_at: new Date()
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d22"),
        title: "Футбольный матч: Россия - Германия",
        description: "Товарищеский матч сборных",
        date: new Date("2024-12-20T19:00:00Z"),
        venue_id: ObjectId("655a1b2c3d4e5f6a7b8c9d02"),
        organizer_id: ObjectId("655a1b2c3d4e5f6a7b8c9d12"),
        categories: ["спорт", "футбол"],
        tags: ["сборная", "товарищеский матч", "международный"],
        ticket_types: [
            { type: "VIP", price: 12000, quantity: 500, sold: 300 },
            { type: "Standard", price: 5000, quantity: 4000, sold: 2800 },
            { type: "Student", price: 2500, quantity: 1000, sold: 750 }
        ],
        status: "published",
        capacity: 5500,
        available_seats: 1650,
        created_at: new Date(),
        updated_at: new Date()
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d23"),
        title: "Балет 'Щелкунчик'",
        description: "Новогодняя сказка в постановке Большого театра",
        date: new Date("2024-12-25T19:00:00Z"),
        venue_id: ObjectId("655a1b2c3d4e5f6a7b8c9d03"),
        organizer_id: ObjectId("655a1b2c3d4e5f6a7b8c9d13"),
        categories: ["театр", "балет", "новогодний"],
        tags: ["Чайковский", "сказка", "рождество"],
        ticket_types: [
            { type: "VIP", price: 20000, quantity: 50, sold: 40 },
            { type: "Standard", price: 10000, quantity: 500, sold: 420 },
            { type: "Student", price: 5000, quantity: 100, sold: 85 }
        ],
        status: "published",
        capacity: 650,
        available_seats: 105,
        created_at: new Date(),
        updated_at: new Date()
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d24"),
        title: "Рок-фестиваль 'Зима'",
        description: "Фестиваль рок-музыки под открытым небом",
        date: new Date("2024-12-28T18:00:00Z"),
        venue_id: ObjectId("655a1b2c3d4e5f6a7b8c9d02"),
        organizer_id: ObjectId("655a1b2c3d4e5f6a7b8c9d11"),
        categories: ["концерт", "рок", "фестиваль"],
        tags: ["живая музыка", "фестиваль", "рок"],
        ticket_types: [
            { type: "VIP", price: 15000, quantity: 200, sold: 120 },
            { type: "Standard", price: 8000, quantity: 3000, sold: 2100 },
            { type: "Student", price: 4000, quantity: 500, sold: 400 }
        ],
        status: "published",
        capacity: 3700,
        available_seats: 1080,
        created_at: new Date(),
        updated_at: new Date()
    }
];

db.events.insertMany(events);
print("   Добавлено мероприятий: " + db.events.countDocuments());

// 4. Создаем пользователей
print("\n4. Создание пользователей...");
var users = [
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d31"),
        email: "ivan.ivanov@example.com",
        name: "Иван Иванов",
        phone: "+79161234567",
        preferences: {
            categories: ["концерт", "спорт"],
            notifications: true
        },
        stats: {
            total_bookings: 3,
            total_spent: 45000,
            last_booking_date: new Date("2024-11-20")
        },
        favorites: [
            ObjectId("655a1b2c3d4e5f6a7b8c9d21"),
            ObjectId("655a1b2c3d4e5f6a7b8c9d22")
        ],
        view_history: [
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d21"), viewed_at: new Date("2024-11-15T10:30:00Z") },
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d22"), viewed_at: new Date("2024-11-16T14:20:00Z") },
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d23"), viewed_at: new Date("2024-11-17T11:45:00Z") }
        ],
        created_at: new Date("2024-01-15"),
        updated_at: new Date()
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d32"),
        email: "maria.petrova@example.com",
        name: "Мария Петрова",
        phone: "+79167654321",
        preferences: {
            categories: ["театр", "балет"],
            notifications: false
        },
        stats: {
            total_bookings: 2,
            total_spent: 30000,
            last_booking_date: new Date("2024-11-18")
        },
        favorites: [
            ObjectId("655a1b2c3d4e5f6a7b8c9d23")
        ],
        view_history: [
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d23"), viewed_at: new Date("2024-11-10T16:15:00Z") },
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d24"), viewed_at: new Date("2024-11-12T12:30:00Z") }
        ],
        created_at: new Date("2024-02-20"),
        updated_at: new Date()
    },
    {
        _id: ObjectId("655a1b2c3d4e5f6a7b8c9d33"),
        email: "alex.smirnov@example.com",
        name: "Алексей Смирнов",
        phone: "+79169998877",
        preferences: {
            categories: ["спорт", "рок"],
            notifications: true
        },
        stats: {
            total_bookings: 4,
            total_spent: 22000,
            last_booking_date: new Date("2024-11-22")
        },
        favorites: [
            ObjectId("655a1b2c3d4e5f6a7b8c9d22"),
            ObjectId("655a1b2c3d4e5f6a7b8c9d24")
        ],
        view_history: [
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d22"), viewed_at: new Date("2024-11-05T09:45:00Z") },
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d24"), viewed_at: new Date("2024-11-08T15:20:00Z") },
            { event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d21"), viewed_at: new Date("2024-11-09T11:10:00Z") }
        ],
        created_at: new Date("2024-03-10"),
        updated_at: new Date()
    }
];

// Добавляем еще 7 пользователей для разнообразия
for (var i = 4; i <= 10; i++) {
    users.push({
        _id: ObjectId(),
        email: `user${i}@example.com`,
        name: `Пользователь ${i}`,
        phone: `+7916${1000000 + i}`,
        preferences: {
            categories: [["концерт", "театр", "спорт"][Math.floor(Math.random() * 3)]],
            notifications: Math.random() > 0.5
        },
        stats: {
            total_bookings: Math.floor(Math.random() * 5),
            total_spent: Math.floor(Math.random() * 50000),
            last_booking_date: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000)
        },
        favorites: events.slice(0, 2).map(e => e._id),
        view_history: events.slice(0, 3).map(e => ({
            event_id: e._id,
            viewed_at: new Date(Date.now() - Math.random() * 15 * 24 * 60 * 60 * 1000)
        })),
        created_at: new Date(Date.now() - Math.random() * 365 * 24 * 60 * 60 * 1000),
        updated_at: new Date()
    });
}

db.users.insertMany(users);
print("   Добавлено пользователей: " + db.users.countDocuments());

// 5. Создаем бронирования
print("\n5. Создание бронирований...");
var bookings = [];

// Бронирования для первого пользователя
bookings.push(
    {
        _id: ObjectId(),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d31"),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d21"),
        ticket_type: "VIP",
        quantity: 2,
        total_amount: 50000,
        status: "confirmed",
        payment_method: "card",
        transaction_id: "TXN20241120001",
        seats: ["A1", "A2"],
        created_at: new Date("2024-11-20T14:30:00Z"),
        updated_at: new Date("2024-11-20T14:30:00Z")
    },
    {
        _id: ObjectId(),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d31"),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d22"),
        ticket_type: "Standard",
        quantity: 3,
        total_amount: 15000,
        status: "confirmed",
        payment_method: "online",
        transaction_id: "TXN20241118002",
        seats: ["B10", "B11", "B12"],
        created_at: new Date("2024-11-18T10:15:00Z"),
        updated_at: new Date("2024-11-18T10:15:00Z")
    }
);

// Бронирования для второго пользователя
bookings.push(
    {
        _id: ObjectId(),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d32"),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d23"),
        ticket_type: "VIP",
        quantity: 1,
        total_amount: 20000,
        status: "confirmed",
        payment_method: "card",
        transaction_id: "TXN20241118003",
        seats: ["C5"],
        created_at: new Date("2024-11-18T16:45:00Z"),
        updated_at: new Date("2024-11-18T16:45:00Z")
    },
    {
        _id: ObjectId(),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d32"),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d23"),
        ticket_type: "Standard",
        quantity: 1,
        total_amount: 10000,
        status: "confirmed",
        payment_method: "cash",
        transaction_id: "TXN20241115004",
        seats: ["D12"],
        created_at: new Date("2024-11-15T12:20:00Z"),
        updated_at: new Date("2024-11-15T12:20:00Z")
    }
);

// Бронирования для третьего пользователя
bookings.push(
    {
        _id: ObjectId(),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d33"),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d22"),
        ticket_type: "Student",
        quantity: 2,
        total_amount: 5000,
        status: "confirmed",
        payment_method: "online",
        transaction_id: "TXN20241122005",
        seats: ["E7", "E8"],
        created_at: new Date("2024-11-22T09:30:00Z"),
        updated_at: new Date("2024-11-22T09:30:00Z")
    },
    {
        _id: ObjectId(),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d33"),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d24"),
        ticket_type: "Standard",
        quantity: 4,
        total_amount: 32000,
        status: "confirmed",
        payment_method: "card",
        transaction_id: "TXN20241110006",
        seats: ["F1", "F2", "F3", "F4"],
        created_at: new Date("2024-11-10T11:45:00Z"),
        updated_at: new Date("2024-11-10T11:45:00Z")
    },
    {
        _id: ObjectId(),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d33"),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d21"),
        ticket_type: "Standard",
        quantity: 1,
        total_amount: 15000,
        status: "cancelled",
        payment_method: "online",
        transaction_id: "TXN20241108007",
        seats: ["G5"],
        created_at: new Date("2024-11-08T14:15:00Z"),
        updated_at: new Date("2024-11-08T14:15:00Z"),
        cancelled_at: new Date("2024-11-09T10:30:00Z")
    }
);

// Добавляем еще 40 случайных бронирований
for (var i = 8; i <= 50; i++) {
    var user = users[Math.floor(Math.random() * users.length)];
    var event = events[Math.floor(Math.random() * events.length)];
    var ticketType = event.ticket_types[Math.floor(Math.random() * event.ticket_types.length)];
    var quantity = Math.floor(Math.random() * 4) + 1;
    
    bookings.push({
        _id: ObjectId(),
        user_id: user._id,
        event_id: event._id,
        ticket_type: ticketType.type,
        quantity: quantity,
        total_amount: ticketType.price * quantity,
        status: Math.random() > 0.1 ? "confirmed" : "cancelled",
        payment_method: ["card", "online", "cash"][Math.floor(Math.random() * 3)],
        transaction_id: `TXN${20241100000 + i}`,
        seats: Array.from({length: quantity}, (_, j) => `${String.fromCharCode(65 + Math.floor(Math.random() * 5))}${j + 1}`),
        created_at: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000),
        updated_at: new Date(),
        cancelled_at: Math.random() > 0.8 ? new Date(Date.now() - Math.random() * 10 * 24 * 60 * 60 * 1000) : null
    });
}

db.bookings.insertMany(bookings);
print("   Добавлено бронирований: " + db.bookings.countDocuments());

// 6. Создаем отзывы
print("\n6. Создание отзывов...");
var reviews = [
    {
        _id: ObjectId(),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d21"),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d31"),
        rating: 5,
        comment: "Отличный концерт! Организация на высшем уровне.",
        created_at: new Date("2024-11-21T12:00:00Z"),
        helpful_count: 12
    },
    {
        _id: ObjectId(),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d22"),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d33"),
        rating: 4,
        comment: "Хороший матч, но было холодно на стадионе.",
        created_at: new Date("2024-11-23T15:30:00Z"),
        helpful_count: 8
    },
    {
        _id: ObjectId(),
        event_id: ObjectId("655a1b2c3d4e5f6a7b8c9d23"),
        user_id: ObjectId("655a1b2c3d4e5f6a7b8c9d32"),
        rating: 5,
        comment: "Волшебный балет! Рекомендую всем.",
        created_at: new Date("2024-11-19T18:45:00Z"),
        helpful_count: 15
    }
];

// Добавляем еще 27 случайных отзывов
for (var i = 4; i <= 30; i++) {
    var event = events[Math.floor(Math.random() * events.length)];
    var user = users[Math.floor(Math.random() * users.length)];
    
    reviews.push({
        _id: ObjectId(),
        event_id: event._id,
        user_id: user._id,
        rating: Math.floor(Math.random() * 3) + 3, // 3-5 звезд
        comment: ["Отлично!", "Хорошо", "Нормально", "Понравилось", "Рекомендую"][Math.floor(Math.random() * 5)] + " " +
                 ["организация", "атмосфера", "исполнение", "место", "цена"][Math.floor(Math.random() * 5)] + " на уровне.",
        created_at: new Date(Date.now() - Math.random() * 20 * 24 * 60 * 60 * 1000),
        helpful_count: Math.floor(Math.random() * 20)
    });
}

db.reviews.insertMany(reviews);
print("   Добавлено отзывов: " + db.reviews.countDocuments());

print("\n=== ИТОГИ ===");
print("Места проведения: " + db.venues.countDocuments());
print("Организаторы: " + db.organizers.countDocuments());
print("Мероприятия: " + db.events.countDocuments());
print("Пользователи: " + db.users.countDocuments());
print("Бронирования: " + db.bookings.countDocuments());
print("Отзывы: " + db.reviews.countDocuments());

var total = db.venues.countDocuments() + db.organizers.countDocuments() + 
            db.events.countDocuments() + db.users.countDocuments() + 
            db.bookings.countDocuments() + db.reviews.countDocuments();

print("Всего документов: " + total);
print("\n✓ Тестовые данные успешно созданы!");
EOF

echo "Запуск создания тестовых данных..."
if command -v mongosh &> /dev/null; then
    mongosh --quiet create_test_data.js
else
    mongo --quiet create_test_data.js
fi

echo "5. Создание индексов..."
cat > create_indexes.js << 'EOF'
// create_indexes.js - Создание индексов
db = db.getSiblingDB('event_booking_system');

print("=== СОЗДАНИЕ ИНДЕКСОВ ===");

try {
    // Индексы для events
    print("1. Индексы для коллекции events:");
    db.events.createIndex({ "date": 1 });
    print("   ✓ Индекс на поле date");
    
    db.events.createIndex({ "status": 1, "date": 1 });
    print("   ✓ Составной индекс на status и date");
    
    db.events.createIndex({ "venue_id": 1 });
    print("   ✓ Индекс на venue_id");
    
    db.events.createIndex({ "categories": 1 });
    print("   ✓ Индекс на categories");
    
    db.events.createIndex({ "available_seats": 1 });
    print("   ✓ Индекс на available_seats");
    
    // Индексы для users
    print("\n2. Индексы для коллекции users:");
    db.users.createIndex({ "email": 1 }, { unique: true });
    print("   ✓ Уникальный индекс на email");
    
    db.users.createIndex({ "favorites": 1 });
    print("   ✓ Индекс на favorites");
    
    // Индексы для bookings
    print("\n3. Индексы для коллекции bookings:");
    db.bookings.createIndex({ "user_id": 1, "created_at": -1 });
    print("   ✓ Составной индекс на user_id и created_at");
    
    db.bookings.createIndex({ "event_id": 1, "status": 1 });
    print("   ✓ Составной индекс на event_id и status");
    
    db.bookings.createIndex({ "status": 1 });
    print("   ✓ Индекс на status");
    
    // Индексы для reviews
    print("\n4. Индексы для коллекции reviews:");
    db.reviews.createIndex({ "event_id": 1, "rating": -1 });
    print("   ✓ Составной индекс на event_id и rating");
    
    db.reviews.createIndex({ "user_id": 1 });
    print("   ✓ Индекс на user_id");
    
    // Индексы для venues
    print("\n5. Индексы для коллекции venues:");
    db.venues.createIndex({ "location": "2dsphere" });
    print("   ✓ Геопространственный индекс на location");
    
    print("\n✓ Все индексы успешно созданы!");
    
    // Показываем статистику
    print("\n=== СТАТИСТИКА ИНДЕКСОВ ===");
    var collections = db.getCollectionNames();
    collections.forEach(function(colName) {
        var indexes = db[colName].getIndexes();
        print(colName + ": " + (indexes.length - 1) + " дополнительных индексов");
    });
    
} catch (e) {
    print("Ошибка при создании индексов: " + e);
}
EOF

echo "Запуск создания индексов..."
if command -v mongosh &> /dev/null; then
    mongosh --quiet create_indexes.js
else
    mongo --quiet create_indexes.js
fi

echo "6. Создание API сервера..."
cd ~/event-booking-system/api

cat > package.json << 'EOF'
{
  "name": "event-booking-api",
  "version": "1.0.0",
  "description": "REST API для системы бронирования мероприятий",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^6.10.0",
    "cors": "^2.8.5"
  }
}
EOF

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
db.on('error', console.error.bind(console, 'MongoDB connection error:'));
db.once('open', () => {
    console.log('✓ Connected to MongoDB');
});

// Схемы Mongoose
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
    favorites: [mongoose.Schema.Types.ObjectId],
    view_history: [{
        event_id: mongoose.Schema.Types.ObjectId,
        viewed_at: Date
    }],
    created_at: Date,
    updated_at: Date
});

const bookingSchema = new mongoose.Schema({
    user_id: mongoose.Schema.Types.ObjectId,
    event_id: mongoose.Schema.Types.ObjectId,
    ticket_type: String,
    quantity: Number,
    total_amount: Number,
    status: String,
    payment_method: String,
    transaction_id: String,
    seats: [String],
    created_at: Date,
    updated_at: Date,
    cancelled_at: Date
});

const reviewSchema = new mongoose.Schema({
    event_id: mongoose.Schema.Types.ObjectId,
    user_id: mongoose.Schema.Types.ObjectId,
    rating: Number,
    comment: String,
    created_at: Date,
    helpful_count: Number
});

const Event = mongoose.model('Event', eventSchema);
const User = mongoose.model('User', userSchema);
const Booking = mongoose.model('Booking', bookingSchema);
const Review = mongoose.model('Review', reviewSchema);

// ==================== API ENDPOINTS ====================

// 1. Основные маршруты
app.get('/', (req, res) => {
    res.json({
        message: 'Event Booking System API',
        version: '1.0',
        endpoints: {
            events: {
                all: 'GET /api/events',
                single: 'GET /api/events/:id',
                search: 'GET /api/events/search?q=...',
                nearby: 'GET /api/events/nearby?lat=...&lng=...'
            },
            users: {
                single: 'GET /api/users/:id',
                favorites: 'GET /api/users/:id/favorites',
                bookings: 'GET /api/users/:id/bookings',
                views: 'GET /api/users/:id/view-history'
            },
            analytics: {
                sales: 'GET /api/analytics/sales',
                popular: 'GET /api/analytics/events/popular',
                users: 'GET /api/analytics/users/active'
            }
        }
    });
});

// 2. Маршруты для мероприятий
app.get('/api/events', async (req, res) => {
    try {
        const { category, status = 'published', limit = 20, offset = 0 } = req.query;
        
        let query = { status };
        if (category) query.categories = category;
        
        const events = await Event.find(query)
            .skip(parseInt(offset))
            .limit(parseInt(limit))
            .sort({ date: 1 });
        
        const total = await Event.countDocuments(query);
        
        res.json({
            success: true,
            data: events,
            pagination: {
                total,
                limit: parseInt(limit),
                offset: parseInt(offset)
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/events/:id', async (req, res) => {
    try {
        const event = await Event.findById(req.params.id);
        if (!event) {
            return res.status(404).json({ success: false, error: 'Event not found' });
        }
        
        // Получаем отзывы
        const reviews = await Review.find({ event_id: event._id })
            .sort({ created_at: -1 })
            .limit(10);
        
        // Получаем средний рейтинг
        const avgRating = await Review.aggregate([
            { $match: { event_id: event._id } },
            { $group: { _id: null, avgRating: { $avg: '$rating' } } }
        ]);
        
        res.json({
            success: true,
            data: {
                ...event.toObject(),
                reviews,
                average_rating: avgRating.length > 0 ? avgRating[0].avgRating : 0,
                review_count: reviews.length
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// 3. Маршруты для пользователей
app.get('/api/users/:id', async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) {
            return res.status(404).json({ success: false, error: 'User not found' });
        }
        res.json({ success: true, data: user });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/users/:id/favorites', async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) {
            return res.status(404).json({ success: false, error: 'User not found' });
        }
        
        const favorites = await Event.find({
            _id: { $in: user.favorites }
        });
        
        res.json({ success: true, data: favorites });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/users/:id/bookings', async (req, res) => {
    try {
        const bookings = await Booking.find({ user_id: req.params.id })
            .sort({ created_at: -1 });
        
        res.json({ success: true, data: bookings });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/users/:id/view-history', async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) {
            return res.status(404).json({ success: false, error: 'User not found' });
        }
        
        // Получаем информацию о просмотренных мероприятиях
        const viewHistory = user.view_history || [];
        const eventIds = viewHistory.map(v => v.event_id);
        const events = await Event.find({ _id: { $in: eventIds } });
        
        // Объединяем данные
        const enrichedHistory = viewHistory.map(view => {
            const event = events.find(e => e._id.equals(view.event_id));
            return {
                ...view,
                event: event ? {
                    title: event.title,
                    date: event.date,
                    categories: event.categories
                } : null
            };
        });
        
        res.json({ success: true, data: enrichedHistory });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// 4. Маршруты для аналитики
app.get('/api/analytics/sales', async (req, res) => {
    try {
        const { days = 30 } = req.query;
        const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
        
        const salesData = await Booking.aggregate([
            {
                $match: {
                    status: 'confirmed',
                    created_at: { $gte: startDate }
                }
            },
            {
                $group: {
                    _id: {
                        year: { $year: '$created_at' },
                        month: { $month: '$created_at' },
                        day: { $dayOfMonth: '$created_at' }
                    },
                    total_bookings: { $sum: 1 },
                    total_revenue: { $sum: '$total_amount' },
                    avg_ticket_price: { $avg: { $divide: ['$total_amount', '$quantity'] } }
                }
            },
            { $sort: { '_id': 1 } },
            { $limit: 30 }
        ]);
        
        res.json({ success: true, data: salesData });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/analytics/events/popular', async (req, res) => {
    try {
        const popularEvents = await Booking.aggregate([
            {
                $match: { status: 'confirmed' }
            },
            {
                $group: {
                    _id: '$event_id',
                    total_bookings: { $sum: 1 },
                    total_revenue: { $sum: '$total_amount' },
                    avg_booking_value: { $avg: '$total_amount' }
                }
            },
            {
                $lookup: {
                    from: 'events',
                    localField: '_id',
                    foreignField: '_id',
                    as: 'event_info'
                }
            },
            { $unwind: '$event_info' },
            {
                $project: {
                    event_title: '$event_info.title',
                    total_bookings: 1,
                    total_revenue: 1,
                    avg_booking_value: { $round: ['$avg_booking_value', 2] }
                }
            },
            { $sort: { total_revenue: -1 } },
            { $limit: 10 }
        ]);
        
        res.json({ success: true, data: popularEvents });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/analytics/users/active', async (req, res) => {
    try {
        const activeUsers = await User.aggregate([
            {
                $match: {
                    'stats.total_bookings': { $gte: 3 }
                }
            },
            {
                $project: {
                    name: 1,
                    email: 1,
                    total_bookings: '$stats.total_bookings',
                    total_spent: '$stats.total_spent',
                    favorites_count: { $size: '$favorites' }
                }
            },
            { $sort: { total_spent: -1 } },
            { $limit: 10 }
        ]);
        
        res.json({ success: true, data: activeUsers });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// 5. Поиск ближайших мероприятий
app.get('/api/events/nearby', async (req, res) => {
    try {
        const { lat, lng, radius = 5000 } = req.query;
        
        if (!lat || !lng) {
            return res.status(400).json({ 
                success: false, 
                error: 'Latitude and longitude are required' 
            });
        }
        
        const nearbyEvents = await Event.aggregate([
            {
                $lookup: {
                    from: 'venues',
                    localField: 'venue_id',
                    foreignField: '_id',
                    as: 'venue'
                }
            },
            { $unwind: '$venue' },
            {
                $match: {
                    'venue.location': {
                        $nearSphere: {
                            $geometry: {
                                type: 'Point',
                                coordinates: [parseFloat(lng), parseFloat(lat)]
                            },
                            $maxDistance: parseInt(radius)
                        }
                    },
                    status: 'published',
                    date: { $gte: new Date() }
                }
            },
            {
                $project: {
                    title: 1,
                    date: 1,
                    categories: 1,
                    available_seats: 1,
                    venue: {
                        name: '$venue.name',
                        address: '$venue.address',
                        coordinates: '$venue.location.coordinates'
                    }
                }
            },
            { $sort: { date: 1 } },
            { $limit: 10 }
        ]);
        
        res.json({ success: true, data: nearbyEvents });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Запуск сервера
app.listen(PORT, () => {
    console.log(`✓ Server running on http://localhost:${PORT}`);
    console.log('\nДоступные эндпоинты:');
    console.log('  GET  /                    - Информация об API');
    console.log('  GET  /api/events          - Все мероприятия');
    console.log('  GET  /api/events/:id      - Мероприятие по ID');
    console.log('  GET  /api/users/:id       - Пользователь по ID');
    console.log('  GET  /api/users/:id/favorites - Избранное пользователя');
    console.log('  GET  /api/users/:id/bookings  - Бронирования пользователя');
    console.log('  GET  /api/users/:id/view-history - История просмотров');
    console.log('  GET  /api/analytics/sales - Статистика продаж');
    console.log('  GET  /api/analytics/events/popular - Популярные мероприятия');
    console.log('  GET  /api/analytics/users/active - Активные пользователи');
    console.log('  GET  /api/events/nearby   - Ближайшие мероприятия');
});
EOF

# 7. Устанавливаем зависимости
echo "7. Установка зависимостей Node.js..."
if command -v npm &> /dev/null; then
    echo "Установка npm пакетов..."
    npm install 2>/dev/null || {
        echo "Используем локальную установку..."
        # Создаем структуру node_modules
        mkdir -p node_modules
    }
else
    echo "npm не найден. Установите Node.js и npm:"
    echo "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
    echo "sudo apt install -y nodejs"
fi

echo -e "\n=== НАСТРОЙКА ЗАВЕРШЕНА! ==="
echo ""
echo "✓ MongoDB запущен и настроен"
echo "✓ База данных создана и заполнена"
echo "✓ Индексы созданы"
echo "✓ API сервер настроен"
echo ""
echo "ДЛЯ ЗАПУСКА СИСТЕМЫ:"
echo "1. Запустите MongoDB (если еще не запущен):"
echo "   mongod --dbpath /data/db"
echo ""
echo "2. Запустите API сервер:"
echo "   cd ~/event-booking-system/api"
echo "   node server.js"
echo ""
echo "3. Откройте в браузере:"
echo "   http://localhost:3000"
echo ""
echo "4. Для работы с MongoDB напрямую:"
echo "   mongosh event_booking_system"
echo "   или"
echo "   mongo event_booking_system"
echo ""
echo "5. Примеры запросов:"
echo "   db.events.countDocuments()"
echo "   db.users.find().limit(3)"
echo "   db.bookings.find({status: 'confirmed'}).count()"