-- BrainQ DB – MySQL 9.x compatible
DROP DATABASE IF EXISTS brainq_db;
CREATE DATABASE brainq_db 
USE brainq_db;


/* =========================
   USERS & AUTHENTICATION
   ========================= */
CREATE TABLE users (
  user_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  email         VARCHAR(255) NOT NULL,
  username      VARCHAR(50)  NOT NULL,
  password_hash VARCHAR(255) NULL,
  role          ENUM('user','admin') NOT NULL DEFAULT 'user',
  is_suspended  TINYINT(1) NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_login    DATETIME NULL,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_username (username),
  KEY idx_users_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE oauth_accounts (
  oauth_id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  user_id          BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  provider         ENUM('google','facebook') NOT NULL,
  provider_user_id VARCHAR(191) NOT NULL,
  access_token     TEXT NULL,
  refresh_token    TEXT NULL,
  linked_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (oauth_id),
  UNIQUE KEY uq_provider_user (provider, provider_user_id),
  KEY idx_oauth_user (user_id),
  CONSTRAINT fk_oauth_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE password_resets (
  token_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  user_id    BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at    DATETIME NULL,
  PRIMARY KEY (token_id),
  KEY idx_pr_user (user_id),
  KEY idx_pr_expires (expires_at),
  CONSTRAINT fk_passwordreset_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/* =========================
   DECKS, CARDS, TAGS, SHARING
   ========================= */
CREATE TABLE decks (
  deck_id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  owner_id               BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  title                  VARCHAR(150) NOT NULL,
  description            TEXT NULL,
  is_public              TINYINT(1) NOT NULL DEFAULT 0,
  archived_at            DATETIME NULL,
  populated_from_deck_id BIGINT UNSIGNED NULL COMMENT 'FK → decks.deck_id',
  ai_generated           TINYINT(1) NOT NULL DEFAULT 0,
  cover_image_url        VARCHAR(500) NULL,
  customization_settings JSON NULL,
  average_rating         DECIMAL(3,2) NULL,
  total_ratings          INT UNSIGNED NOT NULL DEFAULT 0,
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (deck_id),
  KEY idx_decks_owner (owner_id),
  KEY idx_decks_populated_from (populated_from_deck_id),
  CONSTRAINT fk_decks_owner          FOREIGN KEY (owner_id)               REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_decks_populated_from FOREIGN KEY (populated_from_deck_id) REFERENCES decks (deck_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE cards (
  card_id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  deck_id                BIGINT UNSIGNED NOT NULL COMMENT 'FK → decks.deck_id',
  question               TEXT NOT NULL,
  answer                 TEXT NOT NULL,
  hint                   TEXT NULL,
  difficulty_seed        TINYINT UNSIGNED NULL,
  position_in_deck       INT UNSIGNED NULL,
  customization_settings JSON NULL,
  ai_generated           TINYINT(1) NOT NULL DEFAULT 0,
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (card_id),
  KEY idx_cards_deck (deck_id),
  CONSTRAINT fk_cards_deck FOREIGN KEY (deck_id) REFERENCES decks (deck_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tags (
  tag_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  name       VARCHAR(50) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (tag_id),
  UNIQUE KEY uq_tags_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE deck_tags (
  deck_id   BIGINT UNSIGNED NOT NULL COMMENT 'FK → decks.deck_id',
  tag_id    BIGINT UNSIGNED NOT NULL COMMENT 'FK → tags.tag_id',
  tagged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (deck_id, tag_id),
  KEY idx_deck_tags_deck (deck_id),
  KEY idx_deck_tags_tag (tag_id),
  CONSTRAINT fk_decktags_deck FOREIGN KEY (deck_id) REFERENCES decks (deck_id) ON DELETE CASCADE,
  CONSTRAINT fk_decktags_tag  FOREIGN KEY (tag_id)  REFERENCES tags  (tag_id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE deck_shares (
  share_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  deck_id           BIGINT UNSIGNED NOT NULL COMMENT 'FK → decks.deck_id',
  recipient_user_id BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  can_edit          TINYINT(1) NOT NULL DEFAULT 0,
  shared_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (share_id),
  UNIQUE KEY uq_deck_share (deck_id, recipient_user_id),
  KEY idx_deck_shares_deck (deck_id),
  KEY idx_deck_shares_user (recipient_user_id),
  CONSTRAINT fk_deckshares_deck FOREIGN KEY (deck_id) REFERENCES decks (deck_id) ON DELETE CASCADE,
  CONSTRAINT fk_deckshares_user FOREIGN KEY (recipient_user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE ratings (
  rating_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  deck_id    BIGINT UNSIGNED NOT NULL COMMENT 'FK → decks.deck_id',
  user_id    BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  stars      TINYINT UNSIGNED NOT NULL,
  comment    TEXT NULL,
  rated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (rating_id),
  UNIQUE KEY uq_rating_user_deck (deck_id, user_id),
  KEY idx_ratings_deck (deck_id),
  KEY idx_ratings_user (user_id),
  CONSTRAINT ck_ratings_stars CHECK (stars BETWEEN 1 AND 5),
  CONSTRAINT fk_ratings_deck FOREIGN KEY (deck_id) REFERENCES decks (deck_id) ON DELETE CASCADE,
  CONSTRAINT fk_ratings_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/* =========================
   STUDY / ADAPTIVE / SPACED
   ========================= */
CREATE TABLE study_sessions (
  session_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  user_id         BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  deck_id         BIGINT UNSIGNED NOT NULL COMMENT 'FK → decks.deck_id',
  mode            ENUM('random','sequential','timed','adaptive','spaced') NOT NULL,
  cards_studied   INT UNSIGNED NOT NULL DEFAULT 0,
  correct_answers INT UNSIGNED NOT NULL DEFAULT 0,
  started_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ended_at        DATETIME NULL,
  PRIMARY KEY (session_id),
  KEY idx_sessions_user (user_id),
  KEY idx_sessions_deck (deck_id),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_sessions_deck FOREIGN KEY (deck_id) REFERENCES decks (deck_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE study_events (
  event_id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  session_id       BIGINT UNSIGNED NOT NULL COMMENT 'FK → study_sessions.session_id',
  card_id          BIGINT UNSIGNED NOT NULL COMMENT 'FK → cards.card_id',
  shown_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  answer_ms        INT UNSIGNED NULL,
  correct          TINYINT(1) NOT NULL,
  difficulty_shown TINYINT UNSIGNED NULL,
  PRIMARY KEY (event_id),
  KEY idx_events_session (session_id),
  KEY idx_events_card (card_id),
  CONSTRAINT fk_events_session FOREIGN KEY (session_id) REFERENCES study_sessions (session_id) ON DELETE CASCADE,
  CONSTRAINT fk_events_card    FOREIGN KEY (card_id)    REFERENCES cards (card_id)           ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE card_performance (
  performance_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  user_id          BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  card_id          BIGINT UNSIGNED NOT NULL COMMENT 'FK → cards.card_id',
  easiness         DECIMAL(3,2) NOT NULL DEFAULT 2.50,
  interval_days    INT UNSIGNED NOT NULL DEFAULT 0,
  repetitions      INT UNSIGNED NOT NULL DEFAULT 0,
  times_reviewed   INT UNSIGNED NOT NULL DEFAULT 0,
  times_correct    INT UNSIGNED NOT NULL DEFAULT 0,
  difficulty_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
  success_rate     DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  last_reviewed_at DATETIME NULL,
  next_due_at      DATETIME NULL,
  PRIMARY KEY (performance_id),
  UNIQUE KEY uq_perf_user_card (user_id, card_id),
  KEY idx_perf_user (user_id),
  KEY idx_perf_card (card_id),
  CONSTRAINT fk_perf_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_perf_card FOREIGN KEY (card_id) REFERENCES cards (card_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/* =========================
   STREAKS / REMINDERS / AI
   ========================= */
CREATE TABLE streaks (
  user_id          BIGINT UNSIGNED NOT NULL COMMENT 'PK, FK → users.user_id',
  current_streak   INT UNSIGNED NOT NULL DEFAULT 0,
  best_streak      INT UNSIGNED NOT NULL DEFAULT 0,
  total_study_days INT UNSIGNED NOT NULL DEFAULT 0,
  last_active_date DATE NULL,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_streaks_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE reminders (
  reminder_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  user_id      BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  title        VARCHAR(120) NOT NULL,
  reminder_time TIME NOT NULL,
  days_of_week VARCHAR(20) NOT NULL,
  is_active    TINYINT(1) NOT NULL DEFAULT 1,
  next_fire_at DATETIME NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (reminder_id),
  KEY idx_reminders_user (user_id),
  CONSTRAINT fk_reminders_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE ai_jobs (
  job_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  user_id            BIGINT UNSIGNED NOT NULL COMMENT 'FK → users.user_id',
  deck_id            BIGINT UNSIGNED NULL COMMENT 'FK → decks.deck_id',
  input_type         ENUM('topic','prompt','notes','file') NOT NULL,
  input_summary      VARCHAR(255) NULL,
  prompt_text        TEXT NULL,
  status             ENUM('queued','running','succeeded','failed') NOT NULL DEFAULT 'queued',
  result_count       INT UNSIGNED NULL,
  api_cost           DECIMAL(10,4) NULL,
  generation_time_ms INT UNSIGNED NULL,
  error_message      TEXT NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at        DATETIME NULL,
  PRIMARY KEY (job_id),
  KEY idx_aijobs_user (user_id),
  KEY idx_aijobs_deck (deck_id),
  CONSTRAINT fk_aijobs_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_aijobs_deck FOREIGN KEY (deck_id) REFERENCES decks (deck_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
