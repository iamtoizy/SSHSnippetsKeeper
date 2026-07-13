PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA temp_store = MEMORY;
PRAGMA user_version = 7; -- v7: Добавлено поле is_security_ignored для отключения сканера утилиты
PRAGMA recursive_triggers = OFF;
PRAGMA busy_timeout = 5000;
PRAGMA cache_size = -20000;

---------------------------------------------------------
-- 1. USERS (Рабочие пространства / Workspaces)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id         INTEGER PRIMARY KEY,
  name       TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);

---------------------------------------------------------
-- 2. CATEGORIES (Дерево категорий, приватное для workspace)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_categories (
  id         INTEGER PRIMARY KEY,
  user_id    INTEGER NOT NULL,
  name       TEXT NOT NULL COLLATE NOCASE,
  parent_id  INTEGER REFERENCES snippet_categories(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_categories_name_parent_user 
  ON snippet_categories(name COLLATE NOCASE, parent_id, user_id);
CREATE INDEX IF NOT EXISTS ix_categories_parent ON snippet_categories(parent_id);
CREATE INDEX IF NOT EXISTS ix_categories_user ON snippet_categories(user_id);
CREATE INDEX IF NOT EXISTS ix_categories_sort_order ON snippet_categories(user_id, parent_id, sort_order);

---------------------------------------------------------
-- 3. SNIPPETS (Команды. Добавлено поле is_security_ignored)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippets (
  id                  INTEGER PRIMARY KEY,
  user_id             INTEGER NOT NULL,
  category_id         INTEGER REFERENCES snippet_categories(id) ON DELETE CASCADE,
  title               TEXT COLLATE NOCASE,
  content             TEXT NOT NULL COLLATE NOCASE,
  comment             TEXT NOT NULL DEFAULT '',
  is_security_ignored INTEGER NOT NULL DEFAULT 0, -- v7: 0 = проверять сканером, 1 = доверять
  created_at          INTEGER NOT NULL DEFAULT (strftime('%s','now')),
  updated_at          INTEGER, 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippets_user       ON snippets(user_id);
CREATE INDEX IF NOT EXISTS ix_snippets_category   ON snippets(category_id);
CREATE INDEX IF NOT EXISTS ix_snippets_title      ON snippets(title);
CREATE INDEX IF NOT EXISTS ix_snippets_created_at ON snippets(created_at DESC);
CREATE INDEX IF NOT EXISTS ix_snippets_updated_at ON snippets(updated_at DESC);

---------------------------------------------------------
-- 4. FTS (Полнотекстовый поиск)
---------------------------------------------------------
-- Используем стандартную FTS5 таблицу для надежной индексации тегов
CREATE VIRTUAL TABLE IF NOT EXISTS snippet_fts USING fts5(
    title,
    content,
    comment,
    tags,
    tokenize='unicode61 remove_diacritics 1'
);

---------------------------------------------------------
-- 5. TAGS (Глобальные теги)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS tags (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_tags_name ON tags(name COLLATE NOCASE);

---------------------------------------------------------
-- 6. SNIPPET_TAGS (Связь Many-to-Many)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_tags (
  snippet_id INTEGER NOT NULL,
  tag_id     INTEGER NOT NULL,
  PRIMARY KEY (snippet_id, tag_id),
  FOREIGN KEY (snippet_id) REFERENCES snippets(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id)     REFERENCES tags(id)     ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippet_tags_snip ON snippet_tags(snippet_id);
CREATE INDEX IF NOT EXISTS ix_snippet_tags_tag  ON snippet_tags(tag_id);

---------------------------------------------------------
-- 7. SNIPPET RUN HISTORY (История запусков)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_runs (
  id                  INTEGER PRIMARY KEY,
  snippet_id          INTEGER NOT NULL,
  run_at              INTEGER NOT NULL,
  executed_by_user_id INTEGER,
  FOREIGN KEY (snippet_id)          REFERENCES snippets(id) ON DELETE CASCADE,
  FOREIGN KEY (executed_by_user_id) REFERENCES users(id)    ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_runs_snippet      ON snippet_runs(snippet_id);
CREATE INDEX IF NOT EXISTS ix_runs_snippet_time ON snippet_runs(snippet_id, run_at DESC);
CREATE INDEX IF NOT EXISTS ix_snippet_runs_time ON snippet_runs(run_at DESC);

---------------------------------------------------------
-- 8. AGGREGATES (Статистика для быстрого доступа)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_stats (
  snippet_id   INTEGER PRIMARY KEY,
  exec_count   INTEGER NOT NULL DEFAULT 0 CHECK (exec_count >= 0),
  last_exec_at INTEGER,
  FOREIGN KEY (snippet_id) REFERENCES snippets(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippet_stats_order ON snippet_stats(exec_count DESC, last_exec_at DESC);

---------------------------------------------------------
-- 9. TRIGGERS (Бизнес-правила БД и синхронизация FTS)
---------------------------------------------------------

-- Запрет перемещения категорий в чужие workspace
CREATE TRIGGER IF NOT EXISTS trg_categories_same_workspace_insert
BEFORE INSERT ON snippet_categories
WHEN NEW.parent_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'Родительская категория принадлежит другому workspace')
    WHERE (SELECT user_id FROM snippet_categories WHERE id = NEW.parent_id) <> NEW.user_id;
END;

-- ВАЖНО: Триггер trg_snippets_updated_at УДАЛЕН.
-- Обновление поля updated_at теперь контролируется приложением в TSnippetService.

-- Обновление статистики (добавление запуска)
DROP TRIGGER IF EXISTS trg_runs_ai;
CREATE TRIGGER trg_runs_ai
AFTER INSERT ON snippet_runs
BEGIN
  INSERT INTO snippet_stats (snippet_id, exec_count, last_exec_at)
  VALUES (NEW.snippet_id, 1, NEW.run_at)
  ON CONFLICT(snippet_id) DO UPDATE SET
    exec_count   = snippet_stats.exec_count + 1,
    last_exec_at = CASE
                     WHEN excluded.last_exec_at > snippet_stats.last_exec_at OR snippet_stats.last_exec_at IS NULL
                     THEN excluded.last_exec_at
                     ELSE snippet_stats.last_exec_at
                   END;
END;

-- Обновление статистики (удаление запуска)
DROP TRIGGER IF EXISTS trg_runs_ad;
CREATE TRIGGER trg_runs_ad
AFTER DELETE ON snippet_runs
BEGIN
  UPDATE snippet_stats SET exec_count = exec_count - 1 WHERE snippet_id = OLD.snippet_id;
  UPDATE snippet_stats SET last_exec_at = (SELECT MAX(run_at) FROM snippet_runs WHERE snippet_id = OLD.snippet_id) WHERE snippet_id = OLD.snippet_id;
  DELETE FROM snippet_stats WHERE snippet_id = OLD.snippet_id AND exec_count <= 0;
END;

-- Обновление статистики (изменение запуска)
DROP TRIGGER IF EXISTS trg_runs_au;
CREATE TRIGGER trg_runs_au
AFTER UPDATE ON snippet_runs
BEGIN
  UPDATE snippet_stats SET exec_count = exec_count - 1 WHERE snippet_id = OLD.snippet_id;
  UPDATE snippet_stats SET last_exec_at = (SELECT MAX(run_at) FROM snippet_runs WHERE snippet_id = OLD.snippet_id) WHERE snippet_id = OLD.snippet_id;
  DELETE FROM snippet_stats WHERE snippet_id = OLD.snippet_id AND exec_count <= 0;

  INSERT INTO snippet_stats (snippet_id, exec_count, last_exec_at)
  VALUES (NEW.snippet_id, 1, NEW.run_at)
  ON CONFLICT(snippet_id) DO UPDATE SET
    exec_count = snippet_stats.exec_count + 1,
    last_exec_at = CASE
                     WHEN excluded.last_exec_at > snippet_stats.last_exec_at OR snippet_stats.last_exec_at IS NULL
                     THEN excluded.last_exec_at
                     ELSE snippet_stats.last_exec_at
                   END;
END;

-- FTS: Синхронизация при обновлении названия тега
DROP TRIGGER IF EXISTS trg_tags_au;
CREATE TRIGGER trg_tags_au
AFTER UPDATE OF name ON tags
BEGIN
  DELETE FROM snippet_fts WHERE rowid IN (SELECT snippet_id FROM snippet_tags WHERE tag_id = NEW.id);
  INSERT INTO snippet_fts(rowid, title, content, comment, tags)
  SELECT s.id, s.title, s.content, s.comment,
    (SELECT group_concat(t.name, ' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = s.id)
  FROM snippets s WHERE s.id IN (SELECT snippet_id FROM snippet_tags WHERE tag_id = NEW.id);
END;

-- FTS: Синхронизация при удалении тега
DROP TRIGGER IF EXISTS trg_tags_ad;
CREATE TRIGGER trg_tags_ad
AFTER DELETE ON tags
BEGIN
  DELETE FROM snippet_fts WHERE rowid IN (SELECT snippet_id FROM snippet_tags WHERE tag_id = OLD.id);
  INSERT INTO snippet_fts(rowid, title, content, comment, tags)
  SELECT s.id, s.title, s.content, s.comment,
    (SELECT group_concat(t.name, ' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = s.id)
  FROM snippets s WHERE s.id IN (SELECT snippet_id FROM snippet_tags WHERE tag_id = OLD.id);
END;

-- FTS: Синхронизация при добавлении сниппета
CREATE TRIGGER IF NOT EXISTS trg_fts_snip_ai
AFTER INSERT ON snippets
BEGIN
  INSERT INTO snippet_fts(rowid, title, content, comment, tags)
  VALUES (
    NEW.id, NEW.title, NEW.content, NEW.comment,
    (SELECT group_concat(t.name, ' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = NEW.id)
  );
END;

-- FTS: Синхронизация при обновлении сниппета
CREATE TRIGGER IF NOT EXISTS trg_fts_snip_au
AFTER UPDATE ON snippets
BEGIN
  DELETE FROM snippet_fts WHERE rowid = OLD.id;
  INSERT INTO snippet_fts(rowid, title, content, comment, tags)
  VALUES (
    NEW.id, NEW.title, NEW.content, NEW.comment,
    (SELECT group_concat(t.name, ' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = NEW.id)
  );
END;

-- FTS: Синхронизация при удалении сниппета
CREATE TRIGGER IF NOT EXISTS trg_fts_snip_ad
AFTER DELETE ON snippets
BEGIN
  DELETE FROM snippet_fts WHERE rowid = OLD.id;
END;

-- FTS: Синхронизация при привязке тега
DROP TRIGGER IF EXISTS trg_snippet_tags_ai;
CREATE TRIGGER IF NOT EXISTS trg_snippet_tags_ai
AFTER INSERT ON snippet_tags
BEGIN
  DELETE FROM snippet_fts WHERE rowid = NEW.snippet_id;
  INSERT INTO snippet_fts(rowid, title, content, comment, tags)
  SELECT s.id, s.title, s.content, s.comment,
    (SELECT group_concat(t.name, ' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = s.id)
  FROM snippets s WHERE s.id = NEW.snippet_id;
END;

-- FTS: Синхронизация при отвязке тега
DROP TRIGGER IF EXISTS trg_snippet_tags_ad;
CREATE TRIGGER IF NOT EXISTS trg_snippet_tags_ad
AFTER DELETE ON snippet_tags
BEGIN
  DELETE FROM snippet_fts WHERE rowid = OLD.snippet_id;
  INSERT INTO snippet_fts(rowid, title, content, comment, tags)
  SELECT s.id, s.title, s.content, s.comment,
    (SELECT group_concat(t.name, ' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = s.id)
  FROM snippets s WHERE s.id = OLD.snippet_id;
END;

---------------------------------------------------------
-- 10. VIEWS (Представления)
---------------------------------------------------------
CREATE VIEW IF NOT EXISTS v_snippet_top_overall AS
SELECT s.id AS snippet_id,
       s.user_id,
       s.title,
       s.category_id,
       st.exec_count,
       st.last_exec_at
FROM snippets s
JOIN snippet_stats st ON st.snippet_id = s.id;