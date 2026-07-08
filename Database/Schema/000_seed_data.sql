PRAGMA foreign_keys = OFF;
DELETE FROM snippet_runs;
DELETE FROM snippet_stats;
DELETE FROM snippet_tags;
DELETE FROM snippets;
DELETE FROM tags;
DELETE FROM snippet_categories;
DELETE FROM users;
PRAGMA foreign_keys = ON;

-- USERS (workspace-ы)
INSERT INTO users(id, name) VALUES
(1, 'Local User'),
(2, 'Admin'),
(3, 'DevOps');

-- CATEGORIES (изолированные деревья)
INSERT INTO snippet_categories(id, user_id, name, parent_id) VALUES
-- Local User (1)
(1,  1, 'Linux',        NULL),
(2,  1, 'Docker',       NULL),
(3,  1, 'Kubernetes',   NULL),
(4,  1, 'Bash',         1),
(5,  1, 'Networking',   1),
(6,  1, 'Systemd',      1),

-- Admin (2)
(7,  2, 'Databases',    NULL),
(8,  2, 'MySQL',        7),
(9,  2, 'SQLite',       7),

-- DevOps (3)
(10, 3, 'Monitoring',   NULL),
(11, 3, 'Prometheus',   10),
(12, 3, 'Grafana',      10);

-- TAGS (глобальные)
INSERT INTO tags(id, name) VALUES
(1, 'linux'),       (2, 'bash'),       (3, 'docker'),      (4, 'kubernetes'),
(5, 'mysql'),       (6, 'sqlite'),     (7, 'backup'),      (8, 'network'),
(9, 'monitoring'),  (10, 'security'),  (11, 'systemd'),    (12, 'ansible');

-- SNIPPETS (с правильными category_id)
INSERT INTO snippets(id, user_id, category_id, title, content, comment) VALUES
-- Local User (1)
(1,  1, 4, 'Очистка логов',          'find /var/log -type f -name "*.log" -delete',          'Использовать осторожно! Лучше сначала проверить find /var/log -type f -name "*.log" -print'),
(2,  1, 4, 'Архивация директории',   'tar -czf backup.tar.gz /home',                         'Для инкрементального бэкапа использовать опцию --listed-incremental'),
(3,  1, 5, 'Проверка открытых портов','ss -tulpn',                                           ''),
(4,  1, 5, 'Трассировка маршрута',   'traceroute google.com',                                ''),
(5,  1, 2, 'Список контейнеров',     'docker ps -a',                                         ''),
(6,  1, 2, 'Очистка Docker',         'docker system prune -a',                               'Перед запуском убедиться, что нет нужных остановленных контейнеров'),
(7,  1, 3, 'Перезапуск deployment',  'kubectl rollout restart deployment nginx',             ''),
(8,  1, 3, 'Получение логов pod',    'kubectl logs my-pod',                                  ''),
(9,  1, 8, 'Создание дампа MySQL',   'mysqldump -u root -p db > backup.sql',                 'Для больших БД использовать --single-transaction и --quick'),
(10, 1, 8, 'Показ процессов MySQL',  'SHOW PROCESSLIST;',                                    ''),
(11, 1, 9, 'Оптимизация SQLite',     'PRAGMA optimize;',                                     ''),
(12, 1, 9, 'Проверка целостности',   'PRAGMA integrity_check;',                              ''),
(13, 1, 6, 'Проверка дисков',        'df -h',                                                ''),
(14, 1, 6, 'Память системы',         'free -m',                                              ''),
(15, 1, 6, 'Перезапуск сервиса',     'systemctl restart nginx',                              ''),
(16, 1, 6, 'Просмотр юнитов',        'systemctl list-units',                                 '');

-- SNIPPET TAGS
INSERT INTO snippet_tags VALUES (1,1),(1,2);
INSERT INTO snippet_tags VALUES (2,1),(2,2),(2,7);
INSERT INTO snippet_tags VALUES (3,1),(3,8);
INSERT INTO snippet_tags VALUES (4,1),(4,8);
INSERT INTO snippet_tags VALUES (5,3);
INSERT INTO snippet_tags VALUES (6,3);
INSERT INTO snippet_tags VALUES (7,4);
INSERT INTO snippet_tags VALUES (8,4);
INSERT INTO snippet_tags VALUES (9,5),(9,7);
INSERT INTO snippet_tags VALUES (10,5);
INSERT INTO snippet_tags VALUES (11,6);
INSERT INTO snippet_tags VALUES (12,6);
INSERT INTO snippet_tags VALUES (15,11);
INSERT INTO snippet_tags VALUES (16,11);

-- RUN HISTORY
INSERT INTO snippet_runs(snippet_id, run_at, executed_by_user_id) VALUES
(1,  strftime('%s','now')-86400*15, 1),
(1,  strftime('%s','now')-86400*7,  1),
(1,  strftime('%s','now')-3600,     2),
(2,  strftime('%s','now')-86400*3,  1),
(3,  strftime('%s','now')-86400*2,  1),
(3,  strftime('%s','now')-7200,     1),
(5,  strftime('%s','now')-86400,    2),
(5,  strftime('%s','now')-3600,     2),
(6,  strftime('%s','now')-3000,     2),
(7,  strftime('%s','now')-6000,     1),
(7,  strftime('%s','now')-5000,     1),
(7,  strftime('%s','now')-4000,     1),
(7,  strftime('%s','now')-3000,     1),
(8,  strftime('%s','now')-2500,     3),
(9,  strftime('%s','now')-86400*10, 1),
(9,  strftime('%s','now')-86400*5,  1),
(9,  strftime('%s','now')-86400,    1),
(11, strftime('%s','now')-1800,     1),
(13, strftime('%s','now')-1200,     3),
(15, strftime('%s','now')-1000,     2),
(15, strftime('%s','now')-500,      2),
(15, strftime('%s','now')-100,      2);