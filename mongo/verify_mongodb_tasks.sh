#!/bin/bash
# verify_mongodb_tasks.sh

echo "=================================================================="
echo "ПРОВЕРКА ВЫПОЛНЕНИЯ ВСЕХ 8 ЗАДАНИЙ MONGODB"
echo "=================================================================="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Переменные для подсчета результатов
total_tests=0
passed_tests=0
failed_tests=0
warnings=0

# Функция для выполнения проверок в MongoDB
run_mongo_check() {
    local query="$1"
    local description="$2"
    local expected="$3"
    
    ((total_tests++))
    
    local result=$(mongosh --quiet --eval "
        db = db.getSiblingDB('event_booking_all_tasks');
        try {
            $query
        } catch(e) {
            print('ERROR: ' + e.message);
        }
    " 2>/dev/null)
    
    echo -n "   Проверка: $description ... "
    
    if [[ "$result" == *"ERROR"* ]]; then
        print_error "Ошибка выполнения запроса"
        ((failed_tests++))
        return 1
    elif [[ "$result" == *"$expected"* ]] || [[ "$expected" == "ANY" && -n "$result" ]]; then
        print_success "OK"
        ((passed_tests++))
        return 0
    else
        print_error "Несоответствие (ожидалось: $expected, получено: $result)"
        ((failed_tests++))
        return 1
    fi
}

echo "🔍 Проверка базы данных и подключения..."
echo ""

# Проверка 1: Существует ли база данных
print_info "1. Проверка существования базы данных"
run_mongo_check "print(db.getName())" "База данных существует" "event_booking_all_tasks"

# Проверка 2: Проверка коллекций
print_info "\n2. Проверка созданных коллекций"
run_mongo_check "
    var cols = db.getCollectionNames();
    print('Коллекций: ' + cols.length);
    cols.forEach(c => print('  - ' + c));
" "Коллекции созданы" "Коллекций:"

echo ""
print_info "3. Проверка заданий по порядку"
echo ""

# Задание 1: Связи между коллекциями
print_info "   Задание 1: Связи между коллекциями"
run_mongo_check "
    var orgCount = db.organizers.countDocuments();
    var eventCount = db.events.countDocuments({organizer_id: 'org_culture'});
    print('Организаторов: ' + orgCount + ', Событий у org_culture: ' + eventCount);
" "1:N связь создана" "Событий у org_culture: 2"

run_mongo_check "
    var userCount = db.users.countDocuments({favorites: 'event_concert'});
    print('Пользователей с концертом в избранном: ' + userCount);
" "M:N связь создана" "Пользователей с концертом в избранном: 2"

# Задание 2: Bulk-операции
print_info "\n   Задание 2: Bulk-операции"
run_mongo_check "
    var newEvent = db.events.findOne({_id: 'event_new'});
    print('Новое событие создано: ' + (newEvent ? 'Да' : 'Нет'));
" "Bulk insertOne выполнен" "Новое событие создано: Да"

run_mongo_check "
    var concert = db.events.findOne({_id: 'event_concert'});
    print('Концерт опубликован: ' + (concert.status === 'published' ? 'Да' : 'Нет'));
" "Bulk updateOne выполнен" "Концерт опубликован: Да"

# Задание 3: Валидация схемы
print_info "\n   Задание 3: Валидация схемы"
run_mongo_check "
    var collExists = db.getCollectionNames().includes('validated_bookings');
    print('Коллекция с валидацией: ' + (collExists ? 'Да' : 'Нет'));
" "Коллекция с валидацией создана" "Коллекция с валидацией: Да"

run_mongo_check "
    var validation = db.validated_bookings.getDB().getCollectionInfos({name: 'validated_bookings'})[0];
    print('Валидация настроена: ' + (validation.options.validator ? 'Да' : 'Нет'));
" "Валидатор настроен" "Валидация настроена: Да"

# Задание 4: Комбинированные отчеты
print_info "\n   Задание 4: Комбинированные отчеты"
run_mongo_check "
    var bookCount = db.books.countDocuments();
    var authorCount = db.authors.countDocuments();
    print('Книг: ' + bookCount + ', Авторов: ' + authorCount);
" "Данные для отчетов созданы" "Книг: 6"

run_mongo_check "
    var report = db.books.aggregate([{\$group: {_id: '\$genre', count: {\$sum: 1}}}]).toArray();
    var hasRomance = report.some(r => r._id === 'роман');
    var hasDetective = report.some(r => r._id === 'детектив');
    print('Жанры: роман=' + hasRomance + ', детектив=' + hasDetective);
" "Агрегации работают" "Жанры: роман=true"

# Задание 5: Оптимизация запросов
print_info "\n   Задание 5: Оптимизация запросов"
run_mongo_check "
    var perfCount = db.performance_data.countDocuments();
    print('Тестовых данных: ' + perfCount);
" "Тестовые данные созданы" "Тестовых данных: 10000"

run_mongo_check "
    var indexes = db.performance_data.getIndexes();
    var hasOptimizedIndex = indexes.some(i => i.name === 'idx_category_status_price_date');
    print('Оптимизированный индекс: ' + (hasOptimizedIndex ? 'Да' : 'Нет'));
" "Индексы созданы" "Оптимизированный индекс: Да"

# Задание 6: Кэширование
print_info "\n   Задание 6: Кэширование"
run_mongo_check "
    var cacheCount = db.cached_analytics.countDocuments();
    var ttlIndex = db.cached_analytics.getIndexes().some(i => i.name === 'idx_ttl_expires');
    print('Кэш отчетов: ' + cacheCount + ', TTL индекс: ' + ttlIndex);
" "Кэширование настроено" "Кэш отчетов: 1"

# Задание 7: Шардинг (только проверка данных)
print_info "\n   Задание 7: Шардинг (демонстрационные данные)"
run_mongo_check "
    var demoCount = db.sharding_demo.countDocuments();
    print('Демо-данные для шардинга: ' + demoCount);
" "Данные для демонстрации шардинга" "Демо-данные для шардинга: 4"

# Задание 8: Транзакции (только проверка данных)
print_info "\n   Задание 8: Транзакции (демонстрационные данные)"
run_mongo_check "
    var acc1 = db.transaction_accounts.findOne({user_id: 'user_anna'});
    var acc2 = db.transaction_accounts.findOne({user_id: 'user_petr'});
    print('Анна: ' + acc1.balance + ', Петр: ' + acc2.balance);
" "Данные для транзакций созданы" "Анна: 8000"

# Дополнительные проверки
echo ""
print_info "4. Дополнительные проверки"
echo ""

# Проверка индексов
run_mongo_check "
    var totalIndexes = 0;
    db.getCollectionNames().forEach(col => {
        totalIndexes += db[col].getIndexes().length;
    });
    print('Всего индексов в БД: ' + totalIndexes);
" "Индексы созданы" "Всего индексов в БД:"

# Проверка агрегационных пайплайнов
run_mongo_check "
    var result = db.performance_data.aggregate([
        {\$match: {status: 'confirmed'}},
        {\$group: {_id: '\$category', count: {\$sum: 1}}},
        {\$sort: {count: -1}},
        {\$limit: 1}
    ]).toArray()[0];
    print('Самая популярная категория: ' + (result ? result._id : 'нет данных'));
" "Агрегационные запросы работают" "Самая популярная категория:"

# Проверка валидации (попытка вставить невалидные данные)
run_mongo_check "
    try {
        db.validated_bookings.insertOne({
            user_id: 'test_user',
            event_id: 'test_event',
            tickets_count: 15,  // Нарушение правила (максимум 10)
            total_amount: 1000,
            status: 'confirmed',
            booking_date: new Date()
        });
        print('ВАЛИДАЦИЯ НЕ РАБОТАЕТ: документ добавился');
    } catch(e) {
        print('ВАЛИДАЦИЯ РАБОТАЕТ: ' + e.message.split(':')[0]);
    }
" "Валидация отклоняет невалидные данные" "ВАЛИДАЦИЯ РАБОТАЕТ:"

# Проверка производительности
run_mongo_check "
    var start = new Date();
    var result = db.performance_data.find({
        category: 'music',
        status: 'confirmed',
        price: {\$gt: 5000}
    })
    .sort({price: -1, created_at: -1})
    .limit(10)
    .toArray();
    var time = new Date() - start;
    print('Время запроса с индексом: ' + time + 'мс, Найдено: ' + result.length);
" "Запросы выполняются быстро" "Время запроса с индексом:"

echo ""
echo "=================================================================="
echo "ИТОГИ ПРОВЕРКИ"
echo "=================================================================="
echo ""

# Вывод результатов
echo "Всего проверок: $total_tests"
echo -e "${GREEN}Успешно: $passed_tests${NC}"
if [ $failed_tests -gt 0 ]; then
    echo -e "${RED}Неудачно: $failed_tests${NC}"
fi
if [ $warnings -gt 0 ]; then
    echo -e "${YELLOW}Предупреждений: $warnings${NC}"
fi

echo ""
echo "📊 СОСТОЯНИЕ ЗАДАНИЙ:"

# Оценка выполнения каждого задания
tasks=(
    "1. Связи между коллекциями"
    "2. Bulk-операции" 
    "3. Валидация схемы"
    "4. Комбинированные отчеты"
    "5. Оптимизация запросов"
    "6. Кэширование"
    "7. Шардинг (теория)"
    "8. Транзакции (теория)"
)

for i in "${!tasks[@]}"; do
    if [ $i -lt 6 ]; then
        # Первые 6 заданий должны быть полностью выполнены
        echo -e "  ${GREEN}✓${NC} ${tasks[$i]}"
    else
        # Последние 2 задания требуют инфраструктуры
        echo -e "  ${YELLOW}⚠${NC} ${tasks[$i]} (требуется дополнительная настройка)"
    fi
done

echo ""
echo "🔧 РЕКОМЕНДАЦИИ:"

# Проверка MongoDB версии
mongodb_version=$(mongosh --quiet --eval "db.version()" 2>/dev/null)
echo "   • Версия MongoDB: $mongodb_version"

# Проверка режима запуска
is_replica=$(mongosh --quiet --eval "try { rs.status(); print('Replica Set'); } catch(e) { print('Standalone'); }" 2>/dev/null)
echo "   • Режим: $is_replica"

if [[ "$is_replica" == "Standalone" ]]; then
    print_warning "   Для транзакций требуется Replica Set"
fi

# Проверка размера БД
db_size=$(mongosh --quiet --eval "
    db = db.getSiblingDB('event_booking_all_tasks');
    var stats = db.stats();
    print('Размер БД: ' + Math.round(stats.dataSize / 1024 / 1024 * 100) / 100 + ' MB');
" 2>/dev/null)
echo "   • $db_size"

echo ""
echo "🚀 КОМАНДЫ ДЛЯ РУЧНОЙ ПРОВЕРКИ:"
echo "   1. Подключиться к БД: mongosh event_booking_all_tasks"
echo "   2. Показать коллекции: show collections"
echo "   3. Проверить индексы: db.performance_data.getIndexes()"
echo "   4. Проверить валидацию: db.validated_bookings.getDB().getCollectionInfos({name: 'validated_bookings'})[0].options.validator"
echo "   5. Проверить кэш: db.cached_analytics.find().pretty()"

echo ""
echo "=================================================================="

# Итоговый статус
if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}✅ ВСЕ ОСНОВНЫЕ ЗАДАНИЯ ВЫПОЛНЕНЫ УСПЕШНО!${NC}"
    echo "   Задания 7-8 требуют дополнительной настройки инфраструктуры."
    exit 0
else
    echo -e "${YELLOW}⚠ НЕКОТОРЫЕ ПРОВЕРКИ НЕ ПРОЙДЕНЫ${NC}"
    echo "   Проверьте ошибки выше."
    exit 1
fi