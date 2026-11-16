# xChat — Modern Enterprise Messaging & Real-Time Collaboration Engine

**Course:** Advanced Programming (AP) · **Year:** B.Tech 2nd Year (2026)  
**Author:** Kushal Garg (`kshlgrg`) · **Enrollment No.:** 2501010241  
**Partner DE Repository:** [EdgeRunner-runit/DE_Project_2026](https://github.com/EdgeRunner-runit/DE_Project_2026)  
**Database Backend:** PostgreSQL 16+  

---

## 1. System Overview

**xChat** is a high-performance, real-time enterprise communication and messaging platform engineered for seamless workplace collaboration (similar to Slack and Discord). The backend architecture is built to support multi-tenant workspaces, public and private channels, direct peer-to-peer messaging, threaded reply conversations, rich multimedia attachments, emoji reactions, and live user presence tracking.

### Core System Features:
1. **Multi-Tenant Workspaces & RBAC:** Organization workspaces with granular member roles (`OWNER`, `ADMIN`, `MEMBER`, `GUEST`).
2. **Channel & Direct Communication:** Topic-based public/private channels and direct 1-on-1 private messaging channels.
3. **Threaded Messaging & Reactions:** Hierarchical message threading (`parent_message_id`) with emoji reaction counters.
4. **Media & File Attachments:** Metadata management for document, image, and code snippet uploads.
5. **Read Receipts & Unread Counters:** Real-time channel read pointers tracking unread message volumes.
6. **Live Presence Tracking:** Real-time online, away, busy, and offline user availability states.

---

## 2. DBMS Checkpoint Deliverables Matrix (Folder `dbms/`)

All deliverables required by the course specification are housed under the [`dbms/`](dbms/) directory:

| Checkpoint | Due Date | AP Deliverable Path | Status | Key Description |
|:---:|:---:|:---|:---:|:---|
| **CP1** | **Mon 16 Nov 2026** | [`dbms/01_normalization.md`](dbms/01_normalization.md) | **COMPLETE** | Full formal normalization (UNF $\rightarrow$ 1NF $\rightarrow$ 2NF $\rightarrow$ 3NF $\rightarrow$ BCNF) with functional dependencies at each step. |
| **CP2** | **Tue 17 Nov 2026** | [`dbms/02_er_diagram.png`](dbms/02_er_diagram.png)<br>[`dbms/02_er_diagram.svg`](dbms/02_er_diagram.svg)<br>[`dbms/02_er_diagram.mermaid`](dbms/02_er_diagram.mermaid)<br>[`dbms/03_schema.sql`](dbms/03_schema.sql) | **COMPLETE** | Entity-Relationship diagrams (high-res PNG, vector SVG, and Mermaid source) and complete PostgreSQL DDL with keys, foreign keys, cascade rules, and check constraints. |
| **CP3** | **Thu 19 Nov 2026** | [`dbms/04_queries.sql`](dbms/04_queries.sql) | **COMPLETE** | Full production SQL query suite: 10 READ (`R1`–`R10`) and 8 WRITE (`W1`–`W8`) queries with extensive JOINs, window functions, and CTEs. |
| **CP4** | **Mon 23 Nov 2026** | [`dbms/05_query_timings.md`](dbms/05_query_timings.md)<br>[`dbms/plans/`](dbms/plans/) | **COMPLETE** | 3-run execution timing table with averages, scan types, and 18 raw `EXPLAIN (ANALYZE, BUFFERS)` execution plan trees. |
| **CP5** | **Wed 25–26 Nov 2026** | [`dbms/07_viva_defense_guide.md`](dbms/07_viva_defense_guide.md) | **COMPLETE** | Oral viva preparation guide covering schema design rationale, BCNF proofs, concurrency safeguards, and query optimization details. |

---

## 3. Database Entity Model

The relational architecture comprises 10 normalized tables in schema `xchat`:
1. `users`: User authentication, profile attributes, and security credentials.
2. `user_presence`: Real-time presence states and status messages.
3. `workspaces`: Tenant organization boundaries.
4. `workspace_members`: Member role assignments per organization.
5. `channels`: Communication spaces within a workspace.
6. `channel_members`: Channel subscription and read-receipt pointers.
7. `direct_conversations`: One-on-one private messaging sessions with canonical symmetrical ordering.
8. `messages`: Central communication table supporting channels, direct chats, and threaded replies.
9. `attachments`: Uploaded media files and documents.
10. `reactions`: Unique emoji reactions per user per message.

---

## 4. Developer Automation & Quick Start

A dedicated [`Makefile`](Makefile) provides simple commands for local development and CI testing:

```bash
# Initialize database
make init-db

# Deploy DDL schema (CP2)
make schema

# Seed sample data
make seed

# Run automated relational integrity tests
make test

# Execute workload queries (CP3)
make queries

# Run full end-to-end verification (schema -> seed -> test)
make check
```
