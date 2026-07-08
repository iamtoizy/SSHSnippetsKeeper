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
(3, 'DevOps'),
(4, 'SRE'),
(5, 'DBA');

-- CATEGORIES (изолированные деревья для каждого workspace)
INSERT INTO snippet_categories(id, user_id, name, parent_id) VALUES
-- Local User (1) - DevOps задачи
(1,  1, 'Linux',        NULL),
(2,  1, 'Docker',       NULL),
(3,  1, 'Kubernetes',   NULL),
(4,  1, 'Bash',         1),
(5,  1, 'Networking',   1),
(6,  1, 'Systemd',      1),
(7,  1, 'Cron',         1),
(8,  1, 'Performance',  1),
(9,  1, 'Users',        1),

-- Admin (2) - Администрирование
(10, 2, 'Databases',    NULL),
(11, 2, 'MySQL',        10),
(12, 2, 'PostgreSQL',   10),
(13, 2, 'SQLite',       10),
(14, 2, 'Redis',        10),
(15, 2, 'Networking',   NULL),
(16, 2, 'Nginx',        15),
(17, 2, 'Git',          NULL),

-- DevOps (3) - Инфраструктура
(18, 3, 'Cloud',        NULL),
(19, 3, 'AWS',          18),
(20, 3, 'Terraform',    18),
(21, 3, 'CI/CD',        NULL),
(22, 3, 'Jenkins',      21),
(23, 3, 'Ansible',      NULL),
(24, 3, 'Docker',       NULL),
(25, 3, 'Kubernetes',   NULL),

-- SRE (4) - Мониторинг и безопасность
(26, 4, 'Monitoring',   NULL),
(27, 4, 'Prometheus',   26),
(28, 4, 'Grafana',      26),
(29, 4, 'Logs',         26),
(30, 4, 'Security',     NULL),
(31, 4, 'SSH',          30),
(32, 4, 'Firewall',     30),
(33, 4, 'Cloud',        NULL),
(34, 4, 'AWS',          33),
(35, 4, 'Terraform',    33),

-- DBA (5) - Специализация на БД
(36, 5, 'MySQL',        NULL),
(37, 5, 'PostgreSQL',   NULL),
(38, 5, 'SQLite',       NULL),
(39, 5, 'Redis',        NULL),
(40, 5, 'Storage',      NULL),
(41, 5, 'Backup',       NULL);

-- TAGS (глобальные)
INSERT INTO tags(id, name) VALUES
(1, 'linux'),       (2, 'bash'),       (3, 'docker'),      (4, 'kubernetes'),
(5, 'mysql'),       (6, 'sqlite'),     (7, 'backup'),      (8, 'network'),
(9, 'monitoring'),  (10, 'security'),  (11, 'systemd'),    (12, 'ansible'),
(13, 'postgres'),   (14, 'redis'),     (15, 'nginx'),      (16, 'firewall'),
(17, 'ssh'),        (18, 'git'),       (19, 'jenkins'),    (20, 'aws'),
(21, 'terraform'),  (22, 'ci-cd'),     (23, 'logs'),       (24, 'cron'),
(25, 'performance'),(26, 'storage'),   (27, 'users'),      (28, 'dns'),
(29, 'ssl'),        (30, 'prometheus'),(31, 'grafana'),    (32, 'alerting'),
(33, 'deploy'),     (34, 'rollback'),  (35, 'scaling'),    (36, 'debug'),
(37, 'cleanup'),    (38, 'automation'),(39, 'config'),     (40, 'troubleshoot');

-- SNIPPETS (84 записи с правильными category_id)
INSERT INTO snippets(id, user_id, category_id, title, content, comment) VALUES
-- Local User (1) - категории 1-9
(1,  1, 4,  'Очистка логов',           'find /var/log -type f -name "*.log" -delete',              'Использовать осторожно! Сначала проверить через find ... -print'),
(2,  1, 4,  'Архивация директории',    'tar -czf backup.tar.gz /home',                              'Для инкрементального бэкапа использовать --listed-incremental'),
(3,  1, 4,  'Поиск больших файлов',    'find / -xdev -type f -size +100M -exec ls -lh {} \;',       ''),
(4,  1, 4,  'Подсчёт строк в файлах',  'wc -l /var/log/*.log | sort -n',                            ''),
(5,  1, 4,  'Замена текста в файлах',  'sed -i "s/old/new/g" config.yml',                           'Обязательно сделать бэкап перед запуском'),
(6,  1, 5,  'Проверка открытых портов','ss -tulpn',                                                 ''),
(7,  1, 5,  'Трассировка маршрута',    'traceroute google.com',                                     ''),
(8,  1, 5,  'DNS lookup',              'dig +short example.com A',                                  'Для обратного DNS: dig -x IP'),
(9,  1, 2,  'Список контейнеров',      'docker ps -a',                                              ''),
(10, 1, 2,  'Очистка Docker',          'docker system prune -a',                                    'ВНИМАНИЕ: удаляет ВСЕ неиспользуемые образы, контейнеры и сети!'),
(11, 1, 3,  'Перезапуск deployment',   'kubectl rollout restart deployment nginx',                   ''),
(12, 1, 3,  'Получение логов pod',     'kubectl logs my-pod --tail=200',                            'Для предыдущего контейнера: --previous'),
(13, 1, 6,  'Перезапуск сервиса',      'systemctl restart nginx',                                   ''),
(14, 1, 6,  'Просмотр юнитов',         'systemctl list-units --type=service --state=running',       ''),
(15, 1, 7,  'Список cron задач',       'crontab -l',                                                'Для другого пользователя: crontab -u user -l'),
(16, 1, 8,  'Нагрузка CPU по ядрам',   'mpstat -P ALL 1 5',                                         'Требует пакет sysstat, %idle < 10 = нагрузка'),
(17, 1, 8,  'IO статистика',           'iostat -xz 1 5',                                            '%util > 80 = диск перегружен'),
(18, 1, 8,  'Топ процессов по памяти', 'ps aux --sort=-%mem | head -15',                            ''),
(19, 1, 8,  'Load average детально',   'uptime && cat /proc/loadavg',                               'Три числа: load за 1, 5 и 15 минут'),
(20, 1, 9,  'Последние логины',        'last -n 20',                                                'Для неудачных попыток: lastb'),

-- Admin (2) - категории 10-17
(21, 2, 11, 'Создание дампа MySQL',    'mysqldump -u root -p db > backup.sql',                      'Для InnoDB обязательно добавить --single-transaction'),
(22, 2, 11, 'Процессы MySQL',          'SHOW PROCESSLIST;',                                         ''),
(23, 2, 11, 'Размер баз данных',       'SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024,2) AS mb FROM information_schema.tables GROUP BY table_schema;', ''),
(24, 2, 11, 'Медленные запросы',       'SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 20;', 'Предварительно включить slow_query_log = ON'),
(25, 2, 11, 'Восстановление из дампа', 'mysql -u root -p db < backup.sql',                          ''),
(26, 2, 11, 'Создание пользователя',   'CREATE USER "app"@"%" IDENTIFIED BY "pass"; GRANT ALL ON db.* TO "app"@"%";', 'FLUSH PRIVILEGES после создания'),
(27, 2, 12, 'Дамп PostgreSQL',         'pg_dump -U postgres mydb > dump.sql',                       'Для сжатия: pg_dump -Fc mydb > dump.dump'),
(28, 2, 12, 'Активные соединения',     'SELECT pid, usename, application_name, state FROM pg_stat_activity;', 'state = idle in transaction — потенциальная проблема'),
(29, 2, 12, 'Размер таблиц',           'SELECT schemaname, relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;', ''),
(30, 2, 12, 'VACUUM ANALYZE',          'VACUUM ANALYZE;',                                           'Обновляет статистику планировщика, выполнять после массовых INSERT/DELETE'),
(31, 2, 12, 'Блокировки',              'SELECT * FROM pg_locks WHERE NOT granted;',                 'Показывает ожидающие блокировки — признак contention'),
(32, 2, 13, 'Оптимизация SQLite',      'PRAGMA optimize;',                                          'Выполнять периодически, не перед каждым запросом'),
(33, 2, 13, 'Проверка целостности',    'PRAGMA integrity_check;',                                   'Возвращает "ok" если БД не повреждена'),
(34, 2, 13, 'Размер БД SQLite',        'SELECT page_count * page_size AS size FROM pragma_page_count(), pragma_page_size();', ''),
(35, 2, 13, 'WAL режим',               'PRAGMA journal_mode=WAL;',                                  'Улучшает конкурентный доступ, обязателен для многопоточных приложений'),
(36, 2, 14, 'Инфо Redis',              'redis-cli INFO memory',                                     ''),
(37, 2, 14, 'Все ключи по паттерну',   'redis-cli KEYS "session:*"',                                'НЕ использовать на проде! Использовать SCAN вместо KEYS'),
(38, 2, 14, 'Удаление по паттерну',    'redis-cli EVAL "for i,k in ipairs(redis.call(KEYS,ARGV[1])) do redis.call(DEL,k) end return 1" 0 "cache:*"', 'Только для staging/dev'),
(39, 2, 14, 'Flush DB',                'redis-cli FLUSHDB',                                         'ТОЛЬКО на staging! На проде = катастрофа'),
(40, 2, 16, 'Nginx конфиг',            'nginx -t',                                                  'Проверка синтаксиса конфигурации'),
(41, 2, 17, 'История коммитов',        'git log --oneline --graph -20',                             ''),
(42, 2, 17, 'Поиск по истории',        'git log -S "password" --all --oneline',                     'Поиск утечек секретов в истории репозитория'),
(43, 2, 17, 'Отмена последнего коммита','git reset --soft HEAD~1',                                   '--soft сохраняет изменения в staging, --hard удаляет'),

-- DevOps (3) - категории 18-25
(44, 3, 19, 'Список EC2 инстансов',    'aws ec2 describe-instances --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name}" --output table', ''),
(45, 3, 19, 'S3 размер бакета',        'aws s3 ls s3://my-bucket --recursive --summarize --human-readable', 'Для больших бакетов может занять минуты'),
(46, 3, 20, 'Terraform plan',          'terraform plan -out=tfplan',                                'ВСЕГДА делать plan перед apply'),
(47, 3, 20, 'Terraform apply',         'terraform apply tfplan',                                    ''),
(48, 3, 20, 'Terraform state list',    'terraform state list',                                      'Показывает все ресурсы в state-файле'),
(49, 3, 22, 'Перезапуск Jenkins job',  'curl -X POST "http://jenkins:8080/job/my-job/build" --user admin:token', 'Token создать в Jenkins → Configure → API Token'),
(50, 3, 22, 'Статус сборки',           'curl -s "http://jenkins:8080/job/my-job/lastBuild/api/json" | jq ".result"', 'Возможные значения: SUCCESS, FAILURE, ABORTED, null (in progress)'),
(51, 3, 23, 'Ping всех хостов',        'ansible all -m ping',                                       ''),
(52, 3, 23, 'Выполнение команды',      'ansible webservers -m shell -a "df -h"',                    'Для ad-hoc команд, не заменяет playbook'),
(53, 3, 23, 'Запуск playbook',         'ansible-playbook deploy.yml --limit prod',                  '--limit ограничивает выполнение группой хостов'),
(54, 3, 23, 'Проверка синтаксиса',     'ansible-playbook deploy.yml --syntax-check',                'Быстрая проверка без подключения к хостам'),
(55, 3, 24, 'Список контейнеров',      'docker ps -a',                                              ''),
(56, 3, 24, 'Очистка Docker',          'docker system prune -a',                                    'ВНИМАНИЕ: удаляет ВСЕ неиспользуемые образы!'),
(57, 3, 24, 'Логи контейнера',         'docker logs --tail 100 -f my-container',                    'Без -f покажет только последние строки и выйдет'),
(58, 3, 25, 'Перезапуск deployment',   'kubectl rollout restart deployment nginx',                  ''),
(59, 3, 25, 'Получение логов pod',     'kubectl logs my-pod --tail=200',                            'Для предыдущего контейнера: --previous'),
(60, 3, 25, 'Масштабирование',         'kubectl scale deployment nginx --replicas=5',               ''),

-- SRE (4) - категории 26-35
(61, 4, 27, 'Проверка targets',        'curl -s http://localhost:9090/api/v1/targets | jq ".data.activeTargets[].labels.instance"', 'health = down означает проблему со сбором метрик'),
(62, 4, 27, 'Запрос PromQL',           'curl -s "http://localhost:9090/api/v1/query?query=up" | jq', ''),
(63, 4, 28, 'Экспорт дашборда',        'curl -s http://localhost:3000/api/dashboards/uid/abc123 -H "Authorization: Bearer $TOKEN" | jq', 'TOKEN получить в Grafana → API Keys'),
(64, 4, 29, 'Поиск ошибок в journald', 'journalctl -p err --since "1 hour ago" --no-pager',         ''),
(65, 4, 29, 'Логи по юниту',           'journalctl -u nginx.service --since today --no-pager',      'Для live-слежения добавить -f'),
(66, 4, 31, 'Генерация SSH ключа',     'ssh-keygen -t ed25519 -C "admin@server"',                   'ed25519 предпочтительнее RSA'),
(67, 4, 31, 'Копирование ключа',       'ssh-copy-id user@remote-host',                              ''),
(68, 4, 31, 'Туннель SSH',             'ssh -L 3306:db-host:3306 bastion',                          'Проброс порта БД через bastion-хост'),
(69, 4, 32, 'Блокировка IP',           'iptables -A INPUT -s 192.168.1.100 -j DROP',                'Для постоянной блокировки сохранить через iptables-save'),
(70, 4, 32, 'Правила iptables',        'iptables -L -n -v --line-numbers',                          '-v показывает счётчики пакетов'),
(71, 4, 34, 'Список EC2 инстансов',    'aws ec2 describe-instances --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name}" --output table', ''),
(72, 4, 34, 'S3 размер бакета',        'aws s3 ls s3://my-bucket --recursive --summarize --human-readable', 'Для больших бакетов может занять минуты'),
(73, 4, 35, 'Terraform plan',          'terraform plan -out=tfplan',                                'ВСЕГДА делать plan перед apply'),
(74, 4, 35, 'Terraform apply',         'terraform apply tfplan',                                    ''),
(75, 4, 35, 'Terraform state list',    'terraform state list',                                      'Показывает все ресурсы в state-файле'),

-- DBA (5) - категории 36-41
(76, 5, 36, 'Дамп MySQL',              'mysqldump -u root -p db > backup.sql',                      'Для InnoDB обязательно добавить --single-transaction'),
(77, 5, 36, 'Процессы MySQL',          'SHOW PROCESSLIST;',                                         ''),
(78, 5, 36, 'Размер баз данных',       'SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024,2) AS mb FROM information_schema.tables GROUP BY table_schema;', ''),
(79, 5, 36, 'Медленные запросы',       'SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 20;', 'Предварительно включить slow_query_log = ON'),
(80, 5, 37, 'Дамп PostgreSQL',         'pg_dump -U postgres mydb > dump.sql',                       'Для сжатия: pg_dump -Fc mydb > dump.dump'),
(81, 5, 37, 'Активные соединения',     'SELECT pid, usename, application_name, state FROM pg_stat_activity;', 'state = idle in transaction — потенциальная проблема'),
(82, 5, 37, 'Размер таблиц',           'SELECT schemaname, relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;', ''),
(83, 5, 38, 'Оптимизация SQLite',      'PRAGMA optimize;',                                          'Выполнять периодически, не перед каждым запросом'),
(84, 5, 38, 'Проверка целостности',    'PRAGMA integrity_check;',                                   'Возвращает "ok" если БД не повреждена');

-- SNIPPET_TAGS (все связи сохранены)
INSERT INTO snippet_tags(snippet_id, tag_id) VALUES
(1,1),(1,2),(1,37),(2,1),(2,2),(2,7),(3,1),(3,2),(3,26),(4,1),(4,2),(4,23),
(5,1),(5,2),(5,39),(6,1),(6,8),(6,40),(7,1),(7,8),(7,40),(8,1),(8,8),(8,28),
(9,3),(9,36),(10,3),(10,37),(11,4),(11,33),(12,4),(12,23),(13,11),(13,1),(14,11),(14,1),
(15,24),(15,1),(16,25),(16,1),(17,25),(17,1),(18,25),(18,1),(19,25),(19,1),(20,27),(20,10),
(21,5),(21,7),(22,5),(22,40),(23,5),(23,25),(24,5),(24,25),(24,40),(25,5),(25,7),(26,5),(26,27),
(27,13),(27,7),(28,13),(28,40),(29,13),(29,25),(30,13),(30,25),(31,13),(31,36),(32,6),(32,25),
(33,6),(33,40),(34,6),(34,25),(35,6),(35,39),(36,14),(36,25),(37,14),(37,36),(38,14),(38,37),
(39,14),(39,37),(40,15),(40,8),(41,18),(41,22),(42,18),(42,10),(42,40),(43,18),(43,34),
(44,20),(44,36),(45,20),(45,26),(46,21),(46,33),(47,21),(47,33),(48,21),(48,36),
(49,19),(49,22),(49,33),(50,19),(50,22),(51,12),(51,38),(52,12),(52,38),(53,12),(53,33),(53,38),
(54,12),(54,36),(55,3),(55,36),(56,3),(56,37),(57,3),(57,23),(58,4),(58,33),(59,4),(59,23),
(60,4),(60,35),(61,30),(61,9),(62,30),(62,9),(63,31),(63,9),(64,23),(64,9),(64,40),
(65,23),(65,9),(66,17),(66,10),(67,17),(67,10),(68,17),(68,10),(68,8),(69,16),(69,10),
(70,16),(70,10),(71,20),(71,36),(72,20),(72,26),(73,21),(73,33),(74,21),(74,33),(75,21),(75,36),
(76,5),(76,7),(77,5),(77,40),(78,5),(78,25),(79,5),(79,25),(79,40),(80,13),(80,7),
(81,13),(81,40),(82,13),(82,25),(83,6),(83,25),(84,6),(84,40);

-- RUN HISTORY (обновлены snippet_id согласно новой нумерации)
INSERT INTO snippet_runs(snippet_id, run_at, executed_by_user_id) VALUES
(1,  strftime('%s','now')-86400*30, 1),(1,  strftime('%s','now')-86400*15, 1),(1,  strftime('%s','now')-86400*7,  1),(1,  strftime('%s','now')-3600,     2),
(2,  strftime('%s','now')-86400*20, 1),(2,  strftime('%s','now')-86400*3,  1),(2,  strftime('%s','now')-86400*1,  1),
(3,  strftime('%s','now')-86400*10, 1),(3,  strftime('%s','now')-86400*2,  1),
(4,  strftime('%s','now')-86400*5,  1),
(5,  strftime('%s','now')-86400*8,  2),(5,  strftime('%s','now')-86400*1,  2),
(6,  strftime('%s','now')-86400*12, 2),(6,  strftime('%s','now')-86400*4,  2),
(7,  strftime('%s','now')-86400*6,  3),(7,  strftime('%s','now')-86400*2,  3),
(8,  strftime('%s','now')-86400*3,  4),
(9,  strftime('%s','now')-86400*14, 1),(9,  strftime('%s','now')-86400*2,  1),(9,  strftime('%s','now')-7200,     1),
(10, strftime('%s','now')-86400*9,  1),(11, strftime('%s','now')-86400*7,  1),(11, strftime('%s','now')-86400*1,  4),
(12, strftime('%s','now')-86400*4,  2),(13, strftime('%s','now')-86400*6,  3),(13, strftime('%s','now')-86400*1,  3),
(14, strftime('%s','now')-86400*3,  4),(15, strftime('%s','now')-86400*25, 2),(15, strftime('%s','now')-86400*1,  2),
(16, strftime('%s','now')-86400*18, 2),(16, strftime('%s','now')-3000,     2),(17, strftime('%s','now')-86400*5,  2),
(17, strftime('%s','now')-86400*1,  2),(18, strftime('%s','now')-86400*8,  3),(19, strftime('%s','now')-86400*3,  2),
(19, strftime('%s','now')-86400*1,  2),(20, strftime('%s','now')-86400*10, 4),(21, strftime('%s','now')-86400*2,  5),
(22, strftime('%s','now')-86400*20, 1),(22, strftime('%s','now')-6000,     1),(22, strftime('%s','now')-5000,     1),
(22, strftime('%s','now')-4000,     1),(22, strftime('%s','now')-3000,     1),(23, strftime('%s','now')-86400*12, 1),
(23, strftime('%s','now')-2500,     3),(24, strftime('%s','now')-86400*7,  4),(24, strftime('%s','now')-86400*2,  4),
(25, strftime('%s','now')-86400*4,  3),(25, strftime('%s','now')-86400*1,  4),(26, strftime('%s','now')-86400*6,  3),
(27, strftime('%s','now')-86400*3,  4),(28, strftime('%s','now')-86400*5,  4),(28, strftime('%s','now')-86400*1,  4),
(29, strftime('%s','now')-86400*2,  4),(30, strftime('%s','now')-86400*28, 1),(30, strftime('%s','now')-86400*10, 1),
(30, strftime('%s','now')-86400*5,  1),(30, strftime('%s','now')-86400*1,  5),(31, strftime('%s','now')-86400*8,  5),
(31, strftime('%s','now')-86400*2,  5),(32, strftime('%s','now')-86400*6,  5),(33, strftime('%s','now')-86400*4,  5),
(33, strftime('%s','now')-86400*1,  5),(34, strftime('%s','now')-86400*3,  5),(35, strftime('%s','now')-86400*9,  5),
(36, strftime('%s','now')-86400*15, 1),(36, strftime('%s','now')-1800,     1),(37, strftime('%s','now')-86400*7,  1),
(38, strftime('%s','now')-86400*3,  5),(39, strftime('%s','now')-86400*5,  5),(40, strftime('%s','now')-86400*20, 5),
(40, strftime('%s','now')-86400*5,  5),(41, strftime('%s','now')-86400*3,  5),(41, strftime('%s','now')-86400*1,  5),
(42, strftime('%s','now')-86400*8,  5),(43, strftime('%s','now')-86400*4,  5),(44, strftime('%s','now')-86400*2,  5),
(45, strftime('%s','now')-86400*6,  5),(45, strftime('%s','now')-86400*1,  5),(46, strftime('%s','now')-86400*3,  5),
(49, strftime('%s','now')-86400*25, 1),(49, strftime('%s','now')-86400*10, 1),(49, strftime('%s','now')-1200,     3),
(50, strftime('%s','now')-86400*12, 1),(50, strftime('%s','now')-86400*3,  4),(51, strftime('%s','now')-86400*5,  4),
(51, strftime('%s','now')-86400*1,  4),(52, strftime('%s','now')-86400*3,  4),(54, strftime('%s','now')-86400*7,  4),
(54, strftime('%s','now')-86400*2,  4),(55, strftime('%s','now')-86400*4,  4),(56, strftime('%s','now')-86400*15, 3),
(56, strftime('%s','now')-86400*5,  3),(57, strftime('%s','now')-86400*8,  3),(58, strftime('%s','now')-86400*10, 3),
(59, strftime('%s','now')-86400*3,  3),(60, strftime('%s','now')-86400*20, 3),(61, strftime('%s','now')-86400*6,  3),
(62, strftime('%s','now')-86400*4,  3),(63, strftime('%s','now')-86400*12, 2),(64, strftime('%s','now')-86400*5,  2),
(66, strftime('%s','now')-86400*8,  2),(66, strftime('%s','now')-86400*2,  2),(68, strftime('%s','now')-86400*6,  4),
(69, strftime('%s','now')-86400*3,  4),(70, strftime('%s','now')-86400*10, 4),(70, strftime('%s','now')-86400*2,  4),
(71, strftime('%s','now')-86400*1,  4),(73, strftime('%s','now')-86400*15, 3),(73, strftime('%s','now')-86400*5,  3),
(74, strftime('%s','now')-86400*8,  3),(75, strftime('%s','now')-86400*3,  3),(75, strftime('%s','now')-86400*1,  3),
(76, strftime('%s','now')-86400*6,  3),(77, strftime('%s','now')-86400*18, 2),(77, strftime('%s','now')-1000,     2),
(77, strftime('%s','now')-500,      2),(77, strftime('%s','now')-100,      2),(78, strftime('%s','now')-86400*7,  1),
(79, strftime('%s','now')-86400*10, 1),(80, strftime('%s','now')-86400*5,  3),(81, strftime('%s','now')-86400*3,  4),
(82, strftime('%s','now')-86400*2,  4),(83, strftime('%s','now')-86400*1,  4),(84, strftime('%s','now')-86400*4,  4);