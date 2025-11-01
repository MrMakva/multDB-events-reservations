-- Создание пользователя с паролем
CREATE USER DEN4IK WITH SUPERUSER LOGIN;

-- Предоставление всех привилегий на все базы данных
ALTER USER DEN4IK WITH CREATEDB CREATEROLE REPLICATION BYPASSRLS;

-- Предоставление прав на все существующие таблицы в схеме public
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO DEN4IK;

-- Предоставление прав на все будущие таблицы в схеме public
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO DEN4IK;

-- Предоставление прав на все последовательности (sequences)
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO DEN4IK;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO DEN4IK;

-- Предоставление прав на все функции
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO DEN4IK;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO DEN4IK;

-- Предоставление прав на все схемы
GRANT ALL ON SCHEMA public TO DEN4IK;

