DROP TABLE IF EXISTS huge_data_table;
CREATE TABLE huge_data_table (
    id SERIAL PRIMARY KEY,
    huge_data BYTEA
);

INSERT INTO huge_data_table (huge_data) 
VALUES (
    decode(
        (SELECT string_agg(lpad(to_hex((random()*255)::integer), 2, '0'), '') 
         FROM generate_series(1, 65536)),
        'hex'
    )
);

ANALYZE huge_data_table;

SELECT 
    'ЭКСПЕРИМЕНТ: Одна запись не помещается на страницу' as title,
    id,
    length(huge_data) as data_length,
    pg_column_size(huge_data) as size_bytes,
    (pg_column_size(huge_data) / 1024.0)::numeric(10,2) as size_kb,
    (pg_column_size(huge_data) > 8192) as exceeds_page_size
FROM huge_data_table;

SELECT 
    'Основная таблица' as table_type,
    pg_relation_size('huge_data_table') as size_bytes,
    (pg_relation_size('huge_data_table') / 8192.0)::numeric(10,2) as pages
UNION ALL
SELECT 
    'TOAST таблица',
    pg_relation_size(t.reltoastrelid),
    (pg_relation_size(t.reltoastrelid) / 8192.0)::numeric(10,2)
FROM pg_class t 
WHERE t.relname = 'huge_data_table' AND t.reltoastrelid != 0;

SELECT 
    c.relname as main_table,
    (SELECT relname FROM pg_class WHERE oid = c.reltoastrelid) as toast_table_name,
    pg_relation_size(c.oid) as main_size,
    pg_relation_size(c.reltoastrelid) as toast_size,
    CASE WHEN pg_relation_size(c.reltoastrelid) > 0 
         THEN 'ДАННЫЕ В TOAST' 
         ELSE 'ДАННЫЕ В ОСНОВНОЙ ТАБЛИЦЕ' 
    END as storage_location
FROM pg_class c
WHERE c.relname = 'huge_data_table';

SELECT 
    attname,
    case attstorage 
        when 'p' then 'plain (в основной таблице)' 
        when 'e' then 'external (TOAST)'
        when 'x' then 'extended (TOAST со сжатием)' 
        when 'm' then 'main (попытка в основной, потом TOAST)'
    end as storage_method,
    '64KB данных > 8KB страницы = НЕ ПОМЕЩАЕТСЯ' as conclusion
FROM pg_attribute 
WHERE attrelid = 'huge_data_table'::regclass 
AND attname = 'huge_data';