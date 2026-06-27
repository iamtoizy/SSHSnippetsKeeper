PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA temp_store = MEMORY;
PRAGMA user_version = 3; -- новая версия, т.к. добавили категории
PRAGMA recursive_triggers = OFF;
PRAGMA busy_timeout = 5000;
PRAGMA cache_size = -20000;

---------------------------------------------------------
-- USERS
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,
  created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);

---------------------------------------------------------
-- CATEGORIES (дерево)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_categories (
  id        INTEGER PRIMARY KEY,
  name      TEXT NOT NULL COLLATE NOCASE,
  parent_id INTEGER REFERENCES snippet_categories(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_categories_name_parent
  ON snippet_categories(name COLLATE NOCASE, parent_id);
CREATE INDEX IF NOT EXISTS ix_categories_parent 
  ON snippet_categories(parent_id);

---------------------------------------------------------
-- SNIPPETS
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippets (
  id           INTEGER PRIMARY KEY,
  user_id      INTEGER NOT NULL,
  category_id  INTEGER REFERENCES snippet_categories(id) ON DELETE SET NULL,
  title        TEXT,
  content      TEXT NOT NULL,
  created_at   INTEGER NOT NULL DEFAULT (strftime('%s','now')),
  updated_at   INTEGER,
  CHECK (length(trim(content)) > 0),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippets_user       ON snippets(user_id);
CREATE INDEX IF NOT EXISTS ix_snippets_category   ON snippets(category_id);
CREATE INDEX IF NOT EXISTS ix_snippets_title      ON snippets(title);
CREATE INDEX IF NOT EXISTS ix_snippets_created_at ON snippets(created_at DESC);
CREATE INDEX IF NOT EXISTS ix_snippets_updated_at ON snippets(updated_at DESC);

-- Виртуальная FTS таблица для полнотекстового поиска
CREATE VIRTUAL TABLE snippet_fts USING fts5(
    title,
    content,
    tags,
    tokenize='unicode61 remove_diacritics 1'
);

---------------------------------------------------------
-- TAGS
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS tags (
  id    INTEGER PRIMARY KEY,
  name  TEXT NOT NULL COLLATE NOCASE UNIQUE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_tags_name ON tags(name COLLATE NOCASE);

---------------------------------------------------------
-- SNIPPET_TAGS
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_tags (
  snippet_id  INTEGER NOT NULL,
  tag_id      INTEGER NOT NULL,
  PRIMARY KEY (snippet_id, tag_id),
  FOREIGN KEY (snippet_id) REFERENCES snippets(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id)     REFERENCES tags(id)     ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippet_tags_snip ON snippet_tags(snippet_id);
CREATE INDEX IF NOT EXISTS ix_snippet_tags_tag  ON snippet_tags(tag_id);

---------------------------------------------------------
-- HOSTS
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS hosts (
  id    INTEGER PRIMARY KEY,
  name  TEXT NOT NULL COLLATE NOCASE UNIQUE
);

---------------------------------------------------------
-- SNIPPET RUN HISTORY
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_runs (
  id                   INTEGER PRIMARY KEY,
  snippet_id           INTEGER NOT NULL,
  run_at               INTEGER NOT NULL,
  host_id              INTEGER,
  executed_by_user_id  INTEGER,
  FOREIGN KEY (snippet_id)          REFERENCES snippets(id) ON DELETE CASCADE,
  FOREIGN KEY (host_id)             REFERENCES hosts(id)    ON DELETE CASCADE,
  FOREIGN KEY (executed_by_user_id) REFERENCES users(id)    ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_runs_snippet                   ON snippet_runs(snippet_id);
CREATE INDEX IF NOT EXISTS ix_runs_snippet_time              ON snippet_runs(snippet_id, run_at DESC);
CREATE INDEX IF NOT EXISTS ix_runs_snippet_host_time         ON snippet_runs(snippet_id, host_id, run_at DESC);
CREATE INDEX IF NOT EXISTS ix_runs_host                      ON snippet_runs(host_id);
CREATE INDEX IF NOT EXISTS ix_snippet_runs_time              ON snippet_runs(run_at DESC);

---------------------------------------------------------
-- AGGREGATES
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS snippet_stats (
  snippet_id    INTEGER PRIMARY KEY,
  exec_count    INTEGER NOT NULL DEFAULT 0 CHECK (exec_count >= 0),
  last_exec_at  INTEGER,
  FOREIGN KEY (snippet_id) REFERENCES snippets(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS snippet_host_stats (
  snippet_id    INTEGER NOT NULL,
  host_id       INTEGER NOT NULL,
  exec_count    INTEGER NOT NULL DEFAULT 0 CHECK (exec_count >= 0),
  last_exec_at  INTEGER,
  PRIMARY KEY (snippet_id, host_id),
  FOREIGN KEY (snippet_id) REFERENCES snippets(id) ON DELETE CASCADE,
  FOREIGN KEY (host_id)    REFERENCES hosts(id)    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_snippet_stats_order
  ON snippet_stats(exec_count DESC, last_exec_at DESC);

CREATE INDEX IF NOT EXISTS ix_snippet_host_stats_order
  ON snippet_host_stats(host_id, exec_count DESC, last_exec_at DESC);

---------------------------------------------------------
-- TRIGGERS
---------------------------------------------------------

-- Сниппеты

-- snippet_runs AFTER INSERT
DROP TRIGGER IF EXISTS trg_runs_ai;
CREATE TRIGGER trg_runs_ai
AFTER INSERT ON snippet_runs
BEGIN
  INSERT INTO snippet_stats (snippet_id, exec_count, last_exec_at)
  VALUES (NEW.snippet_id, 1, NEW.run_at)
  ON CONFLICT(snippet_id) DO UPDATE SET
    exec_count   = snippet_stats.exec_count + 1,
    last_exec_at = CASE
                     WHEN excluded.last_exec_at > snippet_stats.last_exec_at
                          OR snippet_stats.last_exec_at IS NULL
                     THEN excluded.last_exec_at
                     ELSE snippet_stats.last_exec_at
                   END;

  INSERT INTO snippet_host_stats (snippet_id, host_id, exec_count, last_exec_at)
  SELECT NEW.snippet_id, NEW.host_id, 1, NEW.run_at
  WHERE NEW.host_id IS NOT NULL
  ON CONFLICT(snippet_id, host_id) DO UPDATE SET
    exec_count   = snippet_host_stats.exec_count + 1,
    last_exec_at = CASE
                     WHEN excluded.last_exec_at > snippet_host_stats.last_exec_at
                          OR snippet_host_stats.last_exec_at IS NULL
                     THEN excluded.last_exec_at
                     ELSE snippet_host_stats.last_exec_at
                   END;
END;

-- snippet_runs AFTER DELETE
DROP TRIGGER IF EXISTS trg_runs_ad;
CREATE TRIGGER trg_runs_ad
AFTER DELETE ON snippet_runs
BEGIN
  UPDATE snippet_stats
     SET exec_count = exec_count - 1
   WHERE snippet_id = OLD.snippet_id;

  UPDATE snippet_stats
     SET last_exec_at = (SELECT MAX(run_at) FROM snippet_runs WHERE snippet_id = OLD.snippet_id)
   WHERE snippet_id = OLD.snippet_id;

  DELETE FROM snippet_stats WHERE snippet_id = OLD.snippet_id AND exec_count <= 0;

  UPDATE snippet_host_stats
     SET exec_count = exec_count - 1
   WHERE OLD.host_id IS NOT NULL
     AND snippet_id = OLD.snippet_id
     AND host_id    = OLD.host_id;

  UPDATE snippet_host_stats
     SET last_exec_at = (SELECT MAX(run_at) FROM snippet_runs
                          WHERE snippet_id = OLD.snippet_id
                            AND host_id    = OLD.host_id)
   WHERE OLD.host_id IS NOT NULL
     AND snippet_id = OLD.snippet_id
     AND host_id    = OLD.host_id;

  DELETE FROM snippet_host_stats
   WHERE snippet_id = OLD.snippet_id
     AND host_id    = OLD.host_id
     AND exec_count <= 0;
END;

-- snippet_runs AFTER UPDATE
DROP TRIGGER IF EXISTS trg_runs_au;

CREATE TRIGGER trg_runs_au
AFTER UPDATE ON snippet_runs
BEGIN
  ----------------------------------------------------
  -- Уменьшаем старую статистику
  ----------------------------------------------------
  UPDATE snippet_stats
     SET exec_count = exec_count - 1
   WHERE snippet_id = OLD.snippet_id;

  UPDATE snippet_host_stats
     SET exec_count = exec_count - 1
   WHERE OLD.host_id IS NOT NULL
     AND snippet_id = OLD.snippet_id
     AND host_id = OLD.host_id;

  ----------------------------------------------------
  -- Пересчитываем OLD.last_exec_at
  ----------------------------------------------------
  UPDATE snippet_stats
     SET last_exec_at = (
        SELECT MAX(run_at)
        FROM snippet_runs
        WHERE snippet_id = OLD.snippet_id
     )
   WHERE snippet_id = OLD.snippet_id;

  UPDATE snippet_host_stats
     SET last_exec_at = (
        SELECT MAX(run_at)
        FROM snippet_runs
        WHERE snippet_id = OLD.snippet_id
          AND host_id = OLD.host_id
     )
   WHERE OLD.host_id IS NOT NULL
     AND snippet_id = OLD.snippet_id
     AND host_id = OLD.host_id;

  ----------------------------------------------------
  -- Удаляем пустые записи
  ----------------------------------------------------
  DELETE FROM snippet_stats
   WHERE snippet_id = OLD.snippet_id
     AND exec_count <= 0;

  DELETE FROM snippet_host_stats
   WHERE snippet_id = OLD.snippet_id
     AND host_id = OLD.host_id
     AND exec_count <= 0;

  ----------------------------------------------------
  -- Добавляем новую статистику
  ----------------------------------------------------
  INSERT INTO snippet_stats (
      snippet_id,
      exec_count,
      last_exec_at
  )
  VALUES (
      NEW.snippet_id,
      1,
      NEW.run_at
  )
  ON CONFLICT(snippet_id)
  DO UPDATE SET
      exec_count = snippet_stats.exec_count + 1,
      last_exec_at = CASE
          WHEN excluded.last_exec_at > snippet_stats.last_exec_at
               OR snippet_stats.last_exec_at IS NULL
          THEN excluded.last_exec_at
          ELSE snippet_stats.last_exec_at
      END;

  INSERT INTO snippet_host_stats (
      snippet_id,
      host_id,
      exec_count,
      last_exec_at
  )
  SELECT
      NEW.snippet_id,
      NEW.host_id,
      1,
      NEW.run_at
  WHERE NEW.host_id IS NOT NULL
  ON CONFLICT(snippet_id, host_id)
  DO UPDATE SET
      exec_count = snippet_host_stats.exec_count + 1,
      last_exec_at = CASE
          WHEN excluded.last_exec_at > snippet_host_stats.last_exec_at
               OR snippet_host_stats.last_exec_at IS NULL
          THEN excluded.last_exec_at
          ELSE snippet_host_stats.last_exec_at
      END;

  ----------------------------------------------------
  -- Если изменился только run_at назад во времени,
  -- пересчитываем NEW.last_exec_at.
  ----------------------------------------------------
  UPDATE snippet_stats
     SET last_exec_at = (
        SELECT MAX(run_at)
        FROM snippet_runs
        WHERE snippet_id = NEW.snippet_id
     )
   WHERE snippet_id = NEW.snippet_id;

  UPDATE snippet_host_stats
     SET last_exec_at = (
        SELECT MAX(run_at)
        FROM snippet_runs
        WHERE snippet_id = NEW.snippet_id
          AND host_id = NEW.host_id
     )
   WHERE NEW.host_id IS NOT NULL
     AND snippet_id = NEW.snippet_id
     AND host_id = NEW.host_id;
END;

-- FTS триггеры

-- триггеры для изменения тегов
DROP TRIGGER IF EXISTS trg_tags_au;

CREATE TRIGGER trg_tags_au
AFTER UPDATE OF name ON tags
BEGIN
  DELETE FROM snippet_fts
   WHERE rowid IN (
      SELECT snippet_id
      FROM snippet_tags
      WHERE tag_id = NEW.id
   );

  INSERT INTO snippet_fts(rowid, title, content, tags)
  SELECT
      s.id,
      s.title,
      s.content,
      (
          SELECT group_concat(t.name, ' ')
          FROM snippet_tags st
          JOIN tags t ON t.id = st.tag_id
          WHERE st.snippet_id = s.id
      )
  FROM snippets s
  WHERE s.id IN (
      SELECT snippet_id
      FROM snippet_tags
      WHERE tag_id = NEW.id
  );
END;

DROP TRIGGER IF EXISTS trg_tags_ad;

CREATE TRIGGER trg_tags_ad
AFTER DELETE ON tags
BEGIN
  DELETE FROM snippet_fts
   WHERE rowid IN (
      SELECT snippet_id
      FROM snippet_tags
      WHERE tag_id = OLD.id
   );

  INSERT INTO snippet_fts(rowid, title, content, tags)
  SELECT
      s.id,
      s.title,
      s.content,
      (
          SELECT group_concat(t.name, ' ')
          FROM snippet_tags st
          JOIN tags t ON t.id = st.tag_id
          WHERE st.snippet_id = s.id
      )
  FROM snippets s
  WHERE s.id IN (
      SELECT snippet_id
      FROM snippet_tags
      WHERE tag_id = OLD.id
  );
END;

CREATE TRIGGER IF NOT EXISTS trg_fts_snip_ai
AFTER INSERT ON snippets BEGIN
  INSERT INTO snippet_fts(rowid,title,content,tags)
  VALUES (
    NEW.id,
    NEW.title,
    NEW.content,
    (SELECT group_concat(t.name,' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = NEW.id)
  );
END;

CREATE TRIGGER IF NOT EXISTS trg_fts_snip_au
AFTER UPDATE ON snippets BEGIN
  DELETE FROM snippet_fts WHERE rowid = OLD.id;
  
  INSERT INTO snippet_fts(rowid,title,content,tags)
  VALUES (
    NEW.id,
    NEW.title,
    NEW.content,
    (SELECT group_concat(t.name,' ') FROM snippet_tags st JOIN tags t ON t.id = st.tag_id WHERE st.snippet_id = NEW.id)
  );
END;

CREATE TRIGGER IF NOT EXISTS trg_fts_snip_ad
AFTER DELETE ON snippets BEGIN
  DELETE FROM snippet_fts WHERE rowid = OLD.id;
END;

-- Триггер AFTER INSERT на snippet_tags
DROP TRIGGER IF EXISTS trg_snippet_tags_ai;
CREATE TRIGGER IF NOT EXISTS trg_snippet_tags_ai
AFTER INSERT ON snippet_tags
BEGIN
  DELETE FROM snippet_fts WHERE rowid = NEW.snippet_id;
  
  INSERT INTO snippet_fts(rowid,title,content,tags)
  SELECT 
    s.id,
    s.title,
    s.content,
    (SELECT group_concat(t.name, ' ') 
     FROM snippet_tags st 
     JOIN tags t ON t.id = st.tag_id 
     WHERE st.snippet_id = s.id)
  FROM snippets s 
  WHERE s.id = NEW.snippet_id;
END;

-- Триггер AFTER DELETE на snippet_tags
DROP TRIGGER IF EXISTS trg_snippet_tags_ad;
CREATE TRIGGER IF NOT EXISTS trg_snippet_tags_ad
AFTER DELETE ON snippet_tags
BEGIN
  DELETE FROM snippet_fts WHERE rowid = OLD.snippet_id;
  
  INSERT INTO snippet_fts(rowid,title,content,tags)
  SELECT 
    s.id,
    s.title,
    s.content,
    (SELECT group_concat(t.name, ' ') 
     FROM snippet_tags st 
     JOIN tags t ON t.id = st.tag_id 
     WHERE st.snippet_id = s.id)
  FROM snippets s 
  WHERE s.id = OLD.snippet_id;
END;

---------------------------------------------------------
-- VIEWS
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

CREATE VIEW IF NOT EXISTS v_snippet_host_stats AS
SELECT sh.snippet_id,
       sh.host_id,
       h.name AS host_name,
       sh.exec_count,
       sh.last_exec_at
FROM snippet_host_stats sh
JOIN hosts h ON h.id = sh.host_id;
