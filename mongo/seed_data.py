from pymongo import MongoClient
from datetime import datetime, timedelta
import random
from faker import Faker

fake = Faker('ru_RU')
client = MongoClient('mongodb://localhost:27017/')
db = client.event_booking_system

def clear_all_data():
    """Очистка всех данных"""
    collections = ['events', 'users', 'bookings', 'reviews', 'venues', 'organizers', 'user_activity_logs']
    for collection in collections:
        db[collection].delete_many({})
    print("Все данные очищены")

def create_organizers(count=5):
    """Создание организаторов"""
    organizers = []
    for i in range(count):
        organizer = {
            "name": fake.company(),
            "email": fake.email(),
            "phone": fake.phone_number(),
            "description": fake.text(max_nb_chars=200),
            "rating": round(random.uniform(3.5, 5.0), 1),
            "total_events": random.randint(1, 20)
        }
        organizers.append(organizer)
    
    result = db.organizers.insert_many(organizers)
    print(f"Создано {len(result.inserted_ids)} организаторов")
    return result.inserted_ids

def create_venues(count=5):
    """Создание мест проведения"""
    venues = []
    for i in range(count):
        venue = {
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
            "capacity": random.choice([100, 500, 1000]),
            "sections": [
                {"name": "Партер", "rows": 10, "seats_per_row": 20}
            ]
        }
        venues.append(venue)
    
    result = db.venues.insert_many(venues)
    print(f"Создано {len(result.inserted_ids)} мест проведения")
    return result.inserted_ids

def create_users(count=50):
    """Создание пользователей"""
    users = []
    for i in range(count):
        user = {
            "email": fake.email(),
            "name": fake.name(),
            "phone": fake.phone_number(),
            "preferences": {
                "categories": random.sample(
                    ["концерт", "театр", "спорт", "выставка"], 
                    k=random.randint(1, 2)
                ),
                "notifications": random.choice([True, False])
            },
            "stats": {
                "total_bookings": 0,
                "total_spent": 0,
                "last_booking_date": None
            },
            "booking_history": [],
            "favorites": [],
            "view_history": [],
            "created_at": fake.date_time_between(start_date='-1y', end_date='now'),
            "updated_at": datetime.now()
        }
        users.append(user)
    
    result = db.users.insert_many(users)
    print(f"Создано {len(result.inserted_ids)} пользователей")
    return result.inserted_ids

def create_events(count=30, organizer_ids=None, venue_ids=None):
    """Создание мероприятий"""
    if not organizer_ids:
        organizer_ids = [org['_id'] for org in db.organizers.find()]
    if not venue_ids:
        venue_ids = [venue['_id'] for venue in db.venues.find()]
    
    events = []
    event_titles = [
        "Рок-концерт", "Балет", "Выставка", "Конференция",
        "Матч", "Джазовый вечер", "Стендап", "Фестиваль"
    ]
    
    for i in range(count):
        event_date = fake.date_time_between(start_date='+1d', end_date='+30d')
        capacity = random.choice([100, 200, 500])
        
        event = {
            "title": f"{random.choice(event_titles)} {fake.word().capitalize()}",
            "description": fake.text(max_nb_chars=200),
            "date": event_date,
            "venue_id": random.choice(venue_ids),
            "organizer_id": random.choice(organizer_ids),
            "categories": random.sample(
                ["концерт", "театр", "спорт", "выставка"], 
                k=random.randint(1, 2)
            ),
            "tags": random.sample(
                ["популярное", "новинка"], 
                k=random.randint(1, 2)
            ),
            "ticket_types": [
                {
                    "type": "VIP",
                    "price": random.randint(5000, 15000),
                    "quantity": random.randint(10, 30),
                    "sold": 0
                },
                {
                    "type": "Standard",
                    "price": random.randint(1000, 5000),
                    "quantity": random.randint(50, 200),
                    "sold": 0
                }
            ],
            "status": random.choice(["draft", "published", "published"]),
            "capacity": capacity,
            "available_seats": capacity,
            "created_at": fake.date_time_between(start_date='-30d', end_date='now'),
            "updated_at": datetime.now()
        }
        events.append(event)
    
    result = db.events.insert_many(events)
    print(f"Создано {len(result.inserted_ids)} мероприятий")
    return result.inserted_ids

def create_bookings(count=100, user_ids=None, event_ids=None):
    """Создание бронирований"""
    if not user_ids:
        user_ids = [user['_id'] for user in db.users.find()]
    if not event_ids:
        event_ids = [event['_id'] for event in db.events.find({"status": "published"})]
    
    bookings = []
    
    for i in range(count):
        user_id = random.choice(user_ids)
        event_id = random.choice(event_ids)
        event = db.events.find_one({"_id": event_id})
        
        if not event or event['available_seats'] <= 0:
            continue
            
        ticket_type = random.choice(event['ticket_types'])
        quantity = random.randint(1, 2)
        
        if ticket_type['quantity'] - ticket_type['sold'] < quantity:
            continue
        
        booking_date = fake.date_time_between(
            start_date='-30d', 
            end_date='now'
        )
        
        booking = {
            "user_id": user_id,
            "event_id": event_id,
            "ticket_type": ticket_type['type'],
            "quantity": quantity,
            "total_amount": ticket_type['price'] * quantity,
            "status": random.choice(["confirmed", "confirmed", "cancelled"]),
            "payment_method": random.choice(["cash", "card", "online"]),
            "transaction_id": f"TXN{random.randint(100000, 999999)}",
            "seats": [f"{row}{num}" for row, num in 
                     zip(random.sample(['A', 'B', 'C'], k=quantity),
                         random.sample(range(1, 20), k=quantity))],
            "created_at": booking_date,
            "updated_at": booking_date
        }
        
        bookings.append(booking)

        db.events.update_one(
            {"_id": event_id, "ticket_types.type": ticket_type['type']},
            {
                "$inc": {
                    "ticket_types.$.sold": quantity,
                    "available_seats": -quantity
                }
            }
        )
    
    if bookings:
        result = db.bookings.insert_many(bookings)
        print(f"Создано {len(result.inserted_ids)} бронирований")

        for booking in db.bookings.find():
            event = db.events.find_one({"_id": booking['event_id']})
            if event:
                db.users.update_one(
                    {"_id": booking['user_id']},
                    {
                        "$inc": {
                            "stats.total_bookings": 1,
                            "stats.total_spent": booking['total_amount']
                        },
                        "$set": {
                            "stats.last_booking_date": booking['created_at']
                        },
                        "$push": {
                            "booking_history": {
                                "booking_id": booking['_id'],
                                "event_id": booking['event_id'],
                                "event_title": event['title'],
                                "date": booking['created_at'],
                                "status": booking['status'],
                                "amount": booking['total_amount']
                            }
                        }
                    }
                )
        
        return result.inserted_ids
    else:
        print("Не удалось создать бронирования")
        return []

def create_reviews(count=50, user_ids=None, event_ids=None):
    """Создание отзывов"""
    if not user_ids:
        user_ids = [user['_id'] for user in db.users.find()]
    if not event_ids:
        event_ids = [event['_id'] for event in db.events.find()]
    
    reviews = []
    
    for i in range(count):
        review = {
            "event_id": random.choice(event_ids),
            "user_id": random.choice(user_ids),
            "rating": random.randint(1, 5),
            "comment": fake.text(max_nb_chars=100),
            "created_at": fake.date_time_between(start_date='-60d', end_date='now'),
            "updated_at": datetime.now(),
            "helpful_count": random.randint(0, 10)
        }
        reviews.append(review)
    
    result = db.reviews.insert_many(reviews)
    print(f"Создано {len(result.inserted_ids)} отзывов")
    return result.inserted_ids

def create_view_history():
    """Создание истории просмотров"""
    users = list(db.users.find())
    events = list(db.events.find({"status": "published"}))
    
    for user in users:
        viewed_events = random.sample(events, k=random.randint(1, 10))
        view_history = []
        
        for event in viewed_events:
            view_history.append({
                "event_id": event['_id'],
                "viewed_at": fake.date_time_between(start_date='-30d', end_date='now')
            })

        favorite_events = random.sample(viewed_events, k=random.randint(0, 3))
        favorites = [event['_id'] for event in favorite_events]
        
        db.users.update_one(
            {"_id": user['_id']},
            {
                "$set": {
                    "view_history": view_history,
                    "favorites": favorites
                }
            }
        )
    
    print(f"Создана история просмотров для {len(users)} пользователей")

def main():
    """Основная функция"""
    print("=== Начало генерации тестовых данных ===")
    
    clear_all_data()

    organizer_ids = create_organizers(3)
    venue_ids = create_venues(3)
    user_ids = create_users(30)
    event_ids = create_events(20, organizer_ids, venue_ids)
    booking_ids = create_bookings(80, user_ids, event_ids)
    review_ids = create_reviews(40, user_ids, event_ids)
    create_view_history()
    
    print("\n=== Сводка ===")
    print(f"Организаторы: {db.organizers.count_documents({})}")
    print(f"Места проведения: {db.venues.count_documents({})}")
    print(f"Пользователи: {db.users.count_documents({})}")
    print(f"Мероприятия: {db.events.count_documents({})}")
    print(f"Бронирования: {db.bookings.count_documents({})}")
    print(f"Отзывы: {db.reviews.count_documents({})}")
    total = sum(db[col].count_documents({}) for col in ['events', 'users', 'bookings', 'reviews', 'venues', 'organizers'])
    print(f"Всего документов в основных коллекциях: {total}")
    
    print("\n=== Генерация данных завершена ===")

if __name__ == "__main__":
    main()