try {
    db = db.getSiblingDB('event_booking_system');
    
    db.events.createIndex({ "date": 1 });
    db.events.createIndex({ "status": 1 });
    db.events.createIndex({ "categories": 1 });

    db.users.createIndex({ "email": 1 }, { unique: true });
    db.users.createIndex({ "favorites": 1 });

    db.bookings.createIndex({ "user_id": 1 });
    db.bookings.createIndex({ "event_id": 1 });
    db.bookings.createIndex({ "status": 1 });

    db.reviews.createIndex({ "event_id": 1 });
    db.reviews.createIndex({ "user_id": 1 });
    
    print("✓ Индексы созданы успешно!");

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
