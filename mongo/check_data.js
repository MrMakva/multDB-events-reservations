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

    var event = db.events.findOne();
    if (event) {
        print("Мероприятие: " + event.title);
        print("Дата: " + event.date);
        print("Категории: " + (event.categories ? event.categories.join(", ") : "нет"));
    }

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
