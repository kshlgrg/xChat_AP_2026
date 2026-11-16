-- =====================================================================
-- xChat Messaging Platform - Seed Data Population
-- Schema: xchat
-- Author: Kushal Garg (kshlgrg) · Enrollment No.: 2501010241
-- Course: Advanced Programming (AP) / DBMS
-- =====================================================================

SET search_path TO xchat;

-- 1. Insert Users
INSERT INTO users (username, email, password_hash, display_name) VALUES
('kushal', 'kushal.garg@xchat.io', '$2b$12$e8YkY9U3z9QfG0...', 'Kushal Garg'),
('piyush', 'piyush.alagh@xchat.io', '$2b$12$K9jX20mP8L1vN5...', 'Piyush Alagh'),
('aujasya', 'aujasya.rajput@xchat.io', '$2b$12$W7tR81xQ4N2mB6...', 'Aujasya Rajput'),
('aryan', 'aryan.damara@xchat.io', '$2b$12$M4pQ52yR7K9jL0...', 'Aryan Damara'),
('satyaki', 'satyaki.das@university.edu', '$2b$12$L8vN19mK3J5pQ2...', 'Prof. Satyaki Das');

-- 2. Insert User Presence
INSERT INTO user_presence (user_id, status, custom_status_text) VALUES
(1, 'ONLINE', 'Architecting DBMS at scale'),
(2, 'ONLINE', 'Leading sprint planning'),
(3, 'AWAY', 'Testing benchmark harness'),
(4, 'BUSY', 'Compiling code review'),
(5, 'OFFLINE', 'Reviewing project submissions');

-- 3. Insert Workspaces
INSERT INTO workspaces (name, slug, owner_id) VALUES
('DE & AP Capstone 2026', 'de-ap-capstone', 1),
('Open Source Engineering', 'oss-engineering', 2);

-- 4. Insert Workspace Members
INSERT INTO workspace_members (workspace_id, user_id, role) VALUES
(1, 1, 'OWNER'),
(1, 2, 'ADMIN'),
(1, 3, 'MEMBER'),
(1, 4, 'MEMBER'),
(1, 5, 'GUEST'),
(2, 2, 'OWNER'),
(2, 1, 'ADMIN');

-- 5. Insert Channels
INSERT INTO channels (workspace_id, name, topic, is_private, created_by) VALUES
(1, 'general', 'General workspace announcements and discussions', false, 1),
(1, 'database-performance', 'PostgreSQL indexing, EXPLAIN, and partitioning', false, 1),
(1, 'ap-architecture', 'Clean architecture, BCNF normalization, and tests', false, 2),
(1, 'core-team-private', 'Confidential team sync', true, 1);

-- 6. Insert Channel Members
INSERT INTO channel_members (channel_id, user_id, role, notifications_enabled) VALUES
(1, 1, 'ADMIN', true),
(1, 2, 'MEMBER', true),
(1, 3, 'MEMBER', true),
(1, 4, 'MEMBER', true),
(1, 5, 'MEMBER', false),
(2, 1, 'ADMIN', true),
(2, 2, 'MEMBER', true),
(2, 3, 'MEMBER', true),
(2, 4, 'MEMBER', true),
(3, 1, 'MEMBER', true),
(3, 2, 'ADMIN', true),
(4, 1, 'ADMIN', true),
(4, 2, 'MEMBER', true);

-- 7. Insert Direct Conversations (user1_id < user2_id enforced)
INSERT INTO direct_conversations (user1_id, user2_id) VALUES
(1, 2),
(1, 3),
(1, 4),
(1, 5);

-- 8. Insert Messages
INSERT INTO messages (channel_id, sender_id, content, message_type, is_pinned) VALUES
(1, 1, 'Welcome everyone to the xChat collaboration workspace!', 'TEXT', true),
(1, 2, 'Excited to test out the real-time chat platform!', 'TEXT', false),
(2, 1, 'We have achieved a 5.18x speedup on our BookMyShow database project.', 'TEXT', true),
(2, 3, 'All 30 queries are under SLA targets, and R19 went from 1510ms down to 0.64ms.', 'TEXT', false),
(2, 4, 'Partitioning on booking_seats with HASH(show_id) keeps the composite PK intact.', 'TEXT', false);

-- Insert Threaded Reply
INSERT INTO messages (channel_id, sender_id, parent_message_id, content, message_type) VALUES
(2, 2, 3, 'That is fantastic! The EXPLAIN BUFFERS outputs show zero disk reads.', 'TEXT');

-- Insert Direct Message
INSERT INTO messages (conversation_id, sender_id, content, message_type) VALUES
(1, 1, 'Hey Piyush, let us review the CP4 and CP5 deliverables before submission.', 'TEXT'),
(1, 2, 'Sounds great Kushal, everything is aligned with the evaluation matrix.', 'TEXT');

-- 9. Insert Attachments
INSERT INTO attachments (message_id, file_name, file_url, file_size_bytes, mime_type) VALUES
(3, 'benchmark_summary.pdf', 'https://cdn.xchat.io/files/benchmark_summary.pdf', 1048576, 'application/pdf');

-- 10. Insert Reactions
INSERT INTO reactions (message_id, user_id, emoji_code) VALUES
(1, 2, 'wave'),
(1, 3, 'thumbs_up'),
(3, 2, 'rocket'),
(3, 3, 'fire'),
(3, 4, '100');

\echo '==> xChat Seed Data Successfully Loaded!'
