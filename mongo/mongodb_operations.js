db = db.getSiblingDB('event_booking_system');

var testData = {
    userId: null,
    eventIds: [],
    bookingIds: []
};

var currentStep = 0;
var totalSteps = 10;
var autoMode = false;

function printHeader(text) {
    print("\n" + "=".repeat(50));
    print(` ${text}`);
    print("=".repeat(50));
}

function printStep(step, title) {
    print(`\nШаг ${step}/${totalSteps}: ${title}`);
    print("-".repeat(40));
}

function waitForInput(promptText) {
    if (autoMode) {
        print(`⏩ Автоматический режим: пропускаем ввод`);
        var start = new Date().getTime();
        while (new Date().getTime() < start + 100000) { /* ждем 1 секунду */ }
        return;
    }
    
    print(`\n⏳ ${promptText}`);
    print("Нажмите Enter для продолжения...");

    try {
        var input = readline();
        return input;
    } catch (e) {
        try {
            var input = readLine();
            return input;
        } catch (e2) {
            print("(автопродолжение через 2 секунды...)");
            var start = new Date().getTime();
            while (new Date().getTime() < start + 2000) { /* ждем 2 секунды */ }
            return "";
        }
    }
}

function showMenu() {
    print("\n" + "=".repeat(60));
    print(" УПРАВЛЕНИЕ ДЕМОНСТРАЦИЕЙ MONGODB ОПЕРАЦИЙ");
    print("=".repeat(60));
    
    print(`\nТекущий шаг: ${currentStep}/${totalSteps}`);
    print(`Режим: ${autoMode ? "Автоматический" : "Ручной"}`);
    
    print("\nДоступные команды:");
    print("  n / next     - Следующий шаг");
    print("  p / prev     - Предыдущий шаг");
    print("  j [номер]    - Перейти к шагу [номер]");
    print("  a / auto     - Включить/выключить автоматический режим");
    print("  s / status   - Показать статус");
    print("  t / test     - Показать тестовые данные");
    print("  m / menu     - Показать это меню");
    print("  e / exit     - Завершить демонстрацию");
    print("  r / run      - Выполнить все шаги автоматически");
    print("  c / cleanup  - Очистить тестовые данные");
    
    print("\nШаги демонстрации:");
    print("  1. INSERT операции");
    print("  2. UPDATE операции ($set, $inc)");
    print("  3. UPDATE операции ($push, $addToSet)");
    print("  4. UPDATE операции ($arrayFilters)");
    print("  5. DELETE операции");
    print("  6. REPLACE и UPSERT операции");
    print("  7. ПОИСК с фильтрами ($and, $or)");
    print("  8. ПОИСК с фильтрами ($in, $nin, $gt, $lt)");
    print("  9. СОЗДАНИЕ ИНДЕКСОВ");
    print("  10. ПРОВЕРКА ИНДЕКСОВ и очистка");
    
    print("\n" + "-".repeat(60));
}

function showStatus() {
    print("\nСТАТУС ДЕМОНСТРАЦИИ:");
    print(`  Текущий шаг: ${currentStep}/${totalSteps}`);
    print(`  Создано тестовых данных:`);
    print(`    - Пользователей: ${testData.userId ? 1 : 0}`);
    print(`    - Мероприятий: ${testData.eventIds.length}`);
    print(`    - Бронирований: ${testData.bookingIds.length}`);

    var collections = ['events', 'users', 'bookings', 'reviews'];
    print(`\n  Коллекции в базе данных:`);
    collections.forEach(col => {
        var count = db[col].countDocuments();
        print(`    - ${col}: ${count} документов`);
    });
}

function showTestData() {
    print("\n🔍 ТЕСТОВЫЕ ДАННЫЕ:");
    print(`  ID тестового пользователя: ${testData.userId || "Не создан"}`);
    print(`  ID тестовых мероприятий: ${testData.eventIds.length} штук`);
    if (testData.eventIds.length > 0) {
        testData.eventIds.forEach((id, i) => {
            var event = db.events.findOne({_id: id}, {title: 1});
            print(`    ${i+1}. ${id} - ${event ? event.title : "Не найден"}`);
        });
    }
    print(`  ID тестовых бронирований: ${testData.bookingIds.length} штук`);
}

function cleanupTestData() {
    print("\n🧹 ОЧИСТКА ТЕСТОВЫХ ДАННЫХ...");
    
    var cleanupResults = {};
    
    if (testData.userId) {
        cleanupResults.users = db.users.deleteOne({_id: testData.userId});
    }
    
    if (testData.eventIds.length > 0) {
        cleanupResults.events = db.events.deleteMany({_id: {$in: testData.eventIds}});
    }
    
    if (testData.bookingIds.length > 0) {
        cleanupResults.bookings = db.bookings.deleteMany({_id: {$in: testData.bookingIds}});
    }

    ['sessions', 'temp_notifications', 'temp_collection'].forEach(col => {
        if (db.getCollectionNames().includes(col)) {
            db[col].drop();
            cleanupResults[col] = {dropped: true};
        }
    });
    
    print("Очистка завершена:");
    Object.keys(cleanupResults).forEach(key => {
        if (cleanupResults[key].deletedCount !== undefined) {
            print(`  - ${key}: удалено ${cleanupResults[key].deletedCount} документов`);
        } else if (cleanupResults[key].dropped) {
            print(`  - ${key}: коллекция удалена`);
        }
    });

    testData = { userId: null, eventIds: [], bookingIds: [] };
}

function executeStep(step) {
    currentStep = step;
    
    switch(step) {
        case 1:
            step1_insertOperations();
            break;
        case 2:
            step2_updateSetInc();
            break;
        case 3:
            step3_updatePushAddToSet();
            break;
        case 4:
            step4_updateArrayFilters();
            break;
        case 5:
            step5_deleteOperations();
            break;
        case 6:
            step6_replaceUpsert();
            break;
        case 7:
            step7_searchAndOr();
            break;
        case 8:
            step8_searchInNinGtLt();
            break;
        case 9:
            step9_createIndexes();
            break;
        case 10:
            step10_checkIndexesAndCleanup();
            break;
        default:
            print(`Неизвестный шаг: ${step}`);
    }
}

function step1_insertOperations() {
    printStep(1, "INSERT ОПЕРАЦИИ");
    
    print("\n1.1. insertOne - создание тестового пользователя");
    var newUser = {
        email: "demo.user@example.com",
        name: "Демо Пользователь",
        phone: "+79991234567",
        preferences: {
            categories: ["концерт", "театр"],
            notifications: true
        },
        stats: {
            total_bookings: 0,
            total_spent: 0
        },
        created_at: new Date()
    };
    
    var insertResult = db.users.insertOne(newUser);
    testData.userId = insertResult.insertedId;
    print(`Создан пользователь с ID: ${testData.userId}`);
    
    waitForInput("Показать созданного пользователя");
    
    var createdUser = db.users.findOne({_id: testData.userId});
    print("Данные пользователя:");
    printjson(createdUser);
    
    print("\n1.2. insertMany - создание тестовых мероприятий");
    var newEvents = [
        {
            title: "Демо: Джазовый вечер",
            description: "Вечер живой джазовой музыки",
            date: new Date("2024-03-15T20:00:00Z"),
            categories: ["концерт", "джаз"],
            tags: ["живая музыка", "вечер"],
            status: "published",
            capacity: 150,
            available_seats: 150,
            created_at: new Date()
        },
        {
            title: "Демо: Выставка искусств",
            description: "Современное искусство от местных художников",
            date: new Date("2024-03-20T10:00:00Z"),
            categories: ["выставка", "искусство"],
            tags: ["выставка", "современное"],
            status: "published",
            capacity: 200,
            available_seats: 200,
            created_at: new Date()
        },
        {
            title: "Демо: Мастер-класс (черновик)",
            description: "Обучение основам фотографии для начинающих",
            date: new Date("2024-03-25T14:00:00Z"),
            categories: ["мастер-класс", "образование"],
            tags: ["обучение", "фотография"],
            status: "draft",
            capacity: 30,
            available_seats: 30,
            created_at: new Date()
        }
    ];
    
    var insertManyResult = db.events.insertMany(newEvents);
    testData.eventIds = Object.values(insertManyResult.insertedIds);
    print(`Создано мероприятий: ${insertManyResult.insertedCount}`);
    print(`   ID созданных мероприятий: ${testData.eventIds.join(", ")}`);
    
    waitForInput("Показать созданные мероприятия");
    
    var createdEvents = db.events.find({_id: {$in: testData.eventIds}}).toArray();
    createdEvents.forEach((event, i) => {
        print(`${i+1}. ${event.title} (${event.status}) - ${event.date.toISOString().split('T')[0]}`);
    });
    
    print("\nВыполнено: insertOne и insertMany");
}

function step2_updateSetInc() {
    printStep(2, "UPDATE ОПЕРАЦИИ ($set, $inc)");
    
    if (!testData.userId || testData.eventIds.length === 0) {
        print("Сначала выполните шаг 1 (создание данных)");
        return;
    }
    
    print("\n2.1. updateOne с $set - обновление описания мероприятия");
    var eventId = testData.eventIds[0];
    var updateResult = db.events.updateOne(
        { _id: eventId },
        {
            $set: {
                description: "ЭКСКЛЮЗИВ  Вечер живой джазовой музыки с участием известных музыкантов",
                updated_at: new Date(),
                organizer: "Jazz Club International"
            }
        }
    );
    
    print(`Обновлено мероприятий: ${updateResult.modifiedCount}`);
    
    waitForInput("Показать обновленное мероприятие");
    
    var updatedEvent = db.events.findOne({_id: eventId});
    print("Обновленное мероприятие:");
    print(`   Заголовок: ${updatedEvent.title}`);
    print(`   Описание: ${updatedEvent.description.substring(0, 80)}...`);
    print(`   Организатор: ${updatedEvent.organizer || "не указан"}`);
    
    print("\n 2.2. updateMany с $inc - увеличение счетчиков");

    var testBookings = [
        {
            user_id: testData.userId,
            event_id: testData.eventIds[0],
            ticket_type: "Standard",
            quantity: 2,
            total_amount: 3000,
            status: "pending",
            created_at: new Date()
        },
        {
            user_id: testData.userId,
            event_id: testData.eventIds[1],
            ticket_type: "VIP",
            quantity: 1,
            total_amount: 5000,
            status: "pending",
            created_at: new Date()
        }
    ];
    
    var bookingsResult = db.bookings.insertMany(testBookings);
    testData.bookingIds = Object.values(bookingsResult.insertedIds);
    print(`Создано тестовых бронирований: ${bookingsResult.insertedCount}`);
    
    print("\n 2.3. updateMany с $inc - увеличение суммы бронирований");
    var incResult = db.bookings.updateMany(
        { status: "pending" },
        {
            $inc: { total_amount: 500 },
            $set: { updated_at: new Date() }
        }
    );
    
    print(`Обновлено бронирований с увеличенной суммой: ${incResult.modifiedCount}`);
    
    waitForInput("Показать обновленные бронирования");
    
    var updatedBookings = db.bookings.find({_id: {$in: testData.bookingIds}}).toArray();
    updatedBookings.forEach((booking, i) => {
        print(`${i+1}. Сумма: ${booking.total_amount}, Статус: ${booking.status}`);
    });
    
    print("\nВыполнено: updateOne/Many с $set и $inc");
}

function step3_updatePushAddToSet() {
    printStep(3, "UPDATE ОПЕРАЦИИ ($push, $addToSet)");
    
    if (!testData.userId) {
        print("Сначала выполните шаг 1 (создание пользователя)");
        return;
    }
    
    print("\n3.1. updateOne с $push - добавление в избранное");
    var pushResult = db.users.updateOne(
        { _id: testData.userId },
        {
            $push: {
                favorites: testData.eventIds[0],
                "view_history": {
                    event_id: testData.eventIds[0],
                    viewed_at: new Date(),
                    duration_seconds: 120
                }
            }
        }
    );
    
    print(`Добавлено мероприятие в избранное пользователя`);
    
    waitForInput("Показать обновленного пользователя");
    
    var userWithFavorites = db.users.findOne(
        {_id: testData.userId},
        {name: 1, email: 1, favorites: 1, "view_history.event_id": 1}
    );
    
    print("Пользователь с избранным:");
    print(`   Имя: ${userWithFavorites.name}`);
    print(`   Email: ${userWithFavorites.email}`);
    print(`   В избранном: ${userWithFavorites.favorites ? userWithFavorites.favorites.length : 0} мероприятий`);
    
    print("\n3.2. updateMany с $addToSet - уникальное добавление категорий");
    var addToSetResult = db.users.updateMany(
        { "preferences.categories": { $exists: true } },
        {
            $addToSet: {
                "preferences.categories": {
                    $each: ["выставка", "мастер-класс"]
                }
            }
        }
    );
    
    print(`Обновлено пользователей с добавлением категорий: ${addToSetResult.modifiedCount}`);
    print("   Категории 'выставка' и 'мастер-класс' добавлены только если их еще нет");
    
    waitForInput("Показать добавленные категории у тестового пользователя");
    
    var userCategories = db.users.findOne(
        {_id: testData.userId},
        {"preferences.categories": 1}
    );
    
    print("Категории пользователя:");
    if (userCategories && userCategories.preferences && userCategories.preferences.categories) {
        userCategories.preferences.categories.forEach((cat, i) => {
            print(`   ${i+1}. ${cat}`);
        });
    }
    
    print("\nВыполнено: update с $push и $addToSet");
}

function step4_updateArrayFilters() {
    printStep(4, "UPDATE ОПЕРАЦИИ ($arrayFilters)");
    
    print("\n4.1. Создание мероприятия со сложной структурой билетов");
    var complexEvent = {
        title: "Демо: Конференция IT-разработчиков",
        description: "Годовой саммит IT-специалистов",
        ticket_types: [
            { type: "Standard", price: 5000, available: true, features: ["доступ на все дни", "кофе-брейк"] },
            { type: "VIP", price: 15000, available: true, features: ["доступ на все дни", "питание", "сет"] },
            { type: "Student", price: 2500, available: false, features: ["доступ на 1 день"] }
        ],
        status: "published",
        created_at: new Date()
    };
    
    var complexEventResult = db.events.insertOne(complexEvent);
    var complexEventId = complexEventResult.insertedId;
    testData.eventIds.push(complexEventId);
    
    print(`Создано мероприятие со сложной структурой билетов: ${complexEventId}`);
    
    waitForInput("Показать структуру билетов до обновления");
    
    var eventBefore = db.events.findOne({_id: complexEventId});
    print("Структура билетов ДО обновления:");
    eventBefore.ticket_types.forEach((ticket, i) => {
        print(`   ${i+1}. ${ticket.type}: ${ticket.price} руб. (доступен: ${ticket.available})`);
    });
    
    print("\n4.2. updateOne с $arrayFilters - обновление конкретного элемента массива");
    var arrayFilterResult = db.events.updateOne(
        { _id: complexEventId },
        {
            $set: {
                "ticket_types.$[ticket].price": 2000,
                "ticket_types.$[ticket].available": true,
                "ticket_types.$[ticket].features": ["доступ на все дни", "кофе-брейк", "материалы"]
            }
        },
        {
            arrayFilters: [
                { "ticket.type": "Student" }
            ]
        }
    );
    
    print(`Обновлен студенческий билет через arrayFilters: ${arrayFilterResult.modifiedCount > 0 ? "Да" : "Нет"}`);
    
    waitForInput("Показать структуру билетов после обновления");
    
    var eventAfter = db.events.findOne({_id: complexEventId});
    print("Структура билетов ПОСЛЕ обновления:");
    eventAfter.ticket_types.forEach((ticket, i) => {
        print(`   ${i+1}. ${ticket.type}: ${ticket.price} руб. (доступен: ${ticket.available})`);
        print(`      Особенности: ${ticket.features.join(", ")}`);
    });
    
    print("\n4.3. Обновление нескольких элементов массива");
    var multiArrayFilterResult = db.events.updateOne(
        { _id: complexEventId },
        {
            $set: {
                "ticket_types.$[elem].updated": new Date()
            }
        },
        {
            arrayFilters: [
                { "elem.price": { $lt: 10000 } } // Все билеты дешевле 10000
            ]
        }
    );
    
    print(`Обновлено элементов массива: ${multiArrayFilterResult.modifiedCount > 0 ? "Да" : "Нет"}`);
    
    print("\nВыполнено: update с $arrayFilters");
}

function step5_deleteOperations() {
    printStep(5, "DELETE ОПЕРАЦИИ");
    
    print("\n 5.1. deleteOne - удаление одного документа");

    var tempDoc = db.events.insertOne({
        title: "Временное мероприятие для удаления",
        status: "draft",
        created_at: new Date()
    });
    
    print(`Создан временный документ для демонстрации удаления: ${tempDoc.insertedId}`);
    
    waitForInput("Выполнить deleteOne");
    
    var deleteOneResult = db.events.deleteOne({ _id: tempDoc.insertedId });
    print(`Удалено документов: ${deleteOneResult.deletedCount}`);
    
    print("\n5.2. deleteMany - удаление нескольких документов");

    var tempDocs = db.temp_collection.insertMany([
        { type: "temp", category: "A", value: 1 },
        { type: "temp", category: "A", value: 2 },
        { type: "temp", category: "B", value: 3 },
        { type: "keep", category: "C", value: 4 }
    ]);
    
    var beforeCount = db.temp_collection.countDocuments({ type: "temp" });
    print(`Создано временных документов: ${beforeCount}`);
    
    waitForInput("Выполнить deleteMany (удалить все type: 'temp')");
    
    var deleteManyResult = db.temp_collection.deleteMany({ type: "temp" });
    var afterCount = db.temp_collection.countDocuments({ type: "temp" });
    
    print(`Удалено документов: ${deleteManyResult.deletedCount}`);
    print(`Осталось документов type='temp': ${afterCount}`);
    
    db.temp_collection.drop();
    print("Временная коллекция удалена");
    
    print("\n5.3. Удаление с фильтрами");
    
    if (testData.bookingIds.length > 0) {
        waitForInput("Удалить тестовые бронирования со статусом 'pending'");
        
        var pendingCount = db.bookings.countDocuments({ 
            _id: { $in: testData.bookingIds },
            status: "pending" 
        });
        
        var deleteFilteredResult = db.bookings.deleteMany({ 
            _id: { $in: testData.bookingIds },
            status: "pending" 
        });
        
        print(`Удалено бронирований со статусом 'pending': ${deleteFilteredResult.deletedCount} из ${pendingCount}`);
        
        testData.bookingIds = testData.bookingIds.filter(id => {
            var booking = db.bookings.findOne({_id: id});
            return booking !== null;
        });
    }
    
    print("\nВыполнено: deleteOne и deleteMany");
}

function step6_replaceUpsert() {
    printStep(6, "REPLACE и UPSERT ОПЕРАЦИИ");
    
    if (!testData.userId) {
        print("Сначала выполните шаг 1 (создание пользователя)");
        return;
    }
    
    print("\n6.1. replaceOne - полная замена документа");
    
    var userToReplace = db.users.findOne({ _id: testData.userId });
    print("Пользователь ДО замены:");
    print(`   Имя: ${userToReplace.name}`);
    print(`   Телефон: ${userToReplace.phone}`);
    print(`   Статус: ${userToReplace.status || "не установлен"}`);
    
    waitForInput("Выполнить replaceOne");

    var newUserDoc = {
        email: userToReplace.email,
        name: "Обновленный Демо Пользователь",
        phone: "+79998887766",
        status: "active",
        membership_level: "premium",
        updated_at: new Date(),
        replaced_at: new Date()
    };
    
    var replaceResult = db.users.replaceOne(
        { _id: testData.userId },
        newUserDoc
    );
    
    print(` Документ заменен: ${replaceResult.modifiedCount > 0 ? "Да" : "Нет"}`);
    
    waitForInput("Показать пользователя после замены");
    
    var replacedUser = db.users.findOne({ _id: testData.userId });
    print(" Пользователь ПОСЛЕ замены:");
    printjson(replacedUser);
    
    print("\n 6.2. upsert - обновить или создать");
    
    var testEmail = "upsert.test@example.com";
    print(`Проверяем пользователя с email: ${testEmail}`);
    
    var existingUser = db.users.findOne({ email: testEmail });
    print(`Существует ли пользователь: ${existingUser ? "Да" : "Нет"}`);
    
    waitForInput("Выполнить upsert (создать нового пользователя)");
    
    var upsertResult1 = db.users.updateOne(
        { email: testEmail },
        {
            $setOnInsert: {
                email: testEmail,
                name: "Upsert Созданный Пользователь",
                created_at: new Date()
            },
            $set: {
                updated_at: new Date(),
                last_operation: "upsert_create"
            }
        },
        { upsert: true }
    );
    
    if (upsertResult1.upsertedId) {
        print(` Создан новый пользователь с ID: ${upsertResult1.upsertedId}`);
    }
    
    waitForInput("Выполнить upsert (обновить существующего)");
    
    var upsertResult2 = db.users.updateOne(
        { email: testEmail },
        {
            $set: {
                name: "Upsert Обновленный Пользователь",
                updated_at: new Date(),
                last_operation: "upsert_update",
                login_count: { $inc: 1 }
            }
        },
        { upsert: true }
    );
    
    print(`Upsert выполнен: ${upsertResult2.modifiedCount > 0 ? "Обновлен существующий" : "Создан новый"}`);
    
    var upsertedUser = db.users.findOne({ email: testEmail });
    print("Результат upsert:");
    print(`   Имя: ${upsertedUser.name}`);
    print(`   Email: ${upsertedUser.email}`);
    print(`   Последняя операция: ${upsertedUser.last_operation}`);

    db.users.deleteOne({ email: testEmail });
    print(" Тестовый upsert пользователь удален");
    
    print("\n Выполнено: replaceOne и upsert");
}

function step7_searchAndOr() {
    printStep(7, "ПОИСК с фильтрами ($and, $or)");
    
    print("\n 7.1. Простая проекция (выбор полей)");
    
    var projectedEvents = db.events.find(
        { status: "published" },
        { 
            title: 1, 
            date: 1, 
            categories: 1,
            available_seats: 1,
            _id: 0 
        }
    ).limit(5).toArray();
    
    print("Мероприятия (только заголовок, дата, категории, свободные места):");
    projectedEvents.forEach((event, i) => {
        var dateStr = event.date ? event.date.toISOString().split('T')[0] : "нет даты";
        print(`   ${i+1}. ${event.title}`);
        print(`      Дата: ${dateStr}, Категории: ${event.categories ? event.categories.join(", ") : "нет"}`);
        print(`      Свободных мест: ${event.available_seats || 0}`);
    });
    
    waitForInput("Продолжить с $and фильтрами");
    
    print("\n 7.2. Фильтр с $and (ВСЕ условия должны выполняться)");
    
    var andResult = db.events.find({
        $and: [
            { status: "published" },
            { capacity: { $gt: 100 } },
            { available_seats: { $gt: 0 } },
            { date: { $gt: new Date() } }
        ]
    }, {
        title: 1,
        status: 1,
        capacity: 1,
        available_seats: 1,
        date: 1
    }).limit(3).toArray();
    
    print("Мероприятия (опубликованные, capacity > 100, есть свободные места, будущие):");
    if (andResult.length === 0) {
        print("   Нет результатов, соответствующих всем условиям");
    } else {
        andResult.forEach((event, i) => {
            print(`   ${i+1}. ${event.title}`);
            print(`      Статус: ${event.status}, Вместимость: ${event.capacity}`);
            print(`      Свободно: ${event.available_seats}, Дата: ${event.date.toISOString().split('T')[0]}`);
        });
    }
    
    waitForInput("Продолжить с $or фильтрами");
    
    print("\n 7.3. Фильтр с $or (хотя бы ОДНО условие должно выполняться)");
    
    var orResult = db.events.find({
        $or: [
            { categories: "концерт" },
            { categories: "джаз" },
            { "tags": "живая музыка" },
            { capacity: { $lt: 100 } }
        ]
    }, {
        title: 1,
        categories: 1,
        tags: 1,
        capacity: 1
    }).limit(5).toArray();
    
    print("Мероприятия (категория 'концерт' ИЛИ 'джаз' ИЛИ тег 'живая музыка' ИЛИ capacity < 100):");
    orResult.forEach((event, i) => {
        var matches = [];
        if (event.categories && event.categories.includes("концерт")) matches.push("концерт");
        if (event.categories && event.categories.includes("джаз")) matches.push("джаз");
        if (event.tags && event.tags.includes("живая музыка")) matches.push("живая музыка");
        if (event.capacity < 100) matches.push("малая вместимость");
        
        print(`   ${i+1}. ${event.title}`);
        print(`      Категории: ${event.categories ? event.categories.join(", ") : "нет"}`);
        print(`      Совпадения: ${matches.join(", ")}`);
    });
    
    print("\n Выполнено: поиск с $and и $or фильтрами");
}

function step8_searchInNinGtLt() {
    printStep(8, "ПОИСК с фильтрами ($in, $nin, $gt, $lt)");
    
    print("\n 8.1. Фильтр с $in (значение находится в массиве)");
    
    var inResult = db.events.find({
        status: { $in: ["published", "draft"] },
        categories: { $in: ["концерт", "выставка", "искусство"] }
    }, {
        title: 1,
        status: 1,
        categories: 1
    }).limit(5).toArray();
    
    print(" Мероприятия (статус: published/draft, категория: концерт/выставка/искусство):");
    inResult.forEach((event, i) => {
        print(`   ${i+1}. ${event.title}`);
        print(`      Статус: ${event.status}, Категории: ${event.categories.join(", ")}`);
    });
    
    waitForInput("Продолжить с $nin фильтрами");
    
    print("\n 8.2. Фильтр с $nin (значение НЕ находится в массиве)");
    
    var ninResult = db.events.find({
        status: { $nin: ["cancelled", "sold_out", "archived"] },
        categories: { $nin: ["спорт", "образование"] }
    }, {
        title: 1,
        status: 1,
        categories: 1
    }).limit(5).toArray();
    
    print("Мероприятия (статус НЕ cancelled/sold_out/archived, категория НЕ спорт/образование):");
    ninResult.forEach((event, i) => {
        print(`   ${i+1}. ${event.title}`);
        print(`      Статус: ${event.status}, Категории: ${event.categories ? event.categories.join(", ") : "нет"}`);
    });
    
    waitForInput("Продолжить с $gt и $lt фильтрами");
    
    print("\n 8.3. Фильтр с $gt (больше) и $lt (меньше)");
    
    var nextMonth = new Date();
    nextMonth.setMonth(nextMonth.getMonth() + 1);
    
    var gtltResult = db.events.find({
        date: {
            $gt: new Date(),           // Будущие мероприятия
            $lt: nextMonth             // В течение месяца
        },
        capacity: {
            $gt: 50,                   // Вместимость больше 50
            $lt: 500                   // Вместимость меньше 500
        },
        available_seats: { $gt: 0 }    // Есть свободные места
    }, {
        title: 1,
        date: 1,
        capacity: 1,
        available_seats: 1
    }).limit(5).toArray();
    
    print(" Мероприятия (ближайший месяц, вместимость 50-500, есть свободные места):");
    if (gtltResult.length === 0) {
        print("   Нет результатов, соответствующих условиям");
    } else {
        gtltResult.forEach((event, i) => {
            print(`   ${i+1}. ${event.title}`);
            print(`      Дата: ${event.date.toISOString().split('T')[0]}`);
            print(`      Вместимость: ${event.capacity}, Свободно: ${event.available_seats}`);
        });
    }
    
    print("\n 8.4. Сложный комбинированный фильтр");
    
    var complexResult = db.users.find({
        $and: [
            { "stats.total_bookings": { $exists: true } },
            {
                $or: [
                    { "stats.total_bookings": { $gt: 0, $lt: 5 } },
                    { "preferences.categories": { $in: ["концерт", "театр"] } }
                ]
            },
            { created_at: { $lt: new Date() } }
        ]
    }, {
        name: 1,
        email: 1,
        "stats.total_bookings": 1,
        "preferences.categories": 1,
        created_at: 1
    }).limit(3).toArray();
    
    print(" Пользователи (имеют бронирования 1-4 ИЛИ интересуются концертами/театром):");
    complexResult.forEach((user, i) => {
        var created = user.created_at ? user.created_at.toISOString().split('T')[0] : "неизвестно";
        print(`   ${i+1}. ${user.name} (${user.email})`);
        print(`      Бронирований: ${user.stats ? user.stats.total_bookings || 0 : 0}`);
        print(`      Интересы: ${user.preferences && user.preferences.categories ? user.preferences.categories.join(", ") : "нет"}`);
        print(`      Создан: ${created}`);
    });
    
    print("\nВыполнено: поиск с $in, $nin, $gt, $lt фильтрами");
}

function step9_createIndexes() {
    printStep(9, "СОЗДАНИЕ ИНДЕКСОВ");

    print("\n 9.1. Очистка старых индексов...");
    var collections = ['events', 'users', 'bookings', 'reviews'];
    collections.forEach(col => {
        var indexes = db[col].getIndexes();
        indexes.forEach(idx => {
            if (idx.name !== '_id_') {
                try {
                    db[col].dropIndex(idx.name);
                    print(`   Удален индекс ${idx.name} из коллекции ${col}`);
                } catch (e) {
                }
            }
        });
    });
    
    waitForInput("Начать создание новых индексов");
    
    print("\n 9.2. Создание одиночных индексов:");
    
    db.events.createIndex({ "date": 1 }, { name: "idx_events_date" });
    print(" events.date - для сортировки по дате");
    
    db.users.createIndex({ "email": 1 }, { name: "idx_users_email", unique: true });
    print(" users.email (unique) - уникальный email");
    
    db.bookings.createIndex({ "status": 1 }, { name: "idx_bookings_status" });
    print(" bookings.status - для фильтрации по статусу");
    
    db.reviews.createIndex({ "rating": -1 }, { name: "idx_reviews_rating" });
    print(" reviews.rating - для сортировки по рейтингу");
    
    waitForInput("Создать составные индексы");
    
    print("\n 9.3. Создание составные индексы:");
    
    db.events.createIndex({ "status": 1, "date": 1 }, { name: "idx_events_status_date" });
    print(" events.status + date - для поиска опубликованных будущих мероприятий");
    
    db.bookings.createIndex({ "user_id": 1, "created_at": -1 }, { name: "idx_bookings_user_created" });
    print(" bookings.user_id + created_at - для истории бронирований пользователя");
    
    db.bookings.createIndex({ "event_id": 1, "status": 1 }, { name: "idx_bookings_event_status" });
    print(" bookings.event_id + status - для статистики по мероприятиям");
    
    waitForInput("Создать индексы по массивам");
    
    print("\n 9.4. Создание индексы по массивам:");
    
    db.events.createIndex({ "categories": 1 }, { name: "idx_events_categories" });
    print(" events.categories - для поиска по категориям");
    
    db.users.createIndex({ "favorites": 1 }, { name: "idx_users_favorites" });
    print(" users.favorites - для поиска пользователей по избранному");
    
    db.events.createIndex({ "tags": 1 }, { name: "idx_events_tags" });
    print(" events.tags - для поиска по тегам");
    
    waitForInput("Создать partial индексы");
    
    print("\n 9.5. Создание partial индексов (только для подмножества):");
    
    db.events.createIndex(
        { "available_seats": 1 },
        { 
            name: "idx_events_available_seats_partial",
            partialFilterExpression: { 
                status: "published",
                available_seats: { $gt: 0 }
            }
        }
    );
    print(" events.available_seats (только published и available_seats > 0)");
    print("   Экономит место, т.к. индексирует только доступные мероприятия");
    
    db.bookings.createIndex(
        { "updated_at": -1 },
        {
            name: "idx_bookings_updated_recent",
            partialFilterExpression: {
                status: { $in: ["confirmed", "pending"] }
            }
        }
    );
    print(" bookings.updated_at (только confirmed/pending бронирования)");
    
    waitForInput("Создать TTL индексы");
    
    print("\n 9.6. Создание TTL индексов (автоудаление):");

    db.sessions.insertMany([
        { user_id: testData.userId, token: "session_abc123", created_at: new Date() },
        { user_id: testData.userId, token: "session_old", created_at: new Date(Date.now() - 2*24*60*60*1000) }
    ]);
    
    db.sessions.createIndex(
        { "created_at": 1 },
        { 
            name: "idx_sessions_ttl",
            expireAfterSeconds: 24 * 60 * 60 // 1 день
        }
    );
    print(" sessions.created_at (TTL 24 часа) - сессии удаляются через день");

    db.temp_notifications.insertMany([
        { type: "welcome", user_id: testData.userId, sent_at: new Date() },
        { type: "reminder", user_id: testData.userId, sent_at: new Date(Date.now() - 3*60*60*1000) }
    ]);
    
    db.temp_notifications.createIndex(
        { "sent_at": 1 },
        {
            name: "idx_temp_notifications_ttl",
            expireAfterSeconds: 7 * 24 * 60 * 60 // 7 дней
        }
    );
    print("temp_notifications.sent_at (TTL 7 дней) - уведомления удаляются через неделю");
    
    waitForInput("Создать текстовый индекс");
    
    print("\n 9.7. Создание текстового индекса (full-text search):");
    
    db.events.createIndex(
        { 
            title: "text",
            description: "text",
            tags: "text"
        },
        {
            name: "idx_events_text_search",
            weights: {
                title: 10,      // Заголовок самый важный
                tags: 5,        // Теги средней важности
                description: 1   // Описание наименее важное
            },
            default_language: "russian"
        }
    );
    print("events.title/description/tags - текстовый поиск по мероприятиям");
    print("   Веса: title=10, tags=5, description=1");
    
    print("\n Выполнено: созданы все типы индексов");
}

function step10_checkIndexesAndCleanup() {
    printStep(10, "ПРОВЕРКА ИНДЕКСОВ и ОЧИСТКА");
    
    print("\n10.1. Проверка созданных индексов:");
    
    var collections = ['events', 'users', 'bookings', 'reviews', 'sessions', 'temp_notifications'];
    collections.forEach(col => {
        if (db.getCollectionNames().includes(col)) {
            var indexes = db[col].getIndexes();
            if (indexes.length > 0) {
                print(`\n${col}:`);
                indexes.forEach(idx => {
                    var ttlInfo = idx.expireAfterSeconds ? ` (TTL: ${idx.expireAfterSeconds} сек)` : '';
                    var partialInfo = idx.partialFilterExpression ? ` (partial)` : '';
                    var typeInfo = idx.textIndexVersion ? ` (текстовый)` : '';
                    print(`  - ${idx.name}: ${JSON.stringify(idx.key)}${ttlInfo}${partialInfo}${typeInfo}`);
                });
            }
        }
    });
    
    waitForInput("Проверить использование индексов");
    
    print("\n 10.2. Проверка использования индексов (explain):");
    
    print("\na) Поиск с использованием составного индекса:");
    var indexedSearch = db.events.find(
        { status: "published", date: { $gt: new Date() } }
    ).explain("executionStats");
    
    var indexUsed = indexedSearch.executionStats.executionStages.inputStage ?
                   indexedSearch.executionStats.executionStages.inputStage.indexName :
                   "Не использован";
    
    print(`   Использован индекс: ${indexUsed}`);
    print(`   Время выполнения: ${indexedSearch.executionStats.executionTimeMillis} мс`);
    print(`   Документов проверено: ${indexedSearch.executionStats.totalDocsExamined}`);
    print(`   Документов возвращено: ${indexedSearch.executionStats.nReturned}`);
    
    print("\nb) Текстовый поиск:");
    var textSearchResult = db.events.find(
        { $text: { $search: "джаз музыка" } },
        { score: { $meta: "textScore" } }
    ).sort({ score: { $meta: "textScore" } }).limit(2).toArray();
    
    print("   Результаты поиска 'джаз музыка':");
    if (textSearchResult.length === 0) {
        print("   Нет результатов");
    } else {
        textSearchResult.forEach((event, i) => {
            print(`   ${i+1}. ${event.title} (релевантность: ${event.score ? event.score.toFixed(2) : "N/A"})`);
        });
    }
    
    print("\nc) Проверка partial индекса:");
    var partialIndexQuery = db.events.find(
        { status: "published", available_seats: { $gt: 50 } }
    ).explain("executionStats");
    
    var partialIndexUsed = partialIndexQuery.executionStats.executionStages.inputStage ?
                          partialIndexQuery.executionStats.executionStages.inputStage.indexName :
                          "Нет";
    
    print(`   Запрос использует partial индекс: ${partialIndexUsed}`);
    print(`   Эффективность: ${partialIndexQuery.executionStats.totalDocsExamined} документов проверено для ${partialIndexQuery.executionStats.nReturned} результатов`);
    
    print("\nd) Проверка TTL индекса:");
    print("   Коллекция sessions (TTL 24 часа):");
    var sessionCount = db.sessions.countDocuments();
    print(`   Документов до TTL очистки: ${sessionCount}`);
    
    print("\n   Коллекция temp_notifications (TTL 7 дней):");
    var notificationCount = db.temp_notifications.countDocuments();
    print(`   Документов до TTL очистки: ${notificationCount}`);
    
    waitForInput("Выполнить очистку тестовых данных");
    
    print("\n 10.3. Очистка тестовых данных:");
    cleanupTestData();
    
    print("\n" + "=".repeat(60));
    print("ДЕМОНСТРАЦИЯ УСПЕШНО ЗАВЕРШЕНА!");
    print("=".repeat(60));
    
    print("\n Выполнены все операции:");
    print("1. INSERT: insertOne, insertMany ✓");
    print("2. UPDATE: $set, $inc ✓");
    print("3. UPDATE: $push, $addToSet ✓");
    print("4. UPDATE: $arrayFilters ✓");
    print("5. DELETE: deleteOne, deleteMany ✓");
    print("6. REPLACE и UPSERT ✓");
    print("7. ПОИСК: $and, $or, проекции ✓");
    print("8. ПОИСК: $in, $nin, $gt, $lt ✓");
    print("9. ИНДЕКСЫ: все типы созданы ✓");
    print("10. ПРОВЕРКА индексов и очистка ✓");
    
    print("\n Все шаги выполнены успешно!");
}

// ========== ГЛАВНЫЙ ЦИКЛ ==========
function main() {
    printHeader("ДЕМОНСТРАЦИЯ ОПЕРАЦИЙ MONGODB");
    print("Автоматическая демонстрация всех базовых операций MongoDB");
    print("База данных: event_booking_system");
    
    showMenu();
    
    // В mongosh/mongo shell нет нормального readline, делаем упрощенный ввод
    while (true) {
        try {
            print(`\n[Шаг ${currentStep}/${totalSteps}] Введите команду (n - следующий, e - выход, m - меню):`);
            
            // Попробуем разные способы чтения ввода
            var command;
            try {
                command = readline();
            } catch (e) {
                try {
                    command = readLine();
                } catch (e2) {
                    // Если не работает ввод, используем автопродолжение
                    print("(используется автопродолжение...)");
                    if (currentStep < totalSteps) {
                        currentStep++;
                        executeStep(currentStep);
                    } else {
                        print(" Все шаги выполнены!");
                        break;
                    }
                    continue;
                }
            }
            
            if (!command) continue;
            
            command = command.trim().toLowerCase();
            
            switch(command) {
                case 'n':
                case 'next':
                    if (currentStep < totalSteps) {
                        currentStep++;
                        executeStep(currentStep);
                    } else {
                        print(" Выполнены все шаги!");
                    }
                    break;
                    
                case 'p':
                case 'prev':
                    if (currentStep > 0) {
                        currentStep--;
                        executeStep(currentStep);
                    } else {
                        print("  Вы уже на первом шаге");
                    }
                    break;
                    
                case 'a':
                case 'auto':
                    autoMode = !autoMode;
                    print(`Режим изменен на: ${autoMode ? "Автоматический" : "Ручной"}`);
                    if (autoMode) {
                        print("Следующие шаги будут выполняться автоматически");
                    }
                    break;
                    
                case 's':
                case 'status':
                    showStatus();
                    break;
                    
                case 't':
                case 'test':
                    showTestData();
                    break;
                    
                case 'm':
                case 'menu':
                    showMenu();
                    break;
                    
                case 'e':
                case 'exit':
                    print("\nЗавершение демонстрации...");
                    cleanupTestData();
                    print("Тестовые данные очищены");
                    print("До свидания!");
                    return;
                    
                case 'r':
                case 'run':
                    print("\nЗапуск автоматического выполнения всех шагов...");
                    autoMode = true;
                    for (var i = 1; i <= totalSteps; i++) {
                        print(`\n▶️  Выполнение шага ${i}/${totalSteps}...`);
                        currentStep = i;
                        executeStep(i);
                        var start = new Date().getTime();
                        while (new Date().getTime() < start + 2000) { /* ждем 2 секунды */ }
                    }
                    autoMode = false;
                    print("\n Все шаги выполнены автоматически!");
                    break;
                    
                case 'c':
                case 'cleanup':
                    cleanupTestData();
                    break;
                    
                default:
                    if (command.startsWith('j ')) {
                        var stepNum = parseInt(command.split(' ')[1]);
                        if (stepNum >= 1 && stepNum <= totalSteps) {
                            currentStep = stepNum;
                            executeStep(currentStep);
                        } else {
                            print(` Неверный номер шага. Допустимо: 1-${totalSteps}`);
                        }
                    } else if (!isNaN(parseInt(command))) {
                        var stepNum = parseInt(command);
                        if (stepNum >= 1 && stepNum <= totalSteps) {
                            currentStep = stepNum;
                            executeStep(currentStep);
                        } else {
                            print(` Неверный номер шага. Допустимо: 1-${totalSteps}`);
                        }
                    } else {
                        print(" Неизвестная команда. Введите 'm' для просмотра меню");
                    }
            }
        } catch (error) {
            print(` Ошибка: ${error}`);
            print("Продолжаем выполнение...");
        }
    }
}

// Запуск основной программы
try {
    main();
} catch (e) {
    print(` Критическая ошибка: ${e}`);
    print("Завершение программы...");
    try {
        cleanupTestData();
    } catch (cleanupError) {
        print(`Ошибка при очистке: ${cleanupError}`);
    }
}