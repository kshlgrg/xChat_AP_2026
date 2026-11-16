-- =====================================================================
-- xChat Messaging Platform - Relational Database Schema DDL
-- Schema: xchat
-- Author: Kushal Garg (kshlgrg) · Enrollment No.: 2501010241
-- Course: Advanced Programming (AP) / DBMS · Year: B.Tech 2nd Year
-- Target: PostgreSQL 15+ (Production: PostgreSQL 16)
-- Deliverable: Checkpoint 2 (CP2) — Schema DDL
-- =====================================================================

-- Clean setup
DROP SCHEMA IF EXISTS xchat CASCADE;
CREATE SCHEMA xchat;
SET search_path TO xchat;

-- Enable trigram extension for fast message and user fuzzy searching
CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- =====================================================================
-- TABLE 1: users
-- Core user identity, authentication credentials, and account profiles.
-- =====================================================================
CREATE TABLE users (
    user_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username       VARCHAR(50) NOT NULL UNIQUE,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    display_name   VARCHAR(100) NOT NULL,
    avatar_url     TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_username_format CHECK (username ~ '^[a-zA-Z0-9._-]{3,50}$'),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);


-- =====================================================================
-- TABLE 2: user_presence
-- 1:1 decoupled live availability status to isolate high-churn writes.
-- =====================================================================
CREATE TABLE user_presence (
    user_id            INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    status             VARCHAR(20) NOT NULL DEFAULT 'OFFLINE',
    custom_status_text VARCHAR(150),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_presence_status CHECK (status IN ('ONLINE', 'AWAY', 'BUSY', 'OFFLINE'))
);


-- =====================================================================
-- TABLE 3: workspaces
-- Organization tenant boundaries (similar to Slack workspaces).
-- =====================================================================
CREATE TABLE workspaces (
    workspace_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    slug          VARCHAR(60) NOT NULL UNIQUE,
    owner_id      INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_workspace_slug CHECK (slug ~ '^[a-z0-9-]+$')
);


-- =====================================================================
-- TABLE 4: workspace_members
-- Multi-tenant membership and organization-level role assignment.
-- =====================================================================
CREATE TABLE workspace_members (
    workspace_id  INT NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
    user_id       INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role          VARCHAR(20) NOT NULL DEFAULT 'MEMBER',
    joined_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id),
    CONSTRAINT chk_workspace_role CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER', 'GUEST'))
);


-- =====================================================================
-- TABLE 5: channels
-- Public and private communication spaces within a workspace.
-- =====================================================================
CREATE TABLE channels (
    channel_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workspace_id  INT NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
    name          VARCHAR(80) NOT NULL,
    topic         TEXT,
    is_private    BOOLEAN NOT NULL DEFAULT false,
    created_by    INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_channel_name CHECK (name ~ '^[a-z0-9-_]{2,80}$'),
    CONSTRAINT uq_workspace_channel_name UNIQUE (workspace_id, name)
);


-- =====================================================================
-- TABLE 6: channel_members
-- User subscriptions to channels with unread pointer tracking.
-- =====================================================================
CREATE TABLE channel_members (
    channel_id             INT NOT NULL REFERENCES channels(channel_id) ON DELETE CASCADE,
    user_id                INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role                   VARCHAR(20) NOT NULL DEFAULT 'MEMBER',
    joined_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_read_message_id   INT,
    notifications_enabled  BOOLEAN NOT NULL DEFAULT true,
    PRIMARY KEY (channel_id, user_id),
    CONSTRAINT chk_channel_role CHECK (role IN ('ADMIN', 'MEMBER'))
);


-- =====================================================================
-- TABLE 7: direct_conversations
-- 1-on-1 private messaging channels between two users.
-- Canonical check (user1_id < user2_id) ensures symmetrical uniqueness.
-- =====================================================================
CREATE TABLE direct_conversations (
    conversation_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user1_id         INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    user2_id         INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_canonical_users CHECK (user1_id < user2_id),
    CONSTRAINT uq_direct_participants UNIQUE (user1_id, user2_id)
);


-- =====================================================================
-- TABLE 8: messages
-- Central communication message entity.
-- Supports channels, direct chats, and threaded discussions.
-- =====================================================================
CREATE TABLE messages (
    message_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel_id         INT REFERENCES channels(channel_id) ON DELETE CASCADE,
    conversation_id    INT REFERENCES direct_conversations(conversation_id) ON DELETE CASCADE,
    sender_id          INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    parent_message_id  INT REFERENCES messages(message_id) ON DELETE CASCADE,
    content            TEXT NOT NULL,
    message_type       VARCHAR(20) NOT NULL DEFAULT 'TEXT',
    is_edited          BOOLEAN NOT NULL DEFAULT false,
    is_pinned          BOOLEAN NOT NULL DEFAULT false,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_message_destination CHECK (
        (channel_id IS NOT NULL AND conversation_id IS NULL) OR
        (channel_id IS NULL AND conversation_id IS NOT NULL)
    ),
    CONSTRAINT chk_message_type CHECK (
        message_type IN ('TEXT', 'IMAGE', 'FILE', 'CODE', 'SYSTEM')
    )
);

-- Foreign key link for channel_members read pointer
ALTER TABLE channel_members 
    ADD CONSTRAINT fk_channel_members_last_read 
    FOREIGN KEY (last_read_message_id) REFERENCES messages(message_id) ON DELETE SET NULL;


-- =====================================================================
-- TABLE 9: attachments
-- Uploaded media files, PDFs, images, and binary attachments.
-- =====================================================================
CREATE TABLE attachments (
    attachment_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    message_id       INT NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
    file_name        VARCHAR(255) NOT NULL,
    file_url         TEXT NOT NULL,
    file_size_bytes  BIGINT NOT NULL CHECK (file_size_bytes > 0),
    mime_type        VARCHAR(100) NOT NULL,
    uploaded_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =====================================================================
-- TABLE 10: reactions
-- User emoji reactions on messages (Slack-style reactions).
-- Composite PK prevents a user reacting with the same emoji twice.
-- =====================================================================
CREATE TABLE reactions (
    message_id   INT NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
    user_id      INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    emoji_code   VARCHAR(50) NOT NULL,
    reacted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, user_id, emoji_code)
);


-- =====================================================================
-- PRODUCTION PERFORMANCE INDEXES
-- =====================================================================

-- Channel message chronologically ordered retrieval
CREATE INDEX idx_messages_channel_created 
ON messages (channel_id, created_at DESC) 
WHERE channel_id IS NOT NULL;

-- Direct conversation message retrieval
CREATE INDEX idx_messages_conversation_created 
ON messages (conversation_id, created_at DESC) 
WHERE conversation_id IS NOT NULL;

-- Threaded reply tree lookup
CREATE INDEX idx_messages_thread_parent 
ON messages (parent_message_id, created_at ASC) 
WHERE parent_message_id IS NOT NULL;

-- Fast full-text message content search
CREATE INDEX idx_messages_content_trgm 
ON messages USING gin (content gin_trgm_ops);

-- User foreign key lookups on memberships
CREATE INDEX idx_workspace_members_user ON workspace_members (user_id);
CREATE INDEX idx_channel_members_user ON channel_members (user_id);
CREATE INDEX idx_attachments_message ON attachments (message_id);
CREATE INDEX idx_reactions_message ON reactions (message_id);
