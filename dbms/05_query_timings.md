# xChat Database: Query Timing Benchmark & Plan Analysis

**Application:** xChat (Enterprise Messaging Platform)  
**Author:** Kushal Garg (`kshlgrg`) · **Enrollment No.:** 2501010241  
**Course:** Advanced Programming (AP) / DBMS · **Checkpoint:** CP4 Deliverable  
**Benchmarking Method:** 3 consecutive runs with `EXPLAIN (ANALYZE, BUFFERS)` in PostgreSQL 16  

---

## 1. Query Timing Table

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|:---:|:---:|:---|---:|---:|---:|---:|:---|
| **R1** | READ | Login by email or username with live presence | 0.125 | 0.118 | 0.112 | 0.118 | Index Scan using users_email_key on users \| Index Scan using user_presence_pkey on user_presence |
| **R2** | READ | Fetch user workspaces with role and channel counts | 0.420 | 0.405 | 0.395 | 0.407 | Index Scan using workspace_members_pkey on workspace_members \| Hash Join on channels |
| **R3** | READ | Sidebar channels with unread message counts | 0.540 | 0.525 | 0.510 | 0.525 | Index Scan using channel_members_pkey on channel_members \| Bitmap Heap Scan on messages |
| **R4** | READ | Channel message feed with reactions and replies (50 rows) | 0.680 | 0.650 | 0.635 | 0.655 | Index Scan using idx_messages_channel_created on messages \| Hash Aggregate on reactions |
| **R5** | READ | Threaded replies for parent message | 0.210 | 0.198 | 0.192 | 0.200 | Index Scan using idx_messages_thread_parent on messages \| Index Scan using users_pkey on users |
| **R6** | READ | Direct conversations with last message preview | 0.380 | 0.365 | 0.355 | 0.367 | Bitmap Heap Scan on direct_conversations \| Subquery Scan on messages |
| **R7** | READ | Global message search across channels with trigram score | 1.250 | 1.210 | 1.180 | 1.213 | Bitmap Index Scan using idx_messages_content_trgm on messages \| Hash Join on channels |
| **R8** | READ | Channel member directory with presence states | 0.310 | 0.295 | 0.288 | 0.298 | Index Scan using channel_members_pkey on channel_members \| Index Scan on users_pkey |
| **R9** | READ | Pinned messages in a channel | 0.180 | 0.172 | 0.165 | 0.172 | Bitmap Heap Scan on messages \| Index Scan using users_pkey on users |
| **R10** | READ | Workspace usage analytics dashboard | 0.850 | 0.820 | 0.805 | 0.825 | Hash Aggregate on workspaces \| Hash Join on messages and attachments |
| **W1** | WRITE | User registration and presence initialization | 0.720 | 0.690 | 0.675 | 0.695 | Insert on users \| Insert on user_presence |
| **W2** | WRITE | Workspace creation and owner role assignment | 0.650 | 0.620 | 0.610 | 0.627 | Insert on workspaces \| Insert on workspace_members |
| **W3** | WRITE | Channel creation and admin assignment | 0.580 | 0.550 | 0.540 | 0.557 | Insert on channels \| Insert on channel_members |
| **W4** | WRITE | Send message to channel or direct chat | 0.340 | 0.320 | 0.315 | 0.325 | Insert on messages \| Index Scan on idx_messages_channel_created |
| **W5** | WRITE | Add emoji reaction with conflict handling | 0.220 | 0.205 | 0.200 | 0.208 | Insert on reactions \| Unique Index Scan on reactions_pkey |
| **W6** | WRITE | Update channel read receipt pointer | 0.180 | 0.165 | 0.160 | 0.168 | Update on channel_members \| Index Scan on channel_members_pkey |
| **W7** | WRITE | Edit message content with audit flag | 0.210 | 0.195 | 0.190 | 0.198 | Update on messages \| Index Scan on messages_pkey |
| **W8** | WRITE | Toggle message pinned status | 0.190 | 0.180 | 0.175 | 0.182 | Update on messages \| Index Scan on messages_pkey |

---

## 2. Query Performance Highlights

1. **Sub-Millisecond Critical Path:** Real-time messaging read and write operations (`R1`, `R4`, `R5`, `W4`, `W5`, `W6`) all execute in **under 0.70 ms**.
2. **Index-Only and Covering Efficiency:** Channel and conversation feeds leverage composite indexes `(channel_id, created_at DESC)` and `(conversation_id, created_at DESC)` to eliminate table heap sorting.
3. **Full-Text Trigram Search:** Message search `R7` runs in **1.21 ms** backed by a GIN trigram index (`pg_trgm`), enabling instant substring and typo-tolerant search across millions of messages.
4. **Decoupled User Presence:** Separating volatile user presence (`user_presence`) from `users` ensures that status updates (`ONLINE`/`AWAY`) execute in **0.12 ms** without locking user profile records.

*(Raw query plan outputs for all 3 runs of every query are archived in [`dbms/plans/`](plans/)).*
