-- =====================================================================
-- xChat Messaging Platform - Relational Integrity Test Suite
-- Schema: xchat
-- Author: Kushal Garg (kshlgrg)
-- =====================================================================

SET search_path TO xchat;

CREATE TEMP TABLE xchat_test_results (
    test_id      INT PRIMARY KEY,
    test_name    TEXT NOT NULL,
    status       TEXT NOT NULL CHECK (status IN ('PASS', 'FAIL')),
    details      TEXT NOT NULL
);

-- Test 1: Verify all 10 tables exist
INSERT INTO xchat_test_results (test_id, test_name, status, details)
SELECT 1, 'Table Existence Test (10 tables)',
       CASE WHEN count(*) = 10 THEN 'PASS' ELSE 'FAIL' END,
       format('Found %s of 10 expected tables in xchat schema', count(*))
FROM information_schema.tables 
WHERE table_schema = 'xchat' AND table_type = 'BASE TABLE';

-- Test 2: Canonical DM Symmetrical Ordering (user1_id < user2_id)
INSERT INTO xchat_test_results (test_id, test_name, status, details)
SELECT 2, 'Canonical Direct Message User Ordering Test',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       format('Found %s direct conversations violating user1_id < user2_id', count(*))
FROM direct_conversations
WHERE user1_id >= user2_id;

-- Test 3: Exclusive Message Destination (Channel OR Direct, never both or neither)
INSERT INTO xchat_test_results (test_id, test_name, status, details)
SELECT 3, 'Exclusive Message Destination Invariant',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       format('Found %s messages with invalid destination routing', count(*))
FROM messages
WHERE (channel_id IS NULL AND conversation_id IS NULL)
   OR (channel_id IS NOT NULL AND conversation_id IS NOT NULL);

-- Test 4: Threaded Parent Message Referential Integrity
INSERT INTO xchat_test_results (test_id, test_name, status, details)
SELECT 4, 'Thread Parent Message Integrity',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       format('Found %s reply messages with non-existent parent messages', count(*))
FROM messages m
LEFT JOIN messages p ON p.message_id = m.parent_message_id
WHERE m.parent_message_id IS NOT NULL AND p.message_id IS NULL;

-- Test 5: Reaction Uniqueness
INSERT INTO xchat_test_results (test_id, test_name, status, details)
SELECT 5, 'Duplicate Emoji Reaction Protection',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       format('Found %s duplicate emoji reaction records', count(*) - count(DISTINCT (message_id, user_id, emoji_code)))
FROM reactions;

SELECT test_id, test_name, status, details FROM xchat_test_results ORDER BY test_id;
