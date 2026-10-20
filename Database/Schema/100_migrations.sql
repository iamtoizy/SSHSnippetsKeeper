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

PRAGMA user_version = 8;
