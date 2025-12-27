// create_indexes_fixed.js - исправлено для MongoDB 4.4.29
db = db.getSiblingDB('event_booking_complete');

print("=== СОЗДАНИЕ ПОСТОЯННЫХ ИНДЕКСОВ (MongoDB 4.4.29) ===");

try {
    // 1. Индексы для events
    print("\n1. Индексы для коллекции events:");
    
    var eventIndexes = db.events.getIndexes();
    
    if (!eventIndexes.some(idx => idx.name === "idx_date")) {
        db.events.createIndex({ "date": 1 }, { name: "idx_date" });
        print("   ✓ Создан индекс на date");
    } else {
        print("   ⏭ Индекс idx_date уже существует");
    }
    
    if (!eventIndexes.some(idx => idx.name === "idx_status_date")) {
        db.events.createIndex({ "status": 1, "date": 1 }, { name: "idx_status_date" });
        print("   ✓ Создан составной индекс на status + date");
    } else {
        print("   ⏭ Индекс idx_status_date уже существует");
    }
    
    if (!eventIndexes.some(idx => idx.name === "idx_categories")) {
        db.events.createIndex({ "categories": 1 }, { name: "idx_categories" });
        print("   ✓ Создан индекс на categories");
    } else {
        print("   ⏭ Индекс idx_categories уже существует");
    }
    
    // 2. Индексы для bookings - используем count() вместо countDocuments()
    print("\n2. Индексы для коллекции bookings:");
    
    if (db.bookings.count() > 0) {  // count() вместо countDocuments()
        var bookingIndexes = db.bookings.getIndexes();
        
        if (!bookingIndexes.some(idx => idx.name === "idx_user_created")) {
            db.bookings.createIndex(
                { "user_id": 1, "created_at": -1 }, 
                { name: "idx_user_created" }
            );
            print("   ✓ Создан индекс на user_id + created_at");
        } else {
            print("   ⏭ Индекс idx_user_created уже существует");
        }
        
        if (!bookingIndexes.some(idx => idx.name === "idx_event_status")) {
            db.bookings.createIndex(
                { "event_id": 1, "status": 1 }, 
                { name: "idx_event_status" }
            );
            print("   ✓ Создан индекс на event_id + status");
        } else {
            print("   ⏭ Индекс idx_event_status уже существует");
        }
    } else {
        print("   ⚠ Коллекция bookings пуста, индексы не созданы");
    }
    
    // 3. Индексы для users
    print("\n3. Индексы для коллекции users:");
    
    var userIndexes = db.users.getIndexes();
    
    if (!userIndexes.some(idx => idx.name === "idx_email")) {
        db.users.createIndex({ "email": 1 }, { name: "idx_email", unique: true });
        print("   ✓ Создан уникальный индекс на email");
    } else {
        print("   ⏭ Индекс idx_email уже существует");
    }
    
    if (!userIndexes.some(idx => idx.name === "idx_favorites")) {
        db.users.createIndex({ "favorites": 1 }, { name: "idx_favorites" });
        print("   ✓ Создан индекс на favorites");
    } else {
        print("   ⏭ Индекс idx_favorites уже существует");
    }
    
    // 4. Создаем коллекцию cached_reports если её нет
    print("\n4. Создание коллекции cached_reports:");
    
    var collNames = db.getCollectionNames();
    
    if (!collNames.includes("cached_reports")) {
        db.createCollection("cached_reports");
        print("   ✓ Коллекция cached_reports создана");
        
        // Создаем TTL индекс
        db.cached_reports.createIndex(
            { "expires_at": 1 },
            { expireAfterSeconds: 0, name: "idx_ttl" }
        );
        print("   ✓ TTL индекс создан (expireAfterSeconds: 0)");
        
        // Добавляем тестовый отчет
        db.cached_reports.insertOne({
            report_type: "events_summary",
            cache_key: "test_" + Date.now(),
            data: {
                total_events: db.events.count(),  // count() вместо countDocuments()
                total_users: db.users.count(),    // count() вместо countDocuments()
                generated_at: new Date()
            },
            created_at: new Date(),
            expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000),
            hit_count: 0
        });
        print("   ✓ Тестовый отчет добавлен");
    } else {
        print("   ✓ Коллекция cached_reports уже существует");
    }
    
    // 5. Создаем индексы для ticket_sales (для отчетов)
    print("\n5. Индексы для коллекции ticket_sales:");
    
    if (collNames.includes("ticket_sales")) {
        var ticketIndexes = db.ticket_sales.getIndexes();
        
        if (!ticketIndexes.some(idx => idx.name === "idx_category")) {
            db.ticket_sales.createIndex({ "category": 1 }, { name: "idx_category" });
            print("   ✓ Создан индекс на category");
        }
        
        if (!ticketIndexes.some(idx => idx.name === "idx_price")) {
            db.ticket_sales.createIndex({ "price": 1 }, { name: "idx_price" });
            print("   ✓ Создан индекс на price");
        }
    }
    
    // 6. Показываем все индексы
    print("\n=== ВСЕ ИНДЕКСЫ В БАЗЕ ===");
    
    var allCollections = db.getCollectionNames();
    allCollections.forEach(col => {
        var indexes = db[col].getIndexes();
        if (indexes.length > 0) {
            print("\n" + col + ":");
            indexes.forEach(idx => {
                var ttlInfo = idx.expireAfterSeconds ? ` (TTL: ${idx.expireAfterSeconds} сек)` : '';
                print("  - " + idx.name + ": " + JSON.stringify(idx.key) + ttlInfo);
            });
        }
    });
    
    print("\n✅ Все постоянные индексы созданы!");
    
} catch (e) {
    print("Ошибка: " + e);
    print("Stack: " + e.stack);
}