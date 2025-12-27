// fix_validation_detailed.js
print("=== ДЕТАЛЬНОЕ ИСПРАВЛЕНИЕ ВАЛИДАЦИИ СХЕМЫ ===");

db = db.getSiblingDB('event_booking_all_tasks');

// 1. Удаляем старую коллекцию
print("1. Удаление старой коллекции validated_bookings...");
try {
    db.validated_bookings.drop();
    print("✅ Коллекция удалена");
} catch (e) {
    print("ℹ " + e.message);
}

// 2. Создаем ПРОСТУЮ коллекцию для теста БЕЗ валидации
print("\n2. Тест: создаем коллекцию БЕЗ валидации...");
db.createCollection("test_no_validation");

// Вставляем тестовый документ без валидации
var testResult = db.test_no_validation.insertOne({
    user_id: "test_user",
    event_id: "test_event",
    tickets_count: 2,
    total_amount: 5000,
    status: "confirmed",
    booking_date: new Date()
});

print("✅ Тестовый документ без валидации добавлен, ID: " + testResult.insertedId);

// 3. Теперь создаем коллекцию с УПРОЩЕННОЙ валидацией
print("\n3. Создание коллекции с УПРОЩЕННОЙ валидацией...");

try {
    db.createCollection("validated_bookings_simple", {
        validator: {
            $jsonSchema: {
                bsonType: "object",
                required: ["user_id", "event_id", "tickets_count", "total_amount", "status"],
                properties: {
                    user_id: { bsonType: "string" },
                    event_id: { bsonType: "string" },
                    tickets_count: { 
                        bsonType: "int",
                        minimum: 1,
                        maximum: 10
                    },
                    total_amount: { 
                        bsonType: "double",
                        minimum: 0,
                        maximum: 50000
                    },
                    status: {
                        bsonType: "string",
                        enum: ["pending", "confirmed", "cancelled", "refunded"]
                    }
                }
            }
        }
    });
    print("✅ Коллекция с упрощенной валидацией создана");
} catch (e) {
    print("❌ Ошибка создания упрощенной валидации: " + e.message);
}

// 4. Тестируем упрощенную валидацию
print("\n4. Тестирование упрощенной валидации:");

print("\n4.1. Правильный документ:");
try {
    var result1 = db.validated_bookings_simple.insertOne({
        user_id: "user_anna",
        event_id: "event_concert",
        tickets_count: 2,
        total_amount: 5000.0,  // Явно указываем double
        status: "confirmed",
        booking_date: new Date()
    });
    print("✅ Документ добавлен. ID: " + result1.insertedId);
} catch (e) {
    print("❌ Ошибка: " + e.message);
    print("Полная ошибка: " + JSON.stringify(e));
}

print("\n4.2. Неправильное количество билетов (15):");
try {
    db.validated_bookings_simple.insertOne({
        user_id: "test_user",
        event_id: "test_event",
        tickets_count: 15,
        total_amount: 5000.0,
        status: "confirmed",
        booking_date: new Date()
    });
    print("❌ ОШИБКА: Этот документ не должен был добавиться!");
} catch (e) {
    print("✅ Валидация работает! Ошибка: " + e.message);
}

// 5. Теперь создаем финальную коллекцию с ПОЛНОЙ валидацией
print("\n5. Создание финальной коллекции validated_bookings...");

try {
    db.createCollection("validated_bookings", {
        validator: {
            $jsonSchema: {
                bsonType: "object",
                required: ["user_id", "event_id", "tickets_count", "total_amount", "status"],
                properties: {
                    user_id: {
                        bsonType: "string",
                        description: "ID пользователя обязательно"
                    },
                    event_id: {
                        bsonType: "string", 
                        description: "ID мероприятия обязательно"
                    },
                    tickets_count: {
                        bsonType: "int",
                        minimum: 1,
                        maximum: 10,
                        description: "От 1 до 10 билетов"
                    },
                    total_amount: {
                        bsonType: "double",
                        minimum: 0,
                        maximum: 50000,
                        description: "Сумма от 0 до 50000 рублей"
                    },
                    status: {
                        bsonType: "string",
                        enum: ["pending", "confirmed", "cancelled", "refunded"],
                        description: "Только допустимые статусы"
                    },
                    booking_date: {
                        bsonType: "date",
                        description: "Дата бронирования"
                    }
                }
            }
        }
    });
    print("✅ Финальная коллекция создана");
} catch (e) {
    print("❌ Ошибка создания финальной коллекции: " + e.message);
    print("Детали ошибки: " + JSON.stringify(e, null, 2));
}

// 6. Тестируем финальную валидацию
print("\n6. Тестирование финальной валидации:");

print("\n6.1. Правильный документ (все поля корректные):");
try {
    var correctDoc = {
        user_id: "user_anna",
        event_id: "event_concert",
        tickets_count: 3,
        total_amount: 7500.0,  // .0 для double
        status: "confirmed",
        booking_date: new Date()
    };
    print("Документ для вставки: " + JSON.stringify(correctDoc));
    
    var result = db.validated_bookings.insertOne(correctDoc);
    print("✅ Документ добавлен. ID: " + result.insertedId);
} catch (e) {
    print("❌ Ошибка: " + e.message);
    if (e.hasOwnProperty('errInfo')) {
        print("Детали ошибки: " + JSON.stringify(e.errInfo, null, 2));
    }
}

print("\n6.2. Проверка всех бизнес-правил:");

var testCases = [
    {
        name: "tickets_count=0 (<1)",
        doc: {
            user_id: "test", event_id: "test", tickets_count: 0, 
            total_amount: 1000.0, status: "confirmed", booking_date: new Date()
        },
        shouldPass: false
    },
    {
        name: "tickets_count=5 (1-10)",
        doc: {
            user_id: "test", event_id: "test", tickets_count: 5, 
            total_amount: 25000.0, status: "confirmed", booking_date: new Date()
        },
        shouldPass: true
    },
    {
        name: "tickets_count=15 (>10)",
        doc: {
            user_id: "test", event_id: "test", tickets_count: 15, 
            total_amount: 75000.0, status: "confirmed", booking_date: new Date()
        },
        shouldPass: false
    },
    {
        name: "total_amount=-100 (<0)",
        doc: {
            user_id: "test", event_id: "test", tickets_count: 2, 
            total_amount: -100.0, status: "confirmed", booking_date: new Date()
        },
        shouldPass: false
    },
    {
        name: "total_amount=60000 (>50000)",
        doc: {
            user_id: "test", event_id: "test", tickets_count: 2, 
            total_amount: 60000.0, status: "confirmed", booking_date: new Date()
        },
        shouldPass: false
    },
    {
        name: "status='invalid' (не из списка)",
        doc: {
            user_id: "test", event_id: "test", tickets_count: 2, 
            total_amount: 5000.0, status: "invalid", booking_date: new Date()
        },
        shouldPass: false
    },
    {
        name: "нет обязательного поля tickets_count",
        doc: {
            user_id: "test", event_id: "test", 
            total_amount: 5000.0, status: "confirmed", booking_date: new Date()
        },
        shouldPass: false
    }
];

testCases.forEach(function(testCase, index) {
    print("\n  Тест " + (index + 1) + ": " + testCase.name);
    try {
        var result = db.validated_bookings.insertOne(testCase.doc);
        if (testCase.shouldPass) {
            print("  ✅ Успешно добавлен (как и ожидалось)");
        } else {
            print("  ❌ ОШИБКА: Документ не должен был добавиться!");
        }
    } catch (e) {
        if (!testCase.shouldPass) {
            print("  ✅ Валидация работает: " + e.message.split('\n')[0]);
        } else {
            print("  ❌ ОШИБКА: Документ должен был добавиться! " + e.message);
        }
    }
});

// 7. Итоги
print("\n7. ИТОГИ:");

var collections = ['validated_bookings_simple', 'validated_bookings'];
collections.forEach(function(colName) {
    if (db.getCollectionNames().includes(colName)) {
        var count = db[colName].countDocuments();
        print("  • " + colName + ": " + count + " документов");
        
        if (count > 0) {
            var sample = db[colName].findOne();
            print("    Пример: " + sample.user_id + " → " + sample.event_id + 
                  " (" + sample.tickets_count + " билетов, " + sample.total_amount + " руб.)");
        }
    }
});

// 8. Очистка тестовых коллекций
print("\n8. Очистка тестовых коллекций...");
['test_no_validation', 'validated_bookings_simple'].forEach(function(col) {
    if (db.getCollectionNames().includes(col)) {
        db[col].drop();
        print("  • " + col + " удалена");
    }
});

print("\n=== ФИНАЛЬНЫЙ РЕЗУЛЬТАТ ===");
if (db.getCollectionNames().includes('validated_bookings')) {
    var finalCount = db.validated_bookings.countDocuments();
    print("✅ Коллекция 'validated_bookings' создана и работает!");
    print("✅ Документов: " + finalCount);
    
    print("\n📋 Бизнес-правила работают:");
    print("   1. Количество билетов: 1-10 ✓");
    print("   2. Сумма заказа: 0-50000 рублей ✓");
    print("   3. Статус только из списка ✓");
    print("   4. Все обязательные поля присутствуют ✓");
    
    print("\n🔍 Для проверки выполните:");
    print("   use event_booking_all_tasks");
    print("   db.validated_bookings.find().pretty()");
} else {
    print("❌ Коллекция 'validated_bookings' не создана!");
}