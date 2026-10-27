---------------------------------------------------------
-- Идемпотентные миграции для существующих БД.
-- Выполняются при каждом открытии (OpenDatabase).
-- Все инструкции должны быть безопасны для повторного запуска.
---------------------------------------------------------

-- v8: Избранное (порядок задаёт горячие слоты 1..0)
CREATE TABLE IF NOT EXISTS snippet_favorites (
  user_id    INTEGER NOT NULL,
  snippet_id INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
  PRIMARY KEY (user_id, snippet_id),
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (snippet_id) REFERENCES snippets(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippet_favorites_order ON snippet_favorites(user_id, sort_order);

-- v9: История версий сниппетов (снимок заменяемого контента)
CREATE TABLE IF NOT EXISTS snippet_history (
  id          INTEGER PRIMARY KEY,
  snippet_id  INTEGER NOT NULL,
  title       TEXT COLLATE NOCASE,
  content     TEXT NOT NULL COLLATE NOCASE,
  comment     TEXT NOT NULL DEFAULT '',
  category_id INTEGER,
  changed_at  INTEGER NOT NULL DEFAULT (strftime('%s','now')),
  FOREIGN KEY (snippet_id) REFERENCES snippets(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippet_history_snippet ON snippet_history(snippet_id, changed_at DESC);

CREATE TABLE IF NOT EXISTS service_flags (
  name  TEXT PRIMARY KEY,
  value TEXT NOT NULL DEFAULT ''
);

INSERT OR IGNORE INTO service_flags(name, value) VALUES ('history_suppressed', '0');

CREATE TRIGGER IF NOT EXISTS trg_snippets_history_au
AFTER UPDATE ON snippets
WHEN OLD.content <> NEW.content
 AND (SELECT value FROM service_flags WHERE name = 'history_suppressed') <> '1'
BEGIN
  INSERT INTO snippet_history (snippet_id, title, content, comment, category_id)
  VALUES (OLD.id, OLD.title, OLD.content, OLD.comment, OLD.category_id);
END;

-- v10: Цепочки сниппетов (именованная последовательность шагов-сниппетов)
CREATE TABLE IF NOT EXISTS snippet_chains (
  id         INTEGER PRIMARY KEY,
  user_id    INTEGER NOT NULL,
  name       TEXT NOT NULL COLLATE NOCASE,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_chains_name_user ON snippet_chains(name COLLATE NOCASE, user_id);
CREATE INDEX IF NOT EXISTS ix_chains_user ON snippet_chains(user_id);

CREATE TABLE IF NOT EXISTS snippet_chain_steps (
  id         INTEGER PRIMARY KEY,
  chain_id   INTEGER NOT NULL,
  position   INTEGER NOT NULL,
  snippet_id INTEGER NOT NULL,
  pause_ms   INTEGER NOT NULL DEFAULT 0 CHECK (pause_ms >= 0),
  FOREIGN KEY (chain_id)   REFERENCES snippet_chains(id) ON DELETE CASCADE,
  FOREIGN KEY (snippet_id) REFERENCES snippets(id)       ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_chain_steps_chain   ON snippet_chain_steps(chain_id, position);
CREATE INDEX IF NOT EXISTS ix_chain_steps_snippet ON snippet_chain_steps(snippet_id);

-- v11: Язык сниппета для подсветки синтаксиса (snippets.language TEXT NOT NULL DEFAULT 'bash').
-- ALTER TABLE ADD COLUMN не идемпотентен и не поддерживает IF NOT EXISTS, а этот скрипт
-- выполняется при каждом открытии БД, поэтому колонка добавляется кодом в
-- TAppDatabase.ApplySchemaMigrations по проверке pragma_table_info.
-- Для новых БД колонку сразу задаёт 000_schema_init.sql.
PRAGMA user_version = 11;
