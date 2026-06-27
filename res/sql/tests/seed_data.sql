-- Удаление данных:

DELETE FROM snippet_runs;
DELETE FROM snippet_host_stats;
DELETE FROM snippet_stats;
DELETE FROM snippet_tags;
DELETE FROM snippets;
DELETE FROM tags;
DELETE FROM hosts;
DELETE FROM snippet_categories;
DELETE FROM users;

-- Заполнение данных

-- BEGIN TRANSACTION;

---------------------------------------------------------
-- USERS
---------------------------------------------------------
INSERT INTO users(id, name) VALUES
(1, 'Дмитрий'),
(2, 'Admin'),
(3, 'DevOps');

---------------------------------------------------------
-- HOSTS
---------------------------------------------------------
INSERT INTO hosts(id, name) VALUES
(1, 'prod-01'),
(2, 'prod-02'),
(3, 'staging'),
(4, 'home-lab');

---------------------------------------------------------
-- CATEGORIES
---------------------------------------------------------

INSERT INTO snippet_categories(id, name, parent_id) VALUES
(1, 'Linux', NULL),
(2, 'Docker', NULL),
(3, 'Kubernetes', NULL),
(4, 'Databases', NULL),
(5, 'Bash', 1),
(6, 'Networking', 1),
(7, 'MySQL', 4),
(8, 'SQLite', 4),
(9, 'Monitoring', NULL);

---------------------------------------------------------
-- TAGS
---------------------------------------------------------

INSERT INTO tags(id, name) VALUES
(1, 'linux'),
(2, 'bash'),
(3, 'docker'),
(4, 'kubernetes'),
(5, 'mysql'),
(6, 'sqlite'),
(7, 'backup'),
(8, 'network'),
(9, 'monitoring'),
(10, 'security'),
(11, 'systemd'),
(12, 'ansible');

---------------------------------------------------------
-- SNIPPETS
---------------------------------------------------------

INSERT INTO snippets(id, user_id, category_id, title, content)
VALUES
(1,1,5,'Очистка логов',
'find /var/log -type f -name "*.log" -delete'),

(2,1,5,'Архивация директории',
'tar -czf backup.tar.gz /home'),

(3,1,6,'Проверка открытых портов',
'ss -tulpn'),

(4,1,6,'Трассировка маршрута',
'traceroute google.com'),

(5,1,2,'Список контейнеров',
'docker ps -a'),

(6,1,2,'Очистка Docker',
'docker system prune -a'),

(7,1,3,'Перезапуск deployment',
'kubectl rollout restart deployment nginx'),

(8,1,3,'Получение логов pod',
'kubectl logs my-pod'),

(9,1,7,'Создание дампа MySQL',
'mysqldump -u root -p db > backup.sql'),

(10,1,7,'Показ процессов MySQL',
'SHOW PROCESSLIST;'),

(11,1,8,'Оптимизация SQLite',
'PRAGMA optimize;'),

(12,1,8,'Проверка целостности',
'PRAGMA integrity_check;'),

(13,1,9,'Проверка дисков',
'df -h'),

(14,1,9,'Память системы',
'free -m'),

(15,1,5,'Перезапуск сервиса',
'systemctl restart nginx'),

(16,1,5,'Просмотр юнитов',
'systemctl list-units');

---------------------------------------------------------
-- SNIPPET TAGS
---------------------------------------------------------

INSERT INTO snippet_tags VALUES (1,1);
INSERT INTO snippet_tags VALUES (1,2);

INSERT INTO snippet_tags VALUES (2,1);
INSERT INTO snippet_tags VALUES (2,2);
INSERT INTO snippet_tags VALUES (2,7);

INSERT INTO snippet_tags VALUES (3,1);
INSERT INTO snippet_tags VALUES (3,8);

INSERT INTO snippet_tags VALUES (4,1);
INSERT INTO snippet_tags VALUES (4,8);

INSERT INTO snippet_tags VALUES (5,3);

INSERT INTO snippet_tags VALUES (6,3);

INSERT INTO snippet_tags VALUES (7,4);

INSERT INTO snippet_tags VALUES (8,4);

INSERT INTO snippet_tags VALUES (9,5);
INSERT INTO snippet_tags VALUES (9,7);

INSERT INTO snippet_tags VALUES (10,5);

INSERT INTO snippet_tags VALUES (11,6);

INSERT INTO snippet_tags VALUES (12,6);

INSERT INTO snippet_tags VALUES (15,11);

INSERT INTO snippet_tags VALUES (16,11);

---------------------------------------------------------
-- RUN HISTORY
---------------------------------------------------------

INSERT INTO snippet_runs
(snippet_id, run_at, host_id, executed_by_user_id)
VALUES
(1, strftime('%s','now')-86400*15, 1, 1),
(1, strftime('%s','now')-86400*7, 2, 1),
(1, strftime('%s','now')-3600, 1, 2),

(2, strftime('%s','now')-86400*3, 1, 1),

(3, strftime('%s','now')-86400*2, 3, 1),
(3, strftime('%s','now')-7200, 3, 1),

(5, strftime('%s','now')-86400, 2, 2),
(5, strftime('%s','now')-3600, 2, 2),

(6, strftime('%s','now')-3000, 2, 2),

(7, strftime('%s','now')-6000, 1, 1),
(7, strftime('%s','now')-5000, 1, 1),
(7, strftime('%s','now')-4000, 1, 1),
(7, strftime('%s','now')-3000, 1, 1),

(8, strftime('%s','now')-2500, 3, 3),

(9, strftime('%s','now')-86400*10, 4, 1),
(9, strftime('%s','now')-86400*5, 4, 1),
(9, strftime('%s','now')-86400, 4, 1),

(11, strftime('%s','now')-1800, 1, 1),

(13, strftime('%s','now')-1200, 4, 3),

(15, strftime('%s','now')-1000, 1, 2),
(15, strftime('%s','now')-500, 1, 2),
(15, strftime('%s','now')-100, 1, 2);

-- COMMIT;