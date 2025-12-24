db = db.getSiblingDB('event_booking_system');

console.log("=== АГРЕГАЦИОННЫЕ PIPELINES ===\n");

console.log("Pipeline 1: Каталог мероприятий с тегами и отзывами");
const pipeline1 = [
    {
        $match: {
            status: "published",
            date: { $gte: new Date() }
        }
    },
    {
        $lookup: {
            from: "reviews",
            localField: "_id",
            foreignField: "event_id",
            as: "reviews",
            pipeline: [
                {
                    $sort: { created_at: -1 }
                },
                {
                    $limit: 5
                }
            ]
        }
    },
    {
        $lookup: {
            from: "venues",
            localField: "venue_id",
            foreignField: "_id",
            as: "venue"
        }
    },
    {
        $unwind: "$venue"
    },
    {
        $lookup: {
            from: "organizers",
            localField: "organizer_id",
            foreignField: "_id",
            as: "organizer"
        }
    },
    {
        $unwind: "$organizer"
    },
    {
        $project: {
            title: 1,
            description: 1,
            date: 1,
            categories: 1,
            tags: 1,
            available_seats: 1,
            venue: {
                name: "$venue.name",
                address: "$venue.address"
            },
            organizer: {
                name: "$organizer.name",
                rating: "$organizer.rating"
            },
            ticket_types: 1,
            review_count: { $size: "$reviews" },
            average_rating: {
                $cond: {
                    if: { $gt: [{ $size: "$reviews" }, 0] },
                    then: { $avg: "$reviews.rating" },
                    else: 0
                }
            },
            recent_reviews: {
                $slice: ["$reviews", 3]
            }
        }
    },
    {
        $sort: { date: 1 }
    },
    {
        $limit: 10
    }
];

const result1 = db.events.aggregate(pipeline1).toArray();
console.log("Каталог мероприятий:");
result1.forEach((event, i) => {
    console.log(`${i+1}. ${event.title} - ${event.venue.name}`);
    console.log(`   Отзывы: ${event.review_count}, Рейтинг: ${event.average_rating.toFixed(1)}★`);
});

console.log("\nPipeline 2: История пользователя");
const pipeline2 = [
    {
        $match: {
            "stats.total_bookings": { $gte: 2 }
        }
    },
    {
        $project: {
            name: 1,
            email: 1,
            total_bookings: "$stats.total_bookings",
            total_spent: "$stats.total_spent",
            favorites_count: { $size: "$favorites" },
            view_history_count: { $size: "$view_history" },
            booking_history: {
                $slice: ["$booking_history", 5]
            },
            recent_views: {
                $slice: [
                    {
                        $sortArray: {
                            input: "$view_history",
                            sortBy: { viewed_at: -1 }
                        }
                    },
                    5
                ]
            },
            favorite_categories: {
                $reduce: {
                    input: "$preferences.categories",
                    initialValue: [],
                    in: { $concatArrays: ["$$value", ["$$this"]] }
                }
            }
        }
    },
    {
        $lookup: {
            from: "events",
            localField: "favorites",
            foreignField: "_id",
            as: "favorite_events",
            pipeline: [
                {
                    $project: {
                        title: 1,
                        date: 1,
                        categories: 1
                    }
                }
            ]
        }
    },
    {
        $project: {
            name: 1,
            email: 1,
            total_bookings: 1,
            total_spent: 1,
            activity_summary: {
                bookings: "$booking_history",
                favorites_count: "$favorites_count",
                favorite_events: "$favorite_events",
                views_count: "$view_history_count",
                recent_views: "$recent_views",
                preferred_categories: "$favorite_categories"
            }
        }
    },
    {
        $sort: { "stats.total_spent": -1 }
    },
    {
        $limit: 5
    }
];

const result2 = db.users.aggregate(pipeline2).toArray();
console.log("Пользователи с историей:");
result2.forEach((user, i) => {
    console.log(`${i+1}. ${user.name} (${user.email})`);
    console.log(`   Бронирований: ${user.total_bookings}, Потрачено: ${user.total_spent}`);
});

console.log("\nPipeline 3: Популярность по просмотрам");
const pipeline3 = [
    {
        $unwind: "$view_history"
    },
    {
        $group: {
            _id: "$view_history.event_id",
            view_count: { $sum: 1 },
            unique_users: { $addToSet: "$_id" }
        }
    },
    {
        $match: {
            view_count: { $gte: 10 }
        }
    },
    {
        $lookup: {
            from: "events",
            localField: "_id",
            foreignField: "_id",
            as: "event_info"
        }
    },
    {
        $unwind: "$event_info"
    },
    {
        $lookup: {
            from: "bookings",
            localField: "_id",
            foreignField: "event_id",
            as: "bookings"
        }
    },
    {
        $project: {
            event_title: "$event_info.title",
            view_count: 1,
            unique_users_count: { $size: "$unique_users" },
            booking_count: { $size: "$bookings" },
            conversion_rate: {
                $multiply: [
                    {
                        $divide: [
                            { $size: "$bookings" },
                            "$view_count"
                        ]
                    },
                    100
                ]
            },
            categories: "$event_info.categories",
            tags: "$event_info.tags"
        }
    },
    {
        $match: {
            conversion_rate: { $gt: 0 }
        }
    },
    {
        $sort: { view_count: -1 }
    },
    {
        $limit: 10
    }
];

const result3 = db.users.aggregate(pipeline3).toArray();
console.log("Популярные мероприятия по просмотрам:");
result3.forEach((event, i) => {
    console.log(`${i+1}. ${event.event_title}`);
    console.log(`   Просмотров: ${event.view_count}, Конверсия: ${event.conversion_rate.toFixed(1)}%`);
});

console.log("\nPipeline 4: Топ категорий по избранному");
const pipeline4 = [
    {
        $unwind: "$favorites"
    },
    {
        $lookup: {
            from: "events",
            localField: "favorites",
            foreignField: "_id",
            as: "event_info"
        }
    },
    {
        $unwind: "$event_info"
    },
    {
        $unwind: "$event_info.categories"
    },
    {
        $group: {
            _id: "$event_info.categories",
            favorite_count: { $sum: 1 },
            unique_users: { $addToSet: "$_id" },
            events: { $addToSet: "$event_info._id" }
        }
    },
    {
        $lookup: {
            from: "bookings",
            let: { eventIds: "$events" },
            pipeline: [
                {
                    $match: {
                        $expr: { $in: ["$event_id", "$$eventIds"] }
                    }
                },
                {
                    $group: {
                        _id: null,
                        total_bookings: { $sum: 1 },
                        total_revenue: { $sum: "$total_amount" }
                    }
                }
            ],
            as: "booking_stats"
        }
    },
    {
        $project: {
            category: "$_id",
            favorite_count: 1,
            unique_users_count: { $size: "$unique_users" },
            events_count: { $size: "$events" },
            total_bookings: {
                $ifNull: [{ $arrayElemAt: ["$booking_stats.total_bookings", 0] }, 0]
            },
            total_revenue: {
                $ifNull: [{ $arrayElemAt: ["$booking_stats.total_revenue", 0] }, 0]
            }
        }
    },
    {
        $sort: { favorite_count: -1 }
    },
    {
        $limit: 10
    }
];

const result4 = db.users.aggregate(pipeline4).toArray();
console.log("Популярные категории:");
result4.forEach((cat, i) => {
    console.log(`${i+1}. ${cat.category}: ${cat.favorite_count} добавлений в избранное`);
});

console.log("\nPipeline 5: Полный отчет по мероприятию");
const pipeline5 = [
    {
        $match: {
            status: "published",
            date: { $gte: new Date() }
        }
    },
    {
        $lookup: {
            from: "bookings",
            localField: "_id",
            foreignField: "event_id",
            as: "bookings",
            pipeline: [
                {
                    $match: { status: "confirmed" }
                }
            ]
        }
    },
    {
        $lookup: {
            from: "reviews",
            localField: "_id",
            foreignField: "event_id",
            as: "reviews"
        }
    },
    {
        $lookup: {
            from: "users",
            let: { eventId: "$_id" },
            pipeline: [
                {
                    $match: {
                        $expr: { $in: ["$$eventId", "$favorites"] }
                    }
                },
                {
                    $count: "count"
                }
            ],
            as: "in_favorites"
        }
    },
    {
        $lookup: {
            from: "users",
            let: { eventId: "$_id" },
            pipeline: [
                {
                    $unwind: "$view_history"
                },
                {
                    $match: {
                        $expr: { $eq: ["$view_history.event_id", "$$eventId"] }
                    }
                },
                {
                    $count: "count"
                }
            ],
            as: "view_stats"
        }
    },
    {
        $project: {
            title: 1,
            date: 1,
            categories: 1,
            tags: 1,
            venue_id: 1,
            organizer_id: 1,
            ticket_types: 1,
            available_seats: 1,
            total_bookings: { $size: "$bookings" },
            total_tickets_sold: {
                $sum: "$bookings.quantity"
            },
            total_revenue: {
                $sum: "$bookings.total_amount"
            },
            avg_rating: {
                $cond: {
                    if: { $gt: [{ $size: "$reviews" }, 0] },
                    then: { $avg: "$reviews.rating" },
                    else: 0
                }
            },
            review_count: { $size: "$reviews" },
            in_favorites_count: {
                $ifNull: [{ $arrayElemAt: ["$in_favorites.count", 0] }, 0]
            },
            view_count: {
                $ifNull: [{ $arrayElemAt: ["$view_stats.count", 0] }, 0]
            },
            conversion_rate: {
                $cond: {
                    if: { $gt: [{ $ifNull: [{ $arrayElemAt: ["$view_stats.count", 0] }, 0] }, 0] },
                    then: {
                        $multiply: [
                            {
                                $divide: [
                                    { $size: "$bookings" },
                                    { $ifNull: [{ $arrayElemAt: ["$view_stats.count", 0] }, 1] }
                                ]
                            },
                            100
                        ]
                    },
                    else: 0
                }
            },
            occupancy_rate: {
                $multiply: [
                    {
                        $divide: [
                            { $sum: "$bookings.quantity" },
                            "$capacity"
                        ]
                    },
                    100
                ]
            }
        }
    },
    {
        $match: {
            total_bookings: { $gt: 0 }
        }
    },
    {
        $sort: { total_revenue: -1 }
    },
    {
        $limit: 10
    }
];

const result5 = db.events.aggregate(pipeline5).toArray();
console.log("Топ мероприятий по выручке:");
result5.forEach((event, i) => {
    console.log(`${i+1}. ${event.title}`);
    console.log(`   Выручка: ${event.total_revenue}, Заполняемость: ${event.occupancy_rate.toFixed(1)}%`);
});

console.log("\nPipeline 6: Отчет по пользовательскому поведению");
const pipeline6 = [
    {
        $match: {
            "stats.total_bookings": { $gte: 1 }
        }
    },
    {
        $project: {
            name: 1,
            email: 1,
            created_at: 1,
            stats: 1,
            favorites_count: { $size: "$favorites" },
            view_history_count: { $size: "$view_history" },
            booking_history_count: { $size: "$booking_history" },
            days_since_last_activity: {
                $divide: [
                    {
                        $subtract: [
                            new Date(),
                            {
                                $max: [
                                    "$stats.last_booking_date",
                                    { $arrayElemAt: ["$view_history.viewed_at", 0] }
                                ]
                            }
                        ]
                    },
                    1000 * 60 * 60 * 24
                ]
            }
        }
    },
    {
        $bucket: {
            groupBy: "$days_since_last_activity",
            boundaries: [0, 7, 30, 90, 180, 365, Infinity],
            default: "older",
            output: {
                count: { $sum: 1 },
                avg_bookings: { $avg: "$stats.total_bookings" },
                avg_spent: { $avg: "$stats.total_spent" },
                avg_favorites: { $avg: "$favorites_count" },
                avg_views: { $avg: "$view_history_count" }
            }
        }
    },
    {
        $sort: { _id: 1 }
    }
];

const result6 = db.users.aggregate(pipeline6).toArray();
console.log("Распределение пользователей по активности:");
result6.forEach((bucket, i) => {
    const days = bucket._id === "older" ? "365+" : bucket._id;
    console.log(`${i+1}. ${days} дней: ${bucket.count} пользователей`);
    console.log(`   Средние бронирования: ${bucket.avg_bookings.toFixed(1)}`);
});

console.log("\n=== АГРЕГАЦИИ ЗАВЕРШЕНЫ ===");

console.log("\n=== СОЗДАНИЕ МАТЕРИАЛИЗОВАННОЙ ВИТРИНЫ ===");

db.createCollection("user_behavior_dashboard", {
    viewOn: "users",
    pipeline: [
        {
            $match: {
                "stats.total_bookings": { $gte: 0 }
            }
        },
        {
            $lookup: {
                from: "user_activity_logs",
                localField: "_id",
                foreignField: "user_id",
                as: "activity_logs"
            }
        },
        {
            $project: {
                _id: 1,
                name: 1,
                email: 1,
                created_at: 1,
                total_bookings: "$stats.total_bookings",
                total_spent: "$stats.total_spent",
                last_booking_date: "$stats.last_booking_date",
                favorites_count: { $size: "$favorites" },
                view_history_count: { $size: "$view_history" },
                preferred_categories: "$preferences.categories",
                activity_count: { $size: "$activity_logs" },
                last_activity_date: { $max: "$activity_logs.timestamp" },
                activity_types: {
                    $reduce: {
                        input: "$activity_logs",
                        initialValue: [],
                        in: {
                            $cond: {
                                if: { $in: ["$$this.action", "$$value"] },
                                then: "$$value",
                                else: { $concatArrays: ["$$value", ["$$this.action"]] }
                            }
                        }
                    }
                }
            }
        }
    ]
});

console.log("Витрина создана: user_behavior_dashboard");
console.log(`Записей в витрине: ${db.user_behavior_dashboard.countDocuments({})}`);

db.user_behavior_dashboard.createIndex({ "total_spent": -1 });
db.user_behavior_dashboard.createIndex({ "last_activity_date": -1 });
db.user_behavior_dashboard.createIndex({ "preferred_categories": 1 });

console.log("Индексы для витрины созданы");
