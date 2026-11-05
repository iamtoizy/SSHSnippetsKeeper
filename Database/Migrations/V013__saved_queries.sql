---------------------------------------------------------
-- V013: Умные папки (saved queries) - именованные
-- сохранённые запросы языка поиска (узлы дерева).
---------------------------------------------------------

CREATE TABLE IF NOT EXISTS saved_queries (
  id         INTEGER PRIMARY KEY,
  user_id    INTEGER NOT NULL,
  name       TEXT NOT NULL COLLATE NOCASE,
  query_text TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_saved_queries_name_user ON saved_queries(name COLLATE NOCASE, user_id);
CREATE INDEX IF NOT EXISTS ix_saved_queries_user ON saved_queries(user_id);
