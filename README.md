
# QueryOptBench

**50 Complex Real-World PostgreSQL Query Optimization Scenarios**

> Yashraj Singh | Roll No. 2328058 | 
> 2026 | KIIT University

---

## Overview

QueryOptBench is a benchmark of 50 intentionally bad PostgreSQL queries covering 10 real-world application domains. Each scenario documents a specific anti-pattern, explains why it degrades performance, and serves as a basis for query optimization practice.

## Repository Structure


## Domains Covered

| Domain | Scenarios | Key Anti-Patterns |
|---|---|---|
| E-Commerce | #1 – #5 | Missing index, leading wildcard LIKE, correlated subquery, NOT IN, SELECT * |
| Social Media | #6 – #10 | N+1 queries, OFFSET pagination, LOWER() blocking index, unbounded array_agg |
| Healthcare | #11 – #15 | Unbounded json_agg, NOT IN subqueries, multiple round trips, EXTRACT blocking index |
| SaaS / Multi-tenant | #16 – #20 | Correlated subquery per row, Cartesian JOIN explosion, OFFSET on append-only table |
| Fintech | #21 – #25 | O(n²) self-join, TO_CHAR blocking index, four correlated subqueries, UNNEST in filter |
| EdTech | #26 – #30 | Correlated subquery, massive intermediate JOIN, O(n×m) pre-aggregation, NOT IN |
| Logistics | #31 – #35 | Unbounded json_agg, subquery in JOIN, CROSS JOIN cartesian, computed column sort |
| Content / Media | #36 – #40 | COUNT DISTINCT without pre-agg, correlated IN in aggregate, ILIKE on large text |
| HR / People Ops | #41 – #45 | Recursive CTE without depth limit, four subqueries per row, PII exposure |
| Real Estate / Booking | #46 – #50 | NOT IN availability check, TO_CHAR blocking index, 270 correlated subqueries |

## How to Use

### 1. Setup (Neon or any PostgreSQL 14+ instance)

```sql
-- Enable pg_trgm for full-text search indexes
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create all tables and indexes
\i schema.sql
```

### 2. Run a bad query

```sql
\i bad_queries.sql
```

### 3. Analyse performance

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <paste query here>;
```

## Anti-Pattern Reference

| Anti-Pattern | Queries | Fix |
|---|---|---|
| Missing index | #1, #9, #19 | `CREATE INDEX` on filter/join columns |
| Leading wildcard LIKE | #2, #8, #15, #39 | GIN index with `pg_trgm` or full-text search |
| Correlated subquery per row | #3, #6, #16, #18, #23, #25, #33, #38 | Replace with JOIN + GROUP BY or CTE |
| NOT IN subquery | #4, #12, #29, #46 | Replace with `LEFT JOIN ... IS NULL` or `NOT EXISTS` |
| SELECT * over-fetching | #5, #8, #11 | Select only required columns |
| OFFSET pagination | #7, #19, #21, #46 | Keyset (cursor) pagination |
| Function on indexed column | #12, #13, #14, #20, #22, #48 | Use range conditions instead of `DATE()`, `EXTRACT()`, `TO_CHAR()` |
| Cartesian JOIN explosion | #17, #34, #42, #46 | Pre-aggregate in subquery/CTE before joining |
| O(n²) self-join | #21 | Use `SUM() OVER()` window function |
| Unbounded recursive CTE | #41, #44 | Add `WHERE depth < N` depth limit |
| CROSS JOIN | #34, #49 | Filter before joining; use lateral joins |
| Multiple round trips | #13 | Batch into a single query with CTEs |

## Tech Stack

- **Database:** PostgreSQL 14+ / [Neon](https://neon.tech) Serverless Postgres
- **Language:** SQL

---

*Submitted as part of CAISc 2026 Research Proposal — B.Tech CSSE Semester 6, KIIT University*
