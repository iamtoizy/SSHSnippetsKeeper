-- Проверка агрегатов

SELECT * FROM snippet_stats
ORDER BY exec_count DESC;

-- Проверка статистики по хостам

SELECT *
FROM v_snippet_host_stats
ORDER BY host_name, exec_count DESC;

-- Проверка дерева категорий

SELECT
    c1.name AS category,
    c2.name AS subcategory
FROM snippet_categories c1
LEFT JOIN snippet_categories c2
    ON c2.parent_id = c1.id
ORDER BY c1.name;

-- Проверка FTS

SELECT rowid, title
FROM snippet_fts
WHERE snippet_fts MATCH 'docker';
SELECT rowid, title
FROM snippet_fts
WHERE snippet_fts MATCH 'backup';
SELECT rowid, title
FROM snippet_fts
WHERE snippet_fts MATCH 'systemd';

-- Проверка триггеров удаления

DELETE FROM snippet_runs
WHERE snippet_id = 7;

-- После этого:

SELECT *
FROM snippet_stats
WHERE snippet_id = 7;

-- строки вообще не должно остаться. Это тест trg_runs_ad и trg_runs_au.