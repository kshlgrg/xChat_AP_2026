# xChat Database: Normalization & Schema Peer Review

**Reviewer:** Aujasya Rajput (`Aujasyarajput18`) · **Enrollment No.:** 2501010564  
**Author:** Kushal Garg (`kshlgrg`) · **Enrollment No.:** 2501010241  
**Team:** T0132 · **Course:** AP / DBMS 2026  
**Status:** Approved with Notes  

---

## 1. Normalization Review (CP1)

* **1NF Compliance:** Verified that repeating groups (`workspace_members`, `channel_members`, `attachments`, `reactions`) have been fully unnested into independent relations with atomic types.
* **2NF Compliance:** Composite keys in junction tables (`workspace_members`, `channel_members`, `reactions`) have zero partial functional dependencies. Every non-prime attribute is fully dependent on the complete candidate key.
* **3NF Compliance:** In `workspaces`, owner metadata was decoupled, eliminating transitive dependencies (`workspace_id -> owner_id -> owner_email`).
* **BCNF Assessment:** For every functional dependency $X \rightarrow Y$, the determinant $X$ is a superkey. The decoupling of `user_presence` from `users` ensures that volatile heartbeat updates do not violate normal forms or create lock contention.

---

## 2. Relational Integrity & Constraint Review (CP2)

1. **Direct Conversation Symmetrical Invariant:**
   The check constraint `CONSTRAINT chk_canonical_dm_order CHECK (user1_id < user2_id)` combined with `UNIQUE (user1_id, user2_id)` correctly prevents duplicate inverse pairs `(A, B)` and `(B, A)`.
2. **Message Destination XOR Routing:**
   The table check constraint enforces that a message belongs either to a channel or to a direct conversation, avoiding orphan records and dual-routing bugs.
3. **Foreign Key Deletion Rules:**
   `ON DELETE CASCADE` is safely applied to transient entities (presence, channel subscriptions, reactions), while core security audit logs preserve author references.
