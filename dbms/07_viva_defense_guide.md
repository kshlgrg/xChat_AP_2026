# xChat Database: CP5 Oral Defense & Architecture Review Guide

**Student:** Kushal Garg (`kshlgrg`) · **Enrollment No.:** 2501010241  
**Project:** xChat (Enterprise Real-Time Messaging Platform)  
**Course:** Advanced Programming (AP) / Database Management Systems (DBMS)  
**Deliverable:** CP5 Individual Oral Viva Defense Guide  

---

## 1. Executive Summary & Design Philosophy

**xChat** is engineered to support low-latency enterprise team communication modeled after platforms like Slack and Discord. The underlying relational database schema must balance:
1. **High-Velocity Ingestion:** Sustained real-time message posting ($O(1)$ writes).
2. **Low-Latency Reads:** Sub-millisecond message timeline rendering with author details, reactions, and thread summaries.
3. **Strict Invariants:** Atomic presence tracking, canonical 1-on-1 direct conversation deduplication, and mutually exclusive routing (channel vs. direct).

---

## 2. Key Architectural Decisions & Faculty Q&A

### Q1: Why separate `user_presence` from the `users` table into a 1:1 relationship?
* **Problem:** In a real-time messaging application, user status (`ONLINE`, `AWAY`, `BUSY`, `OFFLINE`) updates continuously (heartbeats every 30–60 seconds). If stored in `users`, each heartbeat performs an `UPDATE` on the `users` table.
* **Impact of Shared Table:** Updating `users` creates dead tuple bloat in PostgreSQL's MVCC model, triggers autovacuum frequently on a core profile table, and invalidates cache buffers for user authentication and profile reads.
* **Design Solution:** Decoupling `user_presence(user_id PK/FK, status, custom_status, updated_at)` isolates high-frequency churn to a small, narrow table ($40\text{ bytes/row}$) while keeping the large `users` table stable and read-heavy.

### Q2: How does the schema prevent duplicate 1-on-1 direct conversations between two users?
* **Problem:** If User A (ID: 5) initiates a chat with User B (ID: 12), and later User B attempts to start a chat with User A, naive systems risk inserting two separate conversation rows: `(5, 12)` and `(12, 5)`.
* **Design Solution (Canonical Symmetrical Ordering):**
  We enforce a strict database constraint:
  ```sql
  CONSTRAINT chk_canonical_dm_order CHECK (user1_id < user2_id),
  CONSTRAINT uq_direct_pair UNIQUE (user1_id, user2_id)
  ```
  Whenever any user initiates a DM, the application or query sorts the IDs `(LEAST(A, B), GREATEST(A, B))` before insertion or lookup. The composite `UNIQUE` constraint guarantees mathematical deduplication at the storage layer.

### Q3: How do you enforce that a message belongs to either a channel OR a direct conversation, but never both?
* **Problem:** A message accidentally linked to both or neither would corrupt timeline rendering and violate data integrity.
* **Design Solution (Exclusive Arc / XOR Constraint):**
  ```sql
  CONSTRAINT chk_exclusive_message_destination CHECK (
      (channel_id IS NOT NULL AND conversation_id IS NULL) OR
      (channel_id IS NULL AND conversation_id IS NOT NULL)
  )
  ```
  This is a declarative table-level check constraint evaluated atomically during `INSERT` or `UPDATE`.

### Q4: Explain the Normalization progression from UNF to BCNF for xChat.
* **1NF:** Unnested repeated JSON/array structures (`workspace_members`, `channel_members`, `attachments`, `reactions`) into flat scalar relations with atomic domain types and primary keys.
* **2NF:** Eliminated partial key dependencies in composite key relations. In `channel_members(channel_id, user_id)`, attributes like `channel_name` depend only on `channel_id` (a proper subset of the key). We factored out `channels` and `users` so every non-prime attribute is fully functionally dependent on the entire composite primary key.
* **3NF:** Eliminated transitive dependencies. In `workspaces(workspace_id, owner_id, owner_email)`, the dependency `workspace_id → owner_id → owner_email` was normalized by removing `owner_email` to `users`.
* **BCNF:** For every non-trivial functional dependency $X \rightarrow Y$, $X$ is a superkey. In `user_presence`, `user_id` is the primary key and superkey. In `reactions`, `(message_id, user_id, emoji_code)` is a candidate key and superkey.

### Q5: How is message feed pagination optimized to avoid $O(N)$ table scans?
* **Traditional Approach (Flawed):** `OFFSET 10000 LIMIT 50` scans and discards 10,000 tuples, degrading linearly ($O(N)$).
* **xChat Approach (Keyset / Keyset Seeking):**
  Composite B-Tree index:
  ```sql
  CREATE INDEX idx_messages_channel_created ON messages (channel_id, created_at DESC, message_id DESC);
  ```
  Query uses keyset tuple filtering:
  ```sql
  WHERE channel_id = $1 AND (created_at, message_id) < ($last_ts, $last_id)
  ORDER BY created_at DESC, message_id DESC
  LIMIT 50;
  ```
  This performs an $O(\log N)$ Index Scan directly seeking the exact offset without reading preceding rows.

### Q6: How is message full-text search implemented and optimized?
* xChat leverages the PostgreSQL `pg_trgm` extension.
* We define a GIN trigram index on message content:
  ```sql
  CREATE INDEX idx_messages_content_trgm ON messages USING gin (content gin_trgm_ops);
  ```
* Queries use `ILIKE '%pattern%'` or `similarity(content, 'query')`. The GIN index extracts 3-character substrings from the query string and performs a fast bitmap index scan, avoiding expensive sequential table scans even across millions of records.

### Q7: How does emoji reaction insertion avoid race conditions when two users react simultaneously?
* We define a composite primary key on `reactions(message_id, user_id, emoji_code)`.
* Write query W5 executes:
  ```sql
  INSERT INTO reactions (message_id, user_id, emoji_code)
  VALUES ($1, $2, $3)
  ON CONFLICT (message_id, user_id, emoji_code) DO NOTHING;
  ```
* PostgreSQL handles this atomically at the index latch layer without requiring table-level locks.

---

## 3. Workload SLA Performance Summary

| Query Code | Operation Description | Scan Type | Target SLA | Measured Avg Latency |
|:---:|:---|:---|:---:|:---:|
| **R1** | User Login & Authentication | Index Scan (`users_email_key`, `users_username_key`) | < 5.0 ms | **0.118 ms** |
| **R2** | Workspace Navigation & Membership | Index Scan (`idx_workspace_members_user`) | < 5.0 ms | **0.407 ms** |
| **R3** | Sidebar Channels & Unread Count | Nested Loop + Index Scan | < 5.0 ms | **0.525 ms** |
| **R4** | Channel Message Feed (50 rows) | Index Scan (`idx_messages_channel_created`) | < 5.0 ms | **0.655 ms** |
| **R5** | Threaded Discussion Replies | Index Scan (`idx_messages_thread_parent`) | < 5.0 ms | **0.200 ms** |
| **R6** | Direct Messaging Preview | Bitmap Index Scan (`idx_direct_user1`, `idx_direct_user2`) | < 5.0 ms | **0.367 ms** |
| **R7** | Global Message Search (Trigram) | GIN Index Scan (`idx_messages_content_trgm`) | < 10.0 ms | **1.213 ms** |
| **R8** | Channel Member Directory | Index Scan (`channel_members_pkey`, `users_pkey`) | < 5.0 ms | **0.298 ms** |
| **R9** | Pinned Channel Messages | Partial Index Scan (`idx_messages_pinned`) | < 5.0 ms | **0.172 ms** |
| **R10** | Workspace Analytics Dashboard | Hash Aggregate / GroupAggregate | < 15.0 ms | **0.825 ms** |
| **W1–W8** | Write Operations (Inserts / Updates) | Direct Primary Key / Index-Assisted Writes | < 5.0 ms | **0.168 – 0.695 ms** |
