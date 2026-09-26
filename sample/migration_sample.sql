-- 004_update_users.sql
ALTER TABLE users ADD COLUMN last_login TIMESTAMP;
ALTER TABLE users DROP COLUMN user_email;
