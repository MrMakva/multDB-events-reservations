db = db.getSiblingDB('event_booking_system');

print("==================================================================");
print("БЕНЧМАРК ИНДЕКСОВ: ЗАМЕР ПРОИЗВОДИТЕЛЬНОСТИ ДО/ПОСЛЕ");
print("==================================================================\n");

print(" Очистка старых тестовых индексов...");
var collections = ['events', 'users', 'bookings', 'reviews'];
collections.forEach(col => {
    if (db.getCollectionNames().includes(col)) {
        var indexes = db[col].getIndexes();
        indexes.forEach(idx => {
            if (idx.name !== '_id_' && idx.name.startsWith('benchmark_')) {
                try {
                    db[col].dropIndex(idx.name);
                    print(`   Удален индекс: ${idx.name}`);
                } catch (e) {
                }
            }
        });
    }
});

print("\nПодготовка тестовых данных...");

var eventsCount = db.events.countDocuments();
var usersCount = db.users.countDocuments();
var bookingsCount = db.bookings.countDocuments();

print(`   events: ${eventsCount} документов`);
print(`   users: ${usersCount} документов`);
print(`   bookings: ${bookingsCount} документов`);

if (eventsCount < 50) {
    print(" Мало данных для тестирования. Создаем дополнительные тестовые данные...");

    var newEvents = [];
    for (var i = 0; i < 100; i++) {
        newEvents.push({
            title: `Тестовое мероприятие ${i}`,
            description: `Описание тестового мероприятия ${i}`,
            date: new Date(Date.now() + Math.random() * 30 * 24 * 60 * 60 * 1000),
            categories: i % 3 === 0 ? ["концерт"] : i % 3 === 1 ? ["театр"] : ["выставка"],
            tags: ["тест", "демо"],
            status: "published",
            capacity: Math.floor(Math.random() * 500) + 50,
            available_seats: Math.floor(Math.random() * 500) + 50,
            created_at: new Date(Date.now() - Math.random() * 365 * 24 * 60 * 60 * 1000)
        });
    }
    
    if (newEvents.length > 0) {
        db.events.insertMany(newEvents);
        print(`Добавлено ${newEvents.length} тестовых мероприятий`);
    }
}

function formatTime(ms) {
    if (ms === undefined || ms === null || isNaN(ms)) return "N/A";
    if (ms < 1) return "<1 мс";
    if (ms < 1000) return `${ms.toFixed(1)} мс`;
    return `${(ms/1000).toFixed(2)} сек`;
}

function getExecutionStats(queryFunc) {
    try {
        var explainResult = queryFunc();
        
        if (explainResult && typeof explainResult === 'object') {

            var stats = {};

            if (explainResult.executionStats) {
                stats.executionTimeMillis = explainResult.executionStats.executionTimeMillis;
                stats.totalDocsExamined = explainResult.executionStats.totalDocsExamined;
                stats.totalKeysExamined = explainResult.executionStats.totalKeysExamined || 0;
                stats.executionStages = explainResult.executionStats.executionStages;
            } 
            else if (explainResult.millis !== undefined) {
                stats.executionTimeMillis = explainResult.millis;
                stats.totalDocsExamined = explainResult.nscannedObjects || explainResult.docsExamined || 0;
                stats.totalKeysExamined = explainResult.nscanned || explainResult.keysExamined || 0;
                stats.executionStages = explainResult.executionStages;
            }
            else {
                stats.executionTimeMillis = explainResult.executionTimeMillis || 0;
                stats.totalDocsExamined = explainResult.totalDocsExamined || 0;
                stats.totalKeysExamined = explainResult.totalKeysExamined || 0;
                stats.executionStages = explainResult.executionStages;
            }

            stats.indexUsed = "COLLSCAN (без индекса)";
            if (stats.executionStages) {
                if (stats.executionStages.inputStage && stats.executionStages.inputStage.indexName) {
                    stats.indexUsed = stats.executionStages.inputStage.indexName;
                } else if (stats.executionStages.stage === "IXSCAN") {
                    stats.indexUsed = stats.executionStages.indexName || "IXSCAN";
                } else if (stats.executionStages.inputStage && stats.executionStages.inputStage.stage === "IXSCAN") {
                    stats.indexUsed = stats.executionStages.inputStage.indexName || "IXSCAN";
                }
            }
            
            return stats;
        }
    } catch (e) {
        print(`   Ошибка explain: ${e.message}`);
    }
    
    return {
        executionTimeMillis: 0,
        totalDocsExamined: 0,
        totalKeysExamined: 0,
        indexUsed: "Ошибка",
        executionStages: null
    };
}

function benchmarkQuery(queryName, queryFunc, iterations) {
    print(`\n${queryName}`);
    print("-".repeat(50));
    
    var totalTime = 0;
    var totalDocsExamined = 0;
    var totalKeysExamined = 0;
    var indexUsed = null;
    var validIterations = 0;
    
    for (var i = 0; i < iterations; i++) {
        try {
            var stats = getExecutionStats(queryFunc);
            
            if (stats && stats.executionTimeMillis !== undefined) {
                totalTime += stats.executionTimeMillis;
                totalDocsExamined += stats.totalDocsExamined;
                totalKeysExamined += stats.totalKeysExamined;
                
                if (!indexUsed && stats.indexUsed) {
                    indexUsed = stats.indexUsed;
                }
                
                validIterations++;
            }
        } catch (e) {
            print(` Ошибка итерации ${i+1}: ${e.message}`);
        }
    }
    
    if (validIterations === 0) {
        print(` Нет валидных результатов для ${queryName}`);
        return null;
    }
    
    var avgTime = totalTime / validIterations;
    var avgDocsExamined = totalDocsExamined / validIterations;
    var avgKeysExamined = totalKeysExamined / validIterations;
    
    print(`   Итераций выполнено: ${validIterations}/${iterations}`);
    print(`   Среднее время: ${formatTime(avgTime)}`);
    print(`   Документов проверено: ${Math.round(avgDocsExamined)}`);
    print(`   Использован индекс: ${indexUsed || "Не определен"}`);
    
    return {
        queryName: queryName,
        avgTime: avgTime,
        avgDocsExamined: avgDocsExamined,
        avgKeysExamined: avgKeysExamined,
        indexUsed: indexUsed || "Не определен"
    };
}

function printComparison(before, after) {
    if (!before || !after) {
        print("Нет данных для сравнения");
        return;
    }
    
    print("\n" + "=".repeat(70));
    print(`СРАВНЕНИЕ: ${before.queryName}`);
    print("=".repeat(70));
    
    print("\nРЕЗУЛЬТАТЫ:");
    print("               |      ДО индекса     |     ПОСЛЕ индекса    |   УЛУЧШЕНИЕ   ");
    print("---------------|---------------------|----------------------|---------------");
    
    var timeImprovement = 0;
    var timeDiff = 0;
    
    if (before.avgTime > 0 && after.avgTime > 0) {
        timeImprovement = ((before.avgTime - after.avgTime) / before.avgTime * 100);
        timeDiff = before.avgTime - after.avgTime;
    }
    
    print(`Время         | ${formatTime(before.avgTime).padStart(10)} | ${formatTime(after.avgTime).padStart(10)} | ${timeImprovement.toFixed(1)}% (${formatTime(timeDiff)})`);
    
    var docsImprovement = 0;
    if (before.avgDocsExamined > 0) {
        docsImprovement = ((before.avgDocsExamined - after.avgDocsExamined) / before.avgDocsExamined * 100);
    }
    print(`Документов    | ${Math.round(before.avgDocsExamined).toString().padStart(10)} | ${Math.round(after.avgDocsExamined).toString().padStart(10)} | ${docsImprovement.toFixed(1)}%`);
    
    if (after.avgKeysExamined > 0) {
        print(`Ключей        | ${"N/A".padStart(10)} | ${Math.round(after.avgKeysExamined).toString().padStart(10)} | -`);
    }
    
    print(`\nИндекс ДО: ${before.indexUsed}`);
    print(`Индекс ПОСЛЕ: ${after.indexUsed}`);
    
    if (timeImprovement > 0 && before.avgTime > 1 && after.avgTime > 0) {
        var speedup = before.avgTime / after.avgTime;
        print(`\nУСКОРЕНИЕ: в ${speedup.toFixed(1)} раз`);

        print("\nРЕКОМЕНДАЦИИ:");
        if (speedup > 10) {
            print("   - Отличное ускорение! Индекс очень эффективен");
        } else if (speedup > 2) {
            print("   - Хорошее ускорение. Индекс работает корректно");
        } else if (speedup > 1) {
            print("   - Небольшое ускорение. Возможно, нужен другой тип индекса");
        }
    } else if (timeImprovement < 0 && Math.abs(timeImprovement) > 5) {
        print(`\nЗАМЕДЛЕНИЕ: на ${Math.abs(timeImprovement).toFixed(1)}%`);
        print("РЕКОМЕНДАЦИИ:");
        print("   - Индекс может быть не оптимальным для этого запроса");
        print("   - Проверьте структуру индекса и запроса");
    } else {
        print(`\nБез значительных изменений в скорости`);
        print("РЕКОМЕНДАЦИИ:");
        print("   - Мало данных для измерения разницы");
        print("   - Индекс может не подходить для этого типа запроса");
    }
}

print("\n" + "=".repeat(70));
print("ТЕСТ 1: Поиск мероприятий по категории");
print("=".repeat(70));

print("\nОписание запроса:");
print("   db.events.find({ categories: 'концерт' })");
print("   Поиск всех мероприятий в категории 'концерт'");

print("\nБЕНЧМАРК ДО СОЗДАНИЯ ИНДЕКСА (3 итерации)...");

var beforeTest1 = benchmarkQuery(
    "Поиск по категории 'концерт'",
    function() {
        return db.events.find({ categories: 'концерт' }).explain("executionStats");
    },
    3
);

print("\nСОЗДАНИЕ ИНДЕКСА для теста 1...");
try {
    db.events.createIndex(
        { categories: 1 },
        { name: "benchmark_categories_idx" }
    );
    print("Индекс создан: { categories: 1 }");
} catch (e) {
    print(`Ошибка создания индекса: ${e.message}`);
}

print("\nБЕНЧМАРК ПОСЛЕ СОЗДАНИЯ ИНДЕКСА (3 итерации)...");

var afterTest1 = benchmarkQuery(
    "Поиск по категории 'концерт'",
    function() {
        return db.events.find({ categories: 'концерт' }).explain("executionStats");
    },
    3
);

printComparison(beforeTest1, afterTest1);

print("\n\n" + "=".repeat(70));
print("ТЕСТ 2: Поиск пользователей по диапазону дат");
print("=".repeat(70));

print("\nОписание запроса:");
print("   db.users.find({ created_at: { $gte: дата1, $lte: дата2 } })");
print("   Поиск пользователей, созданных за последние 30 дней");

var endDate = new Date();
var startDate = new Date();
startDate.setDate(startDate.getDate() - 30);

print("\nБЕНЧМАРК ДО СОЗДАНИЯ ИНДЕКСА (3 итерации)...");

var beforeTest2 = benchmarkQuery(
    "Поиск пользователей за 30 дней",
    function() {
        return db.users.find({ 
            created_at: { 
                $gte: startDate, 
                $lte: endDate 
            } 
        }).explain("executionStats");
    },
    3
);

print("\nСОЗДАНИЕ ИНДЕКСА для теста 2...");
try {
    db.users.createIndex(
        { created_at: 1 },
        { name: "benchmark_created_at_idx" }
    );
    print("Индекс создан: { created_at: 1 }");
} catch (e) {
    print(`Ошибка создания индекса: ${e.message}`);
}

print("\nБЕНЧМАРК ПОСЛЕ СОЗДАНИЯ ИНДЕКСА (3 итерации)...");

var afterTest2 = benchmarkQuery(
    "Поиск пользователей за 30 дней",
    function() {
        return db.users.find({ 
            created_at: { 
                $gte: startDate, 
                $lte: endDate 
            } 
        }).explain("executionStats");
    },
    3
);

printComparison(beforeTest2, afterTest2);

print("\n\n" + "=".repeat(70));
print("ТЕСТ 3: Составной запрос с сортировкой");
print("=".repeat(70));

print("\nОписание запроса:");
print("   db.bookings.find({ status: 'confirmed' }).sort({ created_at: -1 }).limit(20)");
print("   Получить последние 20 подтвержденных бронирований");

print("\nБЕНЧМАРК ДО СОЗДАНИЯ ИНДЕКСА (3 итерации)...");

var beforeTest3 = benchmarkQuery(
    "Подтвержденные бронирования с сортировкой",
    function() {
        return db.bookings.find({ status: 'confirmed' })
            .sort({ created_at: -1 })
            .limit(20)
            .explain("executionStats");
    },
    3
);

print("\nСОЗДАНИЕ ИНДЕКСА для теста 3...");
try {
    db.bookings.createIndex(
        { status: 1, created_at: -1 },
        { name: "benchmark_status_created_at_idx" }
    );
    print("Индекс создан: { status: 1, created_at: -1 }");
} catch (e) {
    print(`Ошибка создания индекса: ${e.message}`);
}

print("\nБЕНЧМАРК ПОСЛЕ СОЗДАНИЯ ИНДЕКСА (3 итерации)...");

var afterTest3 = benchmarkQuery(
    "Подтвержденные бронирования с сортировкой",
    function() {
        return db.bookings.find({ status: 'confirmed' })
            .sort({ created_at: -1 })
            .limit(20)
            .explain("executionStats");
    },
    3
);

printComparison(beforeTest3, afterTest3);

print("\n\n" + "=".repeat(70));
print("ДЕМОНСТРАЦИЯ EXPLAIN()");
print("=".repeat(70));

print("\nПример использования explain() для анализа запроса:");

print("\n1. Простой explain (без статистики):");
try {
    var simpleExplain = db.events.find({ categories: 'концерт' }).explain();
    print("   Тип запроса: " + (simpleExplain.queryPlanner ? "queryPlanner" : "старый формат"));
    
    if (simpleExplain.queryPlanner && simpleExplain.queryPlanner.winningPlan) {
        var plan = simpleExplain.queryPlanner.winningPlan;
        print("   План выполнения: " + (plan.inputStage ? "составной" : "простой"));
    }
} catch (e) {
    print(`   Ошибка: ${e.message}`);
}

print("\n2. Explain с executionStats:");
try {
    var explainWithStats = db.events.find({ categories: 'концерт' }).explain("executionStats");

    print("   Структура ответа explain():");
    var keys = Object.keys(explainWithStats);
    if (keys.length > 0) {
        keys.slice(0, 5).forEach(key => {
            print(`   - ${key}: ${typeof explainWithStats[key]}`);
        });
        if (keys.length > 5) {
            print(`   - ... и еще ${keys.length - 5} полей`);
        }
    }
} catch (e) {
    print(`   Ошибка: ${e.message}`);
}

print("\n3. Анализ плана выполнения:");
try {
    var analysis = db.events.find({ categories: 'концерт' }).explain("executionStats");
    
    if (analysis.executionStats) {
        print("   Статистика выполнения:");
        print(`   - Время выполнения: ${analysis.executionStats.executionTimeMillis} мс`);
        print(`   - Проверено документов: ${analysis.executionStats.totalDocsExamined}`);
        print(`   - Проверено ключей: ${analysis.executionStats.totalKeysExamined || 0}`);
        
        if (analysis.executionStats.executionStages) {
            print("   - Этапы выполнения:");

            function printStages(stage, depth) {
                var indent = "   " + "  ".repeat(depth);
                if (stage && stage.stage) {
                    print(`${indent}└─ ${stage.stage}`);
                    
                    if (stage.stage === "COLLSCAN") {
                        print(`${indent}   фильтр: ${JSON.stringify(stage.filter || {})}`);
                    } else if (stage.stage === "IXSCAN") {
                        print(`${indent}   индекс: ${stage.indexName || "не указан"}`);
                        print(`${indent}   ключи: ${JSON.stringify(stage.keyPattern || {})}`);
                    }

                    if (stage.inputStage) printStages(stage.inputStage, depth + 1);
                    if (stage.innerStage) printStages(stage.innerStage, depth + 1);
                    if (stage.outerStage) printStages(stage.outerStage, depth + 1);
                }
            }
            
            printStages(analysis.executionStats.executionStages, 0);
        }
    }
} catch (e) {
    print(`   Ошибка анализа: ${e.message}`);
}

print("\n\n" + "=".repeat(70));
print("ИТОГИ И РЕКОМЕНДАЦИИ");
print("=".repeat(70));

print("\n📊 КРАТКИЕ ВЫВОДЫ:");
print("1. explain('executionStats') показывает детальную статистику выполнения");
print("2. Индексы сокращают количество проверяемых документов (totalDocsExamined)");
print("3. Время выполнения (executionTimeMillis) - ключевой показатель производительности");
print("4. План выполнения (executionStages) показывает как MongoDB обрабатывает запрос");

print("\nКАК ИСПОЛЬЗОВАТЬ EXPLAIN() НА ПРАКТИКЕ:");
print("1. Для медленных запросов всегда используйте explain('executionStats')");
print("2. Смотрите на totalDocsExamined - должно быть близко к nReturned");
print("3. Проверяйте executionStages.stage - COLLSCAN значит сканирование всей коллекции");
print("4. Оптимизируйте запросы, где totalDocsExamined >> nReturned");

print("\n  ЧАСТЫЕ ПРОБЛЕМЫ:");
print("1. Отсутствие индексов приводит к COLLSCAN");
print("2. Неоптимальные индексы не используются");
print("3. Слишком много индексов замедляет запись");
print("4. Индексы не покрывают все условия запроса");

print("\n Очистка тестовых индексов...");
collections.forEach(col => {
    if (db.getCollectionNames().includes(col)) {
        var indexes = db[col].getIndexes();
        indexes.forEach(idx => {
            if (idx.name !== '_id_' && idx.name.startsWith('benchmark_')) {
                try {
                    db[col].dropIndex(idx.name);
                    print(`   Удален индекс: ${idx.name}`);
                } catch (e) {
                }
            }
        });
    }
});

if (eventsCount < 50) {
    print("\n🧹 Удаление добавленных тестовых данных...");
    try {
        var deleted = db.events.deleteMany({ 
            title: { $regex: /^Тестовое мероприятие/ } 
        });
        print(`   Удалено тестовых мероприятий: ${deleted.deletedCount}`);
    } catch (e) {
        print(`   Ошибка удаления: ${e.message}`);
    }
}

print("\n" + "=".repeat(70));
print("БЕНЧМАРК ЗАВЕРШЕН!");
print("=".repeat(70));

print("\nЧТО БЫЛО ПРОДЕМОНСТРИРОВАНО:");
print("1. Использование explain('executionStats') для анализа производительности");
print("2. Сравнение планов выполнения до и после создания индексов");
print("3. Ключевые метрики: executionTimeMillis, totalDocsExamined, executionStages");
print("4. Практические примеры оптимизации запросов с помощью индексов");

print("\nДЛЯ ДАЛЬНЕЙШЕГО ИЗУЧЕНИЯ:");
print("1. MongoDB Documentation: Query Optimization");
print("2. Использование explain() с разными verbosity уровнями");
print("3. Анализ coverage индексов (indexOnly vs fetch)");
print("4. Мониторинг медленных запросов в продакшене");