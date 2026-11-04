---------------------------------------------------------
-- V009: История версий сниппетов (снимок заменяемого контента)
-- и служебные флаги (подавление истории на время массового импорта).
---------------------------------------------------------

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

-- Снимок заменяемой версии при реальном изменении контента.
-- Не срабатывает, пока установлен флаг history_suppressed.
CREATE TRIGGER IF NOT EXISTS trg_snippets_history_au
AFTER UPDATE ON snippets
WHEN OLD.content <> NEW.content
 AND (SELECT value FROM service_flags WHERE name = 'history_suppressed') <> '1'
BEGIN
  INSERT INTO snippet_history (snippet_id, title, content, comment, category_id)
  VALUES (OLD.id, OLD.title, OLD.content, OLD.comment, OLD.category_id);
END;
