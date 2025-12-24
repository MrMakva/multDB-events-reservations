db = db.getSiblingDB('event_booking_system');

db.dropDatabase();

db.createCollection("events", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["title", "date", "venue_id", "organizer_id", "status"],
         properties: {
            title: { bsonType: "string", description: "Название мероприятия" },
            description: { bsonType: "string" },
            date: { bsonType: "date", description: "Дата и время мероприятия" },
            venue_id: { bsonType: "objectId" },
            organizer_id: { bsonType: "objectId" },
            categories: { bsonType: "array", items: { bsonType: "string" } },
            tags: { bsonType: "array", items: { bsonType: "string" } },
            ticket_types: {
               bsonType: "array",
               items: {
                  bsonType: "object",
                  required: ["type", "price", "quantity"],
                  properties: {
                     type: { bsonType: "string", enum: ["VIP", "Standard", "Student"] },
                     price: { bsonType: "decimal" },
                     quantity: { bsonType: "int", minimum: 0 },
                     sold: { bsonType: "int", minimum: 0 }
                  }
               }
            },
            status: { bsonType: "string", enum: ["draft", "published", "cancelled", "sold_out"] },
            created_at: { bsonType: "date" },
            updated_at: { bsonType: "date" },
            capacity: { bsonType: "int" },
            available_seats: { bsonType: "int" },
            metadata: { bsonType: "object" }
         }
      }
   }
});

db.createCollection("users", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["email", "created_at"],
         properties: {
            email: { bsonType: "string", pattern: "^.+@.+\\..+$" },
            name: { bsonType: "string" },
            phone: { bsonType: "string" },
            preferences: {
               bsonType: "object",
               properties: {
                  categories: { bsonType: "array", items: { bsonType: "string" } },
                  notifications: { bsonType: "bool" }
               }
            },
            stats: {
               bsonType: "object",
               properties: {
                  total_bookings: { bsonType: "int" },
                  total_spent: { bsonType: "decimal" },
                  last_booking_date: { bsonType: "date" }
               }
            },
            created_at: { bsonType: "date" },
            updated_at: { bsonType: "date" },
            booking_history: {
               bsonType: "array",
               items: {
                  bsonType: "object",
                  properties: {
                     booking_id: { bsonType: "objectId" },
                     event_id: { bsonType: "objectId" },
                     event_title: { bsonType: "string" },
                     date: { bsonType: "date" },
                     status: { bsonType: "string" },
                     amount: { bsonType: "decimal" }
                  }
               }
            },
            favorites: {
               bsonType: "array",
               items: { bsonType: "objectId" }
            },
            view_history: {
               bsonType: "array",
               items: {
                  bsonType: "object",
                  properties: {
                     event_id: { bsonType: "objectId" },
                     viewed_at: { bsonType: "date" }
                  }
               }
            }
         }
      }
   }
});

db.createCollection("bookings", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["user_id", "event_id", "status", "created_at"],
         properties: {
            user_id: { bsonType: "objectId" },
            event_id: { bsonType: "objectId" },
            ticket_type: { bsonType: "string", enum: ["VIP", "Standard", "Student"] },
            quantity: { bsonType: "int", minimum: 1 },
            total_amount: { bsonType: "decimal", minimum: 0 },
            status: { bsonType: "string", enum: ["pending", "confirmed", "cancelled", "refunded"] },
            payment_method: { bsonType: "string", enum: ["cash", "card", "online"] },
            transaction_id: { bsonType: "string" },
            seats: { bsonType: "array", items: { bsonType: "string" } },
            created_at: { bsonType: "date" },
            updated_at: { bsonType: "date" },
            cancelled_at: { bsonType: "date" }
         }
      }
   }
});

db.createCollection("reviews", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["event_id", "user_id", "rating", "created_at"],
         properties: {
            event_id: { bsonType: "objectId" },
            user_id: { bsonType: "objectId" },
            rating: { bsonType: "int", minimum: 1, maximum: 5 },
            comment: { bsonType: "string" },
            created_at: { bsonType: "date" },
            updated_at: { bsonType: "date" },
            helpful_count: { bsonType: "int", minimum: 0 }
         }
      }
   }
});

db.createCollection("venues", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["name", "location"],
         properties: {
            name: { bsonType: "string" },
            location: {
               bsonType: "object",
               required: ["type", "coordinates"],
               properties: {
                  type: { bsonType: "string", enum: ["Point"] },
                  coordinates: { bsonType: "array", items: { bsonType: "double" } }
               }
            },
            address: { bsonType: "string" },
            capacity: { bsonType: "int" },
            sections: {
               bsonType: "array",
               items: {
                  bsonType: "object",
                  properties: {
                     name: { bsonType: "string" },
                     rows: { bsonType: "int" },
                     seats_per_row: { bsonType: "int" }
                  }
               }
            }
         }
      }
   }
});

db.createCollection("organizers", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["name", "email"],
         properties: {
            name: { bsonType: "string" },
            email: { bsonType: "string" },
            phone: { bsonType: "string" },
            description: { bsonType: "string" },
            rating: { bsonType: "double", minimum: 0, maximum: 5 },
            total_events: { bsonType: "int" }
         }
      }
   }
});

db.createCollection("user_activity_logs", {
   timeseries: {
      timeField: "timestamp",
      metaField: "user_id",
      granularity: "hours"
   },
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["user_id", "action", "timestamp"],
         properties: {
            user_id: { bsonType: "objectId" },
            action: { bsonType: "string" },
            entity_type: { bsonType: "string", enum: ["event", "booking", "review"] },
            entity_id: { bsonType: "objectId" },
            details: { bsonType: "object" },
            timestamp: { bsonType: "date" },
            ip_address: { bsonType: "string" }
         }
      }
   }
});

console.log("Коллекции созданы успешно!");
