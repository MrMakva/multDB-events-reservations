#!/usr/bin/env python3
# generate_data.py - Генерация тестовых данных для MongoDB
from pymongo import MongoClient
from datetime import datetime, timedelta
import random
from faker import Faker
from bson import ObjectId

fake = Faker('ru_RU')
client = MongoClient('mongodb://localhost:27017/')
db = client.event_booking_system

def generate_data():
    print("=== ГЕНЕРАЦИЯ ТЕСТОВЫХ ДАННЫХ ===")
    
    # Очистка старых данных
    db.events.delete_many({})
    db.users.delete_many({})
    db.bookings.delete_many({})
    db.reviews.delete_many({})
    db.venues.delete_many({})
    db.organizers.delete_many({})
    
    # Генерация организаторов
    organizers = []
    for i in range(10):
        organizer = {
            "_id": ObjectId(),
            "name": fake.company(),
            "email": fake.email(),
            "phone": fake.phone_number(),
            "description": fake.text(max_nb_chars=200),
            "rating": round(random.uniform(3.5, 5.0), 1),
            "total_events": random.randint(1, 50)
        }
        organizers.append(organizer)
    
    db.organizers.insert_many(organizers)
    print(f"Создано организаторов: {len(organizers)}")
    
    # Генерация мест проведения
    venues = []
    for i in range(15):
        venue = {
            "_id": ObjectId(),
            "name": fake.random_element([
                "Кремлевский дворец", "Стадион Лужники", 
                "Театр им. Вахтангова", "Концертный зал Чайковского"
            ]),
            "location": {
                "type": "Point",
                "coordinates": [
                    round(random.uniform(37.0, 38.0), 6),
                    round(random.uniform(55.0, 56.0), 6)
                ]
            },
            "address": fake.address(),
            "capacity": random.choice([100, 500, 1000, 5000]),
            "sections": [
                {"name": "Партер", "rows": 20, "seats_per_row": 25},
                {"name": "Балкон", "rows": 15, "seats_per_row": 20}
            ]
        }
        venues.append(venue)
    
    db.venues.insert_many(venues)
    print(f"Создано мест проведения: {len(venues)}")
    
    # Генерация пользователей
    users = []
    for i in range(200):
        user = {
            "_id": ObjectId(),
            "email": fake.email(),
            "name": fake.name(),
            "phone": fake.phone_number(),
            "preferences": {
                "categories": random.sample(
                    ["концерт", "театр", "спорт", "выставка"], 
                    k=random.randint(1, 3)
                ),
                "notifications": random.choice([True, False])
            },
            "stats": {
                "total_bookings": 0,
                "total_spent": 0.0,
                "last_booking_date": None
            },
            "booking_history": [],
            "favorites": [],
            "view_history": [],
            "created_at": fake.date_time_between(start_date='-2y', end_date='now'),
            "updated_at": datetime.now()
        }
        users.append(user)
    
    db.users.insert_many(users)
    print(f"Создано пользователей: {len(users)}")
    
    # Генерация мероприятий
    events = []
    for i in range(100):
        capacity = random.choice([100, 200, 500, 1000])
        event = {
            "_id": ObjectId(),
            "title": f"{fake.random_element(['Концерт', 'Спектакль', 'Матч', 'Выставка'])} {fake.word().capitalize()}",
            "description": fake.text(max_nb_chars=500),
            "date": fake.date_time_between(start_date='+1d', end_date='+90d'),
            "venue_id": random.choice(venues)["_id"],
            "organizer_id": random.choice(organizers)["_id"],
            "categories": random.sample(
                ["концерт", "театр", "спорт", "выставка", "фестиваль"], 
                k=random.randint(1, 3)
            ),
            "tags": random.sample(["популярное", "новинка", "рекомендуем"], k=random.randint(1, 2)),
            "ticket_types": [
                {
                    "type": "VIP",
                    "price": random.randint(5000, 20000),
                    "quantity": random.randint(10, 50),
                    "sold": 0
                },
                {
                    "type": "Standard",
                    "price": random.randint(1000, 5000),
                    "quantity": random.randint(100, 500),
                    "sold": 0
                },
                {
                    "type": "Student",
                    "price": random.randint(500, 2000),
                    "quantity": random.randint(50, 200),
                    "sold": 0
                }
            ],
            "status": random.choice(["draft", "published", "published", "published"]),
            "capacity": capacity,
            "available_seats": capacity,
            "created_at": fake.date_time_between(start_date='-30d', end_date='now'),
            "updated_at": datetime.now()
        }
        events.append(event)
    
    db.events.insert_many(events)
    print(f"Создано мероприятий: {len(events)}")
    
    # Генерация бронирований
    bookings = []
    for i in range(300):
        user = random.choice(users)
        event = random.choice(events)
        
        ticket_type = random.choice(event["ticket_types"])
        quantity = random.randint(1, 4)
        total_amount = ticket_type["price"] * quantity
        
        # ИСПРАВЛЕННЫЙ КОД: больше рядов для выборки
        rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']
        seats = [f"{row}{num}" for row, num in 
                 zip(random.sample(rows, k=quantity),
                     random.sample(range(1, 30), k=quantity))]
        
        booking = {
            "_id": ObjectId(),
            "user_id": user["_id"],
            "event_id": event["_id"],
            "ticket_type": ticket_type["type"],
            "quantity": quantity,
            "total_amount": total_amount,
            "status": random.choice(["confirmed", "confirmed", "cancelled"]),
            "payment_method": random.choice(["cash", "card", "online"]),
            "transaction_id": f"TXN{random.randint(100000, 999999)}",
            "seats": seats,
            "created_at": fake.date_time_between(start_date='-60d', end_date='now'),
            "updated_at": datetime.now()
        }
        bookings.append(booking)
    
    db.bookings.insert_many(bookings)
    print(f"Создано бронирований: {len(bookings)}")
    
    # Обновление статистики пользователей и истории
    for booking in bookings:
        # Находим событие
        event = next(e for e in events if e["_id"] == booking["event_id"])
        
        # Обновляем пользователя
        db.users.update_one(
            {"_id": booking["user_id"]},
            {
                "$inc": {
                    "stats.total_bookings": 1,
                    "stats.total_spent": booking["total_amount"]
                },
                "$set": {
                    "stats.last_booking_date": booking["created_at"]
                },
                "$push": {
                    "booking_history": {
                        "booking_id": booking["_id"],
                        "event_id": booking["event_id"],
                        "event_title": event["title"],
                        "date": booking["created_at"],
                        "status": booking["status"],
                        "amount": booking["total_amount"]
                    }
                }
            }
        )
    
    # Генерация отзывов
    reviews = []
    for i in range(150):
        review = {
            "_id": ObjectId(),
            "event_id": random.choice(events)["_id"],
            "user_id": random.choice(users)["_id"],
            "rating": random.randint(1, 5),
            "comment": fake.text(max_nb_chars=200),
            "created_at": fake.date_time_between(start_date='-60d', end_date='now'),
            "helpful_count": random.randint(0, 50)
        }
        reviews.append(review)
    
    db.reviews.insert_many(reviews)
    print(f"Создано отзывов: {len(reviews)}")
    
    # Генерация истории просмотров и избранного
    for user in users:
        viewed_events = random.sample(events, k=random.randint(5, 20))
        view_history = []
        
        for event in viewed_events:
            view_history.append({
                "event_id": event["_id"],
                "viewed_at": fake.date_time_between(start_date='-30d', end_date='now')
            })
        
        # Добавляем в избранное
        favorites = random.sample(viewed_events, k=random.randint(2, 5))
        
        db.users.update_one(
            {"_id": user["_id"]},
            {
                "$set": {
                    "view_history": view_history,
                    "favorites": [e["_id"] for e in favorites]
                }
            }
        )
    
    print("\n=== СВОДКА ===")
    print(f"Организаторы: {db.organizers.count_documents({})}")
    print(f"Места проведения: {db.venues.count_documents({})}")
    print(f"Пользователи: {db.users.count_documents({})}")
    print(f"Мероприятия: {db.events.count_documents({})}")
    print(f"Бронирования: {db.bookings.count_documents({})}")
    print(f"Отзывы: {db.reviews.count_documents({})}")
    
    total = (db.organizers.count_documents({}) + db.venues.count_documents({}) + 
             db.users.count_documents({}) + db.events.count_documents({}) + 
             db.bookings.count_documents({}) + db.reviews.count_documents({}))
    print(f"Всего документов: {total}")
    
    print("\n✓ Генерация данных завершена!")

if __name__ == "__main__":
    generate_data()