---------------------------------------------------------
-- V010: Цепочки сниппетов (именованная последовательность
-- шагов-сниппетов) и их шаги (порядок, пауза после шага).
---------------------------------------------------------

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
