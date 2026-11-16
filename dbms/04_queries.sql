-- =====================================================================
-- xChat Messaging Platform - Application SQL Workload Queries
-- Schema: xchat
-- Author: Kushal Garg (kshlgrg) · Enrollment No.: 2501010241
-- Course: Advanced Programming (AP) / DBMS · Year: B.Tech 2nd Year
-- Deliverable: Checkpoint 3 (CP3) — Application Queries
--
-- STRUCTURE:
--   READ Queries:  R1 through R10 (10 read operations with extensive JOINs)
--   WRITE Queries: W1 through W8  (8 transactional write operations)
-- =====================================================================

SET search_path TO xchat;

-- =====================================================================
-- SECTION 1: READ QUERIES (R1 – R10)
-- =====================================================================

-- @R1
-- User Authentication: Login lookup by email or username with live presence state
-- READ
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.password_hash,
    u.display_name,
    u.avatar_url,
    coalesce(up.status, 'OFFLINE') AS presence_status,
    up.custom_status_text,
    u.last_seen_at
FROM users u
LEFT JOIN user_presence up ON up.user_id = u.user_id
WHERE u.email = 'kushal.garg@xchat.io' OR u.username = 'kushal';


-- @R2
-- Workspace Navigation: Fetch all workspaces a user belongs to with their roles
-- READ
SELECT 
    w.workspace_id,
    w.name AS workspace_name,
    w.slug,
    wm.role AS user_role,
    wm.joined_at,
    u_owner.display_name AS owner_name,
    count(DISTINCT c.channel_id) AS total_channels,
    count(DISTINCT wm2.user_id) AS total_members
FROM workspaces w
JOIN workspace_members wm ON wm.workspace_id = w.workspace_id
JOIN users u_owner ON u_owner.user_id = w.owner_id
LEFT JOIN channels c ON c.workspace_id = w.workspace_id
LEFT JOIN workspace_members wm2 ON wm2.workspace_id = w.workspace_id
WHERE wm.user_id = 1
GROUP BY w.workspace_id, w.name, w.slug, wm.role, wm.joined_at, u_owner.display_name
ORDER BY w.name ASC;


-- @R3
-- Sidebar Channels: Fetch channels in a workspace with computed unread message count
-- READ
SELECT 
    c.channel_id,
    c.name AS channel_name,
    c.topic,
    c.is_private,
    cm.role AS membership_role,
    cm.notifications_enabled,
    count(m.message_id) FILTER (WHERE m.message_id > coalesce(cm.last_read_message_id, 0)) AS unread_count,
    max(m.created_at) AS last_activity_at
FROM channels c
JOIN channel_members cm ON cm.channel_id = c.channel_id AND cm.user_id = 1
LEFT JOIN messages m ON m.channel_id = c.channel_id
WHERE c.workspace_id = 1
GROUP BY c.channel_id, c.name, c.topic, c.is_private, cm.role, cm.notifications_enabled, cm.last_read_message_id
ORDER BY c.is_private ASC, c.name ASC;


-- @R4
-- Message Feed: Paginated channel messages with author profile, reply count, and aggregated reactions
-- READ
SELECT 
    m.message_id,
    m.content,
    m.message_type,
    m.is_edited,
    m.is_pinned,
    m.created_at,
    u.user_id AS sender_id,
    u.username AS sender_username,
    u.display_name AS sender_name,
    u.avatar_url AS sender_avatar,
    coalesce(r.reaction_summary, '{}'::json) AS reactions,
    coalesce(att.attachment_count, 0) AS total_attachments,
    coalesce(replies.reply_count, 0) AS reply_count
FROM messages m
JOIN users u ON u.user_id = m.sender_id
LEFT JOIN (
    SELECT message_id, json_object_agg(emoji_code, reaction_count) AS reaction_summary
    FROM (
        SELECT message_id, emoji_code, count(*) AS reaction_count
        FROM reactions
        GROUP BY message_id, emoji_code
    ) rx
    GROUP BY message_id
) r ON r.message_id = m.message_id
LEFT JOIN (
    SELECT message_id, count(*) AS attachment_count
    FROM attachments
    GROUP BY message_id
) att ON att.message_id = m.message_id
LEFT JOIN (
    SELECT parent_message_id, count(*) AS reply_count
    FROM messages
    WHERE parent_message_id IS NOT NULL
    GROUP BY parent_message_id
) replies ON replies.parent_message_id = m.message_id
WHERE m.channel_id = 1 
  AND m.parent_message_id IS NULL
ORDER BY m.created_at DESC
LIMIT 50;


-- @R5
-- Thread Discussion: Load threaded replies for a parent message
-- READ
SELECT 
    m.message_id,
    m.parent_message_id,
    m.content,
    m.message_type,
    m.created_at,
    u.user_id AS sender_id,
    u.display_name AS sender_name,
    u.avatar_url AS sender_avatar,
    coalesce(a.file_url, '') AS attachment_url,
    coalesce(a.file_name, '') AS attachment_name
FROM messages m
JOIN users u ON u.user_id = m.sender_id
LEFT JOIN attachments a ON a.message_id = m.message_id
WHERE m.parent_message_id = 101
ORDER BY m.created_at ASC;


-- @R6
-- Direct Messaging List: 1-on-1 conversations with other user profile and latest message preview
-- READ
SELECT 
    dc.conversation_id,
    other_user.user_id AS contact_id,
    other_user.display_name AS contact_name,
    other_user.avatar_url AS contact_avatar,
    coalesce(up.status, 'OFFLINE') AS contact_presence,
    last_msg.content AS last_message_content,
    last_msg.created_at AS last_message_time
FROM direct_conversations dc
JOIN users other_user ON other_user.user_id = CASE 
    WHEN dc.user1_id = 1 THEN dc.user2_id 
    ELSE dc.user1_id 
END
LEFT JOIN user_presence up ON up.user_id = other_user.user_id
LEFT JOIN LATERAL (
    SELECT content, created_at
    FROM messages
    WHERE conversation_id = dc.conversation_id
    ORDER BY created_at DESC
    LIMIT 1
) last_msg ON true
WHERE dc.user1_id = 1 OR dc.user2_id = 1
ORDER BY last_msg.created_at DESC NULLS LAST;


-- @R7
-- Global Message Search: Trigram similarity search across messages in user's channels
-- READ
SELECT 
    m.message_id,
    c.name AS channel_name,
    w.name AS workspace_name,
    u.display_name AS sender_name,
    m.content,
    m.created_at,
    similarity(m.content, 'database migration') AS rank_score
FROM messages m
JOIN channels c ON c.channel_id = m.channel_id
JOIN workspaces w ON w.workspace_id = c.workspace_id
JOIN users u ON u.user_id = m.sender_id
JOIN channel_members cm ON cm.channel_id = c.channel_id AND cm.user_id = 1
WHERE m.content ILIKE '%database migration%'
ORDER BY rank_score DESC, m.created_at DESC
LIMIT 20;


-- @R8
-- Channel Member Directory: Participants with roles and real-time presence
-- READ
SELECT 
    u.user_id,
    u.username,
    u.display_name,
    u.avatar_url,
    cm.role AS channel_role,
    wm.role AS workspace_role,
    coalesce(up.status, 'OFFLINE') AS presence_status,
    up.custom_status_text,
    cm.joined_at
FROM channel_members cm
JOIN users u ON u.user_id = cm.user_id
JOIN channels c ON c.channel_id = cm.channel_id
JOIN workspace_members wm ON wm.workspace_id = c.workspace_id AND wm.user_id = u.user_id
LEFT JOIN user_presence up ON up.user_id = u.user_id
WHERE cm.channel_id = 1
ORDER BY 
    CASE cm.role WHEN 'ADMIN' THEN 1 ELSE 2 END,
    u.display_name ASC;


-- @R9
-- Pinned Messages: Retrieve pinned messages in a channel
-- READ
SELECT 
    m.message_id,
    m.content,
    m.created_at,
    u.display_name AS pinned_by_author,
    count(a.attachment_id) AS attachment_count
FROM messages m
JOIN users u ON u.user_id = m.sender_id
LEFT JOIN attachments a ON a.message_id = m.message_id
WHERE m.channel_id = 1 AND m.is_pinned = true
GROUP BY m.message_id, m.content, m.created_at, u.display_name
ORDER BY m.created_at DESC;


-- @R10
-- Workspace Analytics Dashboard: Aggregated activity metrics per workspace
-- READ
SELECT 
    w.workspace_id,
    w.name,
    count(DISTINCT wm.user_id) AS total_users,
    count(DISTINCT c.channel_id) AS total_channels,
    count(m.message_id) AS total_messages,
    coalesce(sum(att.file_size_bytes), 0) AS total_storage_bytes
FROM workspaces w
LEFT JOIN workspace_members wm ON wm.workspace_id = w.workspace_id
LEFT JOIN channels c ON c.workspace_id = w.workspace_id
LEFT JOIN messages m ON m.channel_id = c.channel_id
LEFT JOIN attachments att ON att.message_id = m.message_id
WHERE w.workspace_id = 1
GROUP BY w.workspace_id, w.name;


-- =====================================================================
-- SECTION 2: WRITE QUERIES (W1 – W8)
-- =====================================================================

-- @W1
-- User Registration: Insert new user and initialize presence state
-- WRITE
WITH new_user AS (
    INSERT INTO users (username, email, password_hash, display_name)
    VALUES ('aryan_d', 'aryan@xchat.io', '$2b$12$e8YkY9U3z9QfG0...', 'Aryan Damara')
    RETURNING user_id
)
INSERT INTO user_presence (user_id, status, custom_status_text)
SELECT user_id, 'ONLINE', 'Ready to collaborate' FROM new_user;


-- @W2
-- Workspace Creation: Create workspace and auto-assign owner role
-- WRITE
WITH new_ws AS (
    INSERT INTO workspaces (name, slug, owner_id)
    VALUES ('Engineering Team', 'engineering-team', 1)
    RETURNING workspace_id, owner_id
)
INSERT INTO workspace_members (workspace_id, user_id, role)
SELECT workspace_id, owner_id, 'OWNER' FROM new_ws;


-- @W3
-- Channel Creation: Create public channel and auto-subscribe creator
-- WRITE
WITH new_ch AS (
    INSERT INTO channels (workspace_id, name, topic, is_private, created_by)
    VALUES (1, 'database-scaling', 'PostgreSQL partitioning and performance discussion', false, 1)
    RETURNING channel_id, created_by
)
INSERT INTO channel_members (channel_id, user_id, role)
SELECT channel_id, created_by, 'ADMIN' FROM new_ch;


-- @W4
-- Post Message: Send a new message into a channel
-- WRITE
INSERT INTO messages (channel_id, sender_id, content, message_type)
VALUES (1, 1, 'Partitioning on booking_seats by HASH (show_id) maintains composite PK constraint perfectly!', 'TEXT');


-- @W5
-- Add Emoji Reaction: Add reaction with duplicate conflict avoidance
-- WRITE
INSERT INTO reactions (message_id, user_id, emoji_code)
VALUES (1, 2, 'thumbs_up')
ON CONFLICT (message_id, user_id, emoji_code) DO NOTHING;


-- @W6
-- Update Read Pointer: Advance user last_read_message_id
-- WRITE
UPDATE channel_members
SET last_read_message_id = 150
WHERE channel_id = 1 AND user_id = 1;


-- @W7
-- Edit Message: Update message content with audit flag
-- WRITE
UPDATE messages
SET content = 'Partitioning on booking_seats by HASH (show_id) with 4 partitions delivers sub-millisecond lookups.',
    is_edited = true,
    updated_at = now()
WHERE message_id = 1 AND sender_id = 1;


-- @W8
-- Pin Message: Toggle pinned status in channel
-- WRITE
UPDATE messages
SET is_pinned = true
WHERE message_id = 1 AND channel_id = 1;
