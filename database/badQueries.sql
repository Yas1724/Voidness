-- ============================================================
-- QueryOptBench - 50 Bad Queries
-- Yashraj Singh | Roll No. 2328058 | B.Tech CSE Semester 6
-- CAISc 2026 | PostgreSQL (Neon Serverless)
-- ============================================================
-- Each query is intentionally bad. Anti-patterns are labelled.
-- Run schema.sql first before testing any of these.
-- ============================================================

-- =====================
-- DOMAIN 1: E-COMMERCE
-- =====================

-- #1 | GET /api/orders/user/:userId | Severity: HIGH
-- Anti-pattern: Missing index + no pagination + over-fetching
SELECT o.*, p.name, p.price, dc.code, dc.percentage, s.status
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
LEFT JOIN discount_codes dc ON dc.id = o.discount_code_id
LEFT JOIN shipping s ON s.order_id = o.id
WHERE o.user_id = $1
ORDER BY o.created_at DESC;

-- #2 | GET /api/products/search | Severity: MEDIUM
-- Anti-pattern: Leading wildcard LIKE blocking index
SELECT p.*, c.name AS category_name
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE p.name LIKE '%$1%'
  AND p.price BETWEEN $2 AND $3
  AND p.category_id = $4
ORDER BY p.created_at DESC;

-- #3 | GET /api/analytics/revenue | Severity: HIGH
-- Anti-pattern: Correlated subquery instead of aggregation/window function
SELECT c.name, EXTRACT(MONTH FROM o.created_at) AS month,
  (SELECT SUM(oi2.price * oi2.quantity)
   FROM order_items oi2 JOIN orders o2 ON o2.id = oi2.order_id
   WHERE o2.status = 'completed'
     AND EXTRACT(MONTH FROM o2.created_at) = EXTRACT(MONTH FROM o.created_at)
     AND p.category_id = c.id) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
JOIN categories c ON c.id = p.category_id
WHERE o.created_at >= NOW() - INTERVAL '12 months'
GROUP BY c.name, month;

-- #4 | GET /api/products/recommended/:userId | Severity: HIGH
-- Anti-pattern: NOT IN subquery anti-pattern
SELECT DISTINCT p.*
FROM products p
WHERE p.id NOT IN (
  SELECT oi2.product_id FROM order_items oi2
  JOIN orders o2 ON o2.id = oi2.order_id
  WHERE o2.user_id = $1
)
AND p.category_id IN (
  SELECT DISTINCT p2.category_id FROM products p2
  JOIN order_items oi ON oi.product_id = p2.id
  JOIN orders o ON o.id = oi.order_id
  WHERE o.user_id = $1
)
LIMIT 10;

-- #5 | GET /api/cart/:userId | Severity: MEDIUM
-- Anti-pattern: SELECT * over-fetching + correlated subquery
SELECT ci.*, p.*
FROM carts c
JOIN cart_items ci ON ci.cart_id = c.id
JOIN products p ON p.id = ci.product_id
WHERE c.user_id = $1
  AND c.updated_at = (
    SELECT MAX(updated_at) FROM carts WHERE user_id = $1
  );

-- ======================
-- DOMAIN 2: SOCIAL MEDIA
-- ======================

-- #6 | GET /api/feed/:userId | Severity: HIGH
-- Anti-pattern: N+1 correlated subqueries for aggregates
SELECT p.*, u.username, u.avatar_url,
  (SELECT COUNT(*) FROM likes WHERE post_id = p.id) AS like_count,
  (SELECT COUNT(*) FROM comments WHERE post_id = p.id) AS comment_count,
  (SELECT COUNT(*) FROM likes WHERE post_id = p.id AND user_id = $1) AS user_liked
FROM posts p
JOIN users u ON u.id = p.user_id
WHERE p.user_id IN (SELECT following_id FROM follows WHERE follower_id = $1)
ORDER BY p.created_at DESC LIMIT 20;

-- #7 | GET /api/posts/:postId/comments | Severity: HIGH
-- Anti-pattern: OFFSET pagination + unbounded array_agg
SELECT c.*, u.username, u.avatar_url,
  COUNT(cl.id) AS likes,
  array_agg(json_build_object('id', r.id, 'content', r.content, 'username', ru.username)) AS replies
FROM comments c
JOIN users u ON u.id = c.user_id
LEFT JOIN comment_likes cl ON cl.comment_id = c.id
LEFT JOIN comments r ON r.parent_id = c.id
LEFT JOIN users ru ON ru.id = r.user_id
WHERE c.post_id = $1 AND c.parent_id IS NULL
GROUP BY c.id, u.username, u.avatar_url
OFFSET $2 LIMIT 20;

-- #8 | GET /api/users/search | Severity: MEDIUM
-- Anti-pattern: Function on column + leading wildcard + SELECT *
SELECT * FROM users
WHERE LOWER(username) LIKE LOWER('%$1%')
   OR LOWER(display_name) LIKE LOWER('%$1%')
ORDER BY follower_count DESC
LIMIT 20;

-- #9 | GET /api/notifications/:userId | Severity: HIGH
-- Anti-pattern: CASE correlated subqueries + no pagination + no index
SELECT n.*, u.username, u.avatar_url,
  CASE
    WHEN n.entity_type = 'post'    THEN (SELECT content FROM posts    WHERE id = n.entity_id)
    WHEN n.entity_type = 'comment' THEN (SELECT content FROM comments WHERE id = n.entity_id)
  END AS entity_content
FROM notifications n
JOIN users u ON u.id = n.actor_id
WHERE n.user_id = $1
ORDER BY n.created_at DESC;

-- #10 | GET /api/profile/:userId/stats | Severity: MEDIUM
-- Anti-pattern: Multiple correlated subqueries instead of single aggregation
SELECT
  (SELECT COUNT(*) FROM posts  WHERE user_id = $1) AS post_count,
  (SELECT COUNT(*) FROM follows WHERE following_id = $1) AS follower_count,
  (SELECT COUNT(*) FROM follows WHERE follower_id  = $1) AS following_count,
  (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id = l.post_id WHERE p.user_id = $1) AS total_likes
FROM users WHERE id = $1;

-- ====================
-- DOMAIN 3: HEALTHCARE
-- ====================

-- #11 | GET /api/patients/:patientId/history | Severity: HIGH
-- Anti-pattern: Unbounded json_agg + SELECT * on sensitive data
SELECT p.*,
  json_agg(DISTINCT a.*)  AS appointments,
  json_agg(DISTINCT pr.*) AS prescriptions,
  json_agg(DISTINCT lr.*) AS lab_results
FROM patients p
LEFT JOIN appointments  a  ON a.patient_id  = p.id
LEFT JOIN prescriptions pr ON pr.patient_id = p.id
LEFT JOIN lab_results   lr ON lr.patient_id = p.id
WHERE p.id = $1
GROUP BY p.id;

-- #12 | GET /api/appointments/available | Severity: HIGH
-- Anti-pattern: NOT IN subqueries + function preventing index use
SELECT d.*, ds.*
FROM doctors d
JOIN doctor_schedules ds ON ds.doctor_id = d.id
WHERE d.specialization = $1
  AND ds.day_of_week = EXTRACT(DOW FROM $2::date)
  AND d.id NOT IN (
    SELECT doctor_id FROM appointments
    WHERE DATE(scheduled_at) = $2::date AND status != 'cancelled'
  )
  AND d.id NOT IN (
    SELECT doctor_id FROM doctor_leaves WHERE leave_date = $2::date
  );

-- #13 | GET /api/dashboard/doctor/:doctorId | Severity: MEDIUM
-- Anti-pattern: Multiple round trips instead of batched query
SELECT * FROM appointments
WHERE doctor_id = $1 AND DATE(scheduled_at) = CURRENT_DATE;

SELECT * FROM lab_results
WHERE doctor_id = $1 AND status = 'pending' LIMIT 10;

SELECT * FROM prescriptions
WHERE doctor_id = $1 ORDER BY issued_at DESC LIMIT 5;

-- #14 | GET /api/reports/department/:deptId | Severity: MEDIUM
-- Anti-pattern: EXTRACT function preventing index range scan
SELECT d.name,
  COUNT(a.id) AS total_appointments,
  AVG(EXTRACT(EPOCH FROM (a.actual_start_at - a.scheduled_at)) / 60) AS avg_wait
FROM doctors d
LEFT JOIN appointments a ON a.doctor_id = d.id
WHERE d.department_id = $1
  AND EXTRACT(MONTH FROM a.scheduled_at) = EXTRACT(MONTH FROM CURRENT_DATE)
  AND EXTRACT(YEAR  FROM a.scheduled_at) = EXTRACT(YEAR  FROM CURRENT_DATE)
GROUP BY d.id, d.name;

-- #15 | GET /api/patients/search | Severity: MEDIUM
-- Anti-pattern: ILIKE + CAST + OR full scan + PII over-exposure
SELECT * FROM patients
WHERE name  ILIKE '%$1%'
   OR phone LIKE  '%$1%'
   OR CAST(id AS TEXT) LIKE '%$1%'
ORDER BY created_at DESC LIMIT 20;

-- ===========================
-- DOMAIN 4: SAAS/MULTI-TENANT
-- ===========================

-- #16 | GET /api/workspace/:workspaceId/members | Severity: HIGH
-- Anti-pattern: Correlated subquery per row + SELECT * exposing PII
SELECT u.*, wm.role, wm.joined_at,
  array_agg(DISTINCT p.action) AS permissions,
  (SELECT MAX(created_at) FROM user_activity
   WHERE user_id = u.id AND workspace_id = $1) AS last_active
FROM workspace_members wm
JOIN users u ON u.id = wm.user_id
LEFT JOIN permissions p ON p.user_id = u.id AND p.workspace_id = $1
WHERE wm.workspace_id = $1
GROUP BY u.id, wm.role, wm.joined_at;

-- #17 | GET /api/projects/:projectId/tasks | Severity: HIGH
-- Anti-pattern: Cartesian explosion from multiple one-to-many JOINs
SELECT t.*,
  array_agg(DISTINCT u.name)  AS assignees,
  array_agg(DISTINCT l.name)  AS labels,
  COUNT(DISTINCT c.id)        AS comment_count,
  COUNT(DISTINCT att.id)      AS attachment_count
FROM tasks t
LEFT JOIN task_assignees ta  ON ta.task_id  = t.id
LEFT JOIN users u            ON u.id        = ta.user_id
LEFT JOIN task_labels tl     ON tl.task_id  = t.id
LEFT JOIN labels l           ON l.id        = tl.label_id
LEFT JOIN comments c         ON c.task_id   = t.id
LEFT JOIN attachments att    ON att.task_id = t.id
WHERE t.project_id = $1
GROUP BY t.id ORDER BY t.updated_at DESC;

-- #18 | GET /api/billing/invoices/:workspaceId | Severity: HIGH
-- Anti-pattern: Correlated subquery per invoice + sensitive data in json_agg(*)
SELECT i.*,
  json_agg(ii.*) AS items,
  json_agg(p.*)  AS payments,
  (SELECT SUM(value) FROM usage_records
   WHERE workspace_id = $1
     AND recorded_at BETWEEN i.period_start AND i.period_end
     AND metric = 'api_calls') AS api_usage
FROM invoices i
LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
LEFT JOIN payments p       ON p.invoice_id  = i.id
WHERE i.workspace_id = $1
ORDER BY i.created_at DESC
GROUP BY i.id;

-- #19 | GET /api/audit-log/:workspaceId | Severity: MEDIUM
-- Anti-pattern: OFFSET pagination on large append-only table
SELECT al.*, u.name, u.email, u.avatar_url
FROM audit_logs al
JOIN users u ON u.id = al.actor_id
WHERE al.workspace_id = $1
ORDER BY al.created_at DESC
OFFSET $2 LIMIT 50;

-- #20 | GET /api/analytics/usage/:workspaceId | Severity: MEDIUM
-- Anti-pattern: DATE() function + no partial index on time-series table
SELECT DATE(created_at) AS day,
  COUNT(DISTINCT user_id) AS dau,
  COUNT(*)                AS total_events
FROM events
WHERE workspace_id = $1
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- ==================
-- DOMAIN 5: FINTECH
-- ==================

-- #21 | GET /api/accounts/:userId/transactions | Severity: HIGH
-- Anti-pattern: O(n²) self-join for running total instead of window function
SELECT t.*, m.name,
  SUM(CASE WHEN t2.type = 'credit' THEN t2.amount ELSE -t2.amount END) AS running_balance
FROM transactions t
LEFT JOIN merchants m  ON m.id = t.merchant_id
JOIN transactions t2   ON t2.account_id = t.account_id AND t2.created_at <= t.created_at
WHERE t.account_id = $1
GROUP BY t.id, m.name
ORDER BY t.created_at DESC
OFFSET $2 LIMIT 20;

-- #22 | GET /api/reports/spending/:userId | Severity: MEDIUM
-- Anti-pattern: TO_CHAR function preventing index + IN subquery
SELECT TO_CHAR(created_at, 'YYYY-MM') AS month, category, SUM(amount) AS total_spent
FROM transactions
WHERE account_id IN (SELECT id FROM accounts WHERE user_id = $1)
  AND type   = 'debit'
  AND status = 'completed'
  AND created_at >= NOW() - INTERVAL '6 months'
GROUP BY TO_CHAR(created_at, 'YYYY-MM'), category
ORDER BY month DESC;

-- #23 | GET /api/loans/:userId/eligibility | Severity: HIGH
-- Anti-pattern: Four correlated subqueries replaceable by CTEs
SELECT u.credit_score,
  (SELECT AVG(amount) FROM transactions t JOIN accounts a ON a.id = t.account_id
   WHERE a.user_id = $1 AND t.type = 'credit'
     AND t.created_at >= NOW() - INTERVAL '3 months') AS avg_income,
  (SELECT COUNT(*)       FROM loans WHERE user_id = $1 AND status = 'active') AS active_loans,
  (SELECT SUM(emi_amount) FROM loans WHERE user_id = $1 AND status = 'active') AS total_emi
FROM users WHERE id = $1;

-- #24 | GET /api/fraud/alerts/:accountId | Severity: HIGH
-- Anti-pattern: Duplicate correlated subqueries + expensive UNNEST in filter
SELECT t.*, m.risk_score,
  (SELECT AVG(amount) FROM transactions
   WHERE account_id = $1 AND created_at >= NOW() - INTERVAL '90 days') AS baseline
FROM transactions t
JOIN merchants m ON m.id = t.merchant_id
WHERE t.account_id = $1
  AND t.amount > (SELECT AVG(amount) * 3 FROM transactions WHERE account_id = $1)
  AND t.location_country NOT IN (
    SELECT UNNEST(common_countries) FROM account_patterns WHERE account_id = $1
  )
  AND t.created_at >= NOW() - INTERVAL '7 days';

-- #25 | GET /api/investments/:userId/portfolio | Severity: HIGH
-- Anti-pattern: Correlated subquery for aggregate used as denominator per row
SELECT h.*, a.symbol, a.current_price,
  h.quantity * a.current_price AS current_value,
  (h.quantity * a.current_price) / (
    SELECT SUM(h2.quantity * a2.current_price)
    FROM holdings h2 JOIN assets a2 ON a2.id = h2.asset_id
    WHERE h2.portfolio_id = h.portfolio_id
  ) * 100 AS allocation_pct
FROM holdings h
JOIN assets a ON a.id = h.asset_id
WHERE h.portfolio_id = (SELECT id FROM portfolios WHERE user_id = $1 LIMIT 1);

-- ==================
-- DOMAIN 6: EDTECH
-- ==================

-- #26 | GET /api/courses/:courseId/progress/:userId | Severity: MEDIUM
-- Anti-pattern: Correlated subquery + unfiltered aggregate across retries
SELECT
  COUNT(CASE WHEN up.status = 'completed' THEN 1 END) AS completed,
  SUM(up.time_spent_seconds)                           AS total_time,
  AVG(qa.score)                                        AS avg_score,
  (SELECT issued_at FROM certificates WHERE user_id = $1 AND course_id = $2) AS cert_date
FROM courses c
JOIN modules m        ON m.course_id  = c.id
JOIN lessons l        ON l.module_id  = m.id
LEFT JOIN user_progress up ON up.lesson_id = l.id AND up.user_id = $1
LEFT JOIN quiz_attempts qa ON qa.lesson_id = l.id AND qa.user_id = $1
WHERE c.id = $2;

-- #27 | GET /api/instructor/:instructorId/dashboard | Severity: HIGH
-- Anti-pattern: Massive intermediate JOIN + incorrect business logic in aggregation
SELECT c.id, c.title,
  COUNT(DISTINCT e.user_id) AS enrolled,
  COUNT(DISTINCT CASE WHEN up.status = 'completed' THEN up.user_id END) * 100.0
    / NULLIF(COUNT(DISTINCT e.user_id), 0) AS completion_rate,
  SUM(e.payment_amount) AS revenue
FROM courses c
LEFT JOIN enrollments e  ON e.course_id  = c.id
LEFT JOIN lessons l      ON l.course_id  = c.id
LEFT JOIN user_progress up ON up.lesson_id = l.id
WHERE c.instructor_id = $1
GROUP BY c.id, c.title;

-- #28 | GET /api/leaderboard/:courseId | Severity: HIGH
-- Anti-pattern: Pre-aggregation missing — O(n x m) intermediate before GROUP BY
SELECT u.name, u.avatar_url,
  AVG(qa.score)                                        AS avg_score,
  COUNT(CASE WHEN up.status = 'completed' THEN 1 END) AS completed,
  SUM(up.time_spent_seconds)                           AS time_spent
FROM enrollments e
JOIN users u ON u.id = e.user_id
LEFT JOIN quiz_attempts qa ON qa.user_id = e.user_id AND qa.course_id = $1
LEFT JOIN lessons l        ON l.course_id = $1
LEFT JOIN user_progress up ON up.user_id = e.user_id AND up.lesson_id = l.id
WHERE e.course_id = $1
GROUP BY u.id ORDER BY avg_score DESC NULLS LAST LIMIT 50;

-- #29 | GET /api/recommendations/:userId | Severity: HIGH
-- Anti-pattern: Three nested subqueries including NOT IN anti-pattern
SELECT DISTINCT c.*
FROM courses c
WHERE c.id NOT IN (SELECT course_id FROM enrollments WHERE user_id = $1)
  AND c.category_id IN (
    SELECT DISTINCT c2.category_id FROM courses c2
    JOIN enrollments e ON e.course_id = c2.id
    WHERE e.user_id = $1 AND e.completed_at IS NOT NULL
  )
  AND c.difficulty <= (
    SELECT MAX(c3.difficulty) + 1 FROM courses c3
    JOIN enrollments e2 ON e2.course_id = c3.id WHERE e2.user_id = $1
  )
ORDER BY c.rating DESC LIMIT 10;

-- #30 | GET /api/admin/reports/engagement | Severity: HIGH
-- Anti-pattern: Correlated subqueries per generated series row = 90 queries
SELECT dates.day,
  (SELECT COUNT(DISTINCT user_id) FROM user_progress WHERE DATE(completed_at) = dates.day) AS dau,
  (SELECT COUNT(*)                FROM enrollments    WHERE DATE(enrolled_at)  = dates.day) AS new_enrollments,
  (SELECT SUM(payment_amount)     FROM enrollments    WHERE DATE(enrolled_at)  = dates.day) AS revenue
FROM (
  SELECT generate_series(
    CURRENT_DATE - INTERVAL '30 days',
    CURRENT_DATE,
    INTERVAL '1 day'
  )::date AS day
) dates;

-- ===================
-- DOMAIN 7: LOGISTICS
-- ===================

-- #31 | GET /api/shipments/:shipmentId/tracking | Severity: MEDIUM
-- Anti-pattern: json_agg(*) fetching all columns on unbounded event history
SELECT s.*,
  json_agg(te.* ORDER BY te.event_time DESC) AS tracking_history
FROM shipments s
JOIN orders o           ON o.id = s.order_id
LEFT JOIN tracking_events te ON te.shipment_id = s.id
LEFT JOIN addresses a_orig   ON a_orig.id = s.origin
LEFT JOIN addresses a_dest   ON a_dest.id = s.destination
WHERE s.id = $1
GROUP BY s.id, o.total_amount, a_orig.city, a_dest.city;

-- #32 | GET /api/drivers/:driverId/schedule | Severity: MEDIUM
-- Anti-pattern: Subquery inside JOIN condition
SELECT d.*, s.weight, a.street, a.lat, a.lng
FROM deliveries d
JOIN shipments s  ON s.id  = d.shipment_id
JOIN addresses a  ON a.id  = s.destination_address_id
JOIN customers c  ON c.id  = (SELECT user_id FROM orders WHERE id = s.order_id)
WHERE d.driver_id      = $1
  AND d.scheduled_date = CURRENT_DATE
ORDER BY d.sequence_order ASC;

-- #33 | GET /api/warehouse/:warehouseId/inventory | Severity: MEDIUM
-- Anti-pattern: Correlated subquery per row + sort on computed column without index
SELECT p.name, p.sku, i.quantity, i.reserved_quantity,
  i.quantity - i.reserved_quantity AS available,
  (SELECT SUM(quantity) FROM pending_orders
   WHERE product_id = p.id AND warehouse_id = $1) AS incoming
FROM inventory i
JOIN products p ON p.id = i.product_id
WHERE i.warehouse_id = $1
ORDER BY available ASC;

-- #34 | GET /api/routes/optimize/:zoneId | Severity: HIGH
-- Anti-pattern: CROSS JOIN cartesian product + per-row distance computation
SELECT d.*, a.lat, a.lng,
  SQRT(POW(a.lat - dr.current_lat, 2) + POW(a.lng - dr.current_lng, 2)) AS distance
FROM deliveries d
JOIN shipments s ON s.id = d.shipment_id
JOIN addresses a ON a.id = s.destination_address_id
CROSS JOIN drivers dr
WHERE d.zone_id        = $1
  AND d.scheduled_date = CURRENT_DATE
  AND d.status         = 'pending'
  AND dr.status        = 'available'
ORDER BY distance ASC, d.time_window_start ASC;

-- #35 | GET /api/reports/delivery-performance | Severity: MEDIUM
-- Anti-pattern: Repeated aggregate expression + missing composite index
SELECT c.name,
  COUNT(s.id) AS total,
  COUNT(CASE WHEN s.actual_delivery <= s.estimated_delivery THEN 1 END) AS on_time,
  COUNT(CASE WHEN s.actual_delivery <= s.estimated_delivery THEN 1 END) * 100.0
    / COUNT(s.id) AS on_time_rate,
  AVG(EXTRACT(EPOCH FROM (s.actual_delivery - s.estimated_delivery)) / 3600) AS avg_delay_hrs
FROM shipments s
JOIN carriers c ON c.id = s.carrier
WHERE s.created_at BETWEEN $1 AND $2
  AND s.status = 'delivered'
GROUP BY c.id, c.name
ORDER BY on_time_rate DESC;

-- =======================
-- DOMAIN 8: CONTENT/MEDIA
-- =======================

-- #36 | GET /api/articles/trending | Severity: HIGH
-- Anti-pattern: Multiple COUNT DISTINCT on large event tables without pre-aggregation
SELECT a.id, a.title,
  COUNT(DISTINCT av.id)  AS views,
  COUNT(DISTINCT ash.id) AS shares,
  COUNT(DISTINCT c.id)   AS comments,
  COUNT(DISTINCT av.id) + COUNT(DISTINCT ash.id) * 3 + COUNT(DISTINCT c.id) * 5 AS score
FROM articles a
LEFT JOIN article_views  av  ON av.article_id  = a.id AND av.viewed_at  >= NOW() - INTERVAL '24 hours'
LEFT JOIN article_shares ash ON ash.article_id = a.id AND ash.shared_at >= NOW() - INTERVAL '24 hours'
LEFT JOIN comments c         ON c.article_id   = a.id AND c.created_at  >= NOW() - INTERVAL '24 hours'
WHERE a.status = 'published'
GROUP BY a.id ORDER BY score DESC LIMIT 20;

-- #37 | GET /api/videos/:videoId/recommendations | Severity: HIGH
-- Anti-pattern: Correlated IN subquery inside aggregate function
SELECT DISTINCT v.*,
  COUNT(CASE WHEN vt.tag_id IN (
    SELECT tag_id FROM video_tags WHERE video_id = $1
  ) THEN 1 END) AS shared_tags
FROM videos v
JOIN video_tags vt ON vt.video_id = v.id
WHERE v.id != $1
  AND v.status      = 'published'
  AND v.category_id = (SELECT category_id FROM videos WHERE id = $1)
GROUP BY v.id
ORDER BY shared_tags DESC, v.view_count DESC LIMIT 10;

-- #38 | GET /api/creator/:creatorId/analytics | Severity: HIGH
-- Anti-pattern: Correlated subquery per video + missing partial index on event table
SELECT v.id, v.title,
  COUNT(vv.id)              AS views,
  SUM(vv.revenue_generated) AS revenue,
  (SELECT COUNT(*) FROM subscriptions
   WHERE creator_id   = $1
     AND subscribed_at BETWEEN v.published_at AND v.published_at + INTERVAL '7 days') AS subs_gained
FROM videos v
LEFT JOIN video_views vv ON vv.video_id = v.id AND vv.viewed_at >= NOW() - INTERVAL '90 days'
WHERE v.creator_id = $1 AND v.status = 'published'
GROUP BY v.id, v.title, v.published_at, v.duration
ORDER BY views DESC;

-- #39 | GET /api/search/content | Severity: HIGH
-- Anti-pattern: ILIKE full scan across multiple large text columns instead of tsvector
SELECT 'article' AS type, id, title FROM articles
WHERE (title ILIKE '%$1%' OR body ILIKE '%$1%') AND status = 'published'
UNION ALL
SELECT 'video', id, title FROM videos
WHERE (title ILIKE '%$1%' OR transcript ILIKE '%$1%') AND status = 'published'
UNION ALL
SELECT 'podcast', id, title FROM podcasts
WHERE (title ILIKE '%$1%' OR description ILIKE '%$1%') AND status = 'published'
ORDER BY 1 LIMIT 20;

-- #40 | GET /api/playlists/:playlistId | Severity: MEDIUM
-- Anti-pattern: Missing latest-record-per-group causing duplicate rows
SELECT pv.position, v.id, v.title, v.duration,
  wh.watch_duration, wh.completed,
  SUM(v.duration) OVER () AS total_duration
FROM playlist_videos pv
JOIN videos v ON v.id = pv.video_id
LEFT JOIN watch_history wh ON wh.video_id = v.id AND wh.user_id = $2
WHERE pv.playlist_id = $1 AND v.status = 'published'
ORDER BY pv.position;

-- ======================
-- DOMAIN 9: HR/PEOPLE OPS
-- ======================

-- #41 | GET /api/employees/:employeeId/profile | Severity: HIGH
-- Anti-pattern: Recursive CTE + correlated subqueries + unbounded sensitive json_agg
WITH RECURSIVE manager_chain AS (
  SELECT id, name, manager_id, 1 AS level FROM employees WHERE id = $1
  UNION ALL
  SELECT e.id, e.name, e.manager_id, mc.level + 1
  FROM employees e JOIN manager_chain mc ON mc.manager_id = e.id
)
SELECT e.*,
  (SELECT json_agg(json_build_object('skill', s.name, 'level', es.proficiency))
   FROM employee_skills es JOIN skills s ON s.id = es.skill_id
   WHERE es.employee_id = $1) AS skills,
  (SELECT json_agg(pr.* ORDER BY pr.review_date DESC)
   FROM performance_reviews pr WHERE pr.employee_id = $1) AS reviews
FROM employees e WHERE e.id = $1;

-- #42 | GET /api/payroll/run/:periodId | Severity: HIGH
-- Anti-pattern: Four correlated subqueries per employee row + PII exposure
SELECT e.id, e.name, e.salary, e.bank_account,
  (SELECT SUM(hours_worked)   FROM attendance WHERE employee_id = e.id AND date BETWEEN pp.start_date AND pp.end_date) AS hours,
  (SELECT SUM(overtime_hours) FROM attendance WHERE employee_id = e.id AND date BETWEEN pp.start_date AND pp.end_date) AS overtime,
  (SELECT SUM(amount) FROM bonuses    WHERE employee_id = e.id AND period_id = $1) AS bonus,
  (SELECT SUM(amount) FROM deductions WHERE employee_id = e.id AND period_id = $1) AS deductions
FROM employees e
CROSS JOIN payroll_periods pp
WHERE pp.id = $1 AND e.status = 'active';

-- #43 | GET /api/recruitment/pipeline/:jobId | Severity: MEDIUM
-- Anti-pattern: Unbounded text aggregation + no pagination on sensitive HR data
SELECT c.name, c.email, a.current_stage, a.applied_at,
  array_agg(json_build_object(
    'stage',    ist.stage_name,
    'score',    ist.score,
    'feedback', ist.feedback
  ) ORDER BY ist.scheduled_at) AS interviews
FROM applications a
JOIN candidates c         ON c.id  = a.candidate_id
LEFT JOIN interview_stages ist ON ist.application_id = a.id
WHERE a.job_id = $1
GROUP BY c.id, a.id
ORDER BY a.applied_at DESC;

-- #44 | GET /api/org-chart/:departmentId | Severity: HIGH
-- Anti-pattern: Unbounded recursive CTE without cycle detection or depth limit
WITH RECURSIVE org AS (
  SELECT id, name, job_title, avatar_url, manager_id, 0 AS depth
  FROM employees
  WHERE department_id = $1 AND manager_id IS NULL AND status = 'active'
  UNION ALL
  SELECT e.id, e.name, e.job_title, e.avatar_url, e.manager_id, org.depth + 1
  FROM employees e
  JOIN org ON org.id = e.manager_id
  WHERE e.status = 'active'
)
SELECT * FROM org ORDER BY depth, name;

-- #45 | GET /api/leave/balance/:employeeId | Severity: MEDIUM
-- Anti-pattern: Three correlated subqueries per policy row + EXTRACT preventing index
SELECT lp.leave_type, lp.annual_days,
  (SELECT SUM(days) FROM leave_requests
   WHERE employee_id = $1 AND leave_type = lp.leave_type AND status = 'approved'
     AND EXTRACT(YEAR FROM start_date) = EXTRACT(YEAR FROM NOW())) AS used,
  (SELECT SUM(days) FROM leave_requests
   WHERE employee_id = $1 AND leave_type = lp.leave_type AND status = 'pending') AS pending,
  (SELECT SUM(days) FROM leave_adjustments
   WHERE employee_id = $1 AND leave_type = lp.leave_type) AS adjustments
FROM leave_policies lp
JOIN employees e ON e.employment_type = lp.employment_type
WHERE e.id = $1;

-- ============================
-- DOMAIN 10: REAL ESTATE/BOOKING
-- ============================

-- #46 | GET /api/properties/search | Severity: HIGH
-- Anti-pattern: NOT IN subquery + OFFSET + Cartesian JOIN explosion
SELECT p.*, AVG(r.rating) AS avg_rating,
  array_agg(DISTINCT a.name) AS amenities
FROM properties p
JOIN hosts h                  ON h.user_id     = p.host_id
LEFT JOIN reviews r           ON r.property_id = p.id
LEFT JOIN property_amenities pa ON pa.property_id = p.id
LEFT JOIN amenities a         ON a.id           = pa.amenity_id
WHERE p.city            = $1
  AND p.max_guests     >= $2
  AND p.price_per_night BETWEEN $3 AND $4
  AND p.status          = 'active'
  AND p.id NOT IN (
    SELECT property_id FROM bookings
    WHERE status IN ('confirmed', 'pending')
      AND check_in  < $6
      AND check_out > $5
  )
GROUP BY p.id
ORDER BY avg_rating DESC NULLS LAST
LIMIT 20 OFFSET $7;

-- #47 | GET /api/bookings/:hostId/upcoming | Severity: MEDIUM
-- Anti-pattern: Correlated subquery + PII exposure + no limit + missing composite index
SELECT b.*, p.title, u.name, u.email, u.phone, u.identity_verified,
  pay.status AS payment_status,
  (SELECT rating FROM reviews WHERE booking_id = b.id AND guest_id = b.guest_id) AS prev_rating
FROM bookings b
JOIN properties p  ON p.id  = b.property_id
JOIN hosts h       ON h.id  = p.host_id
JOIN users u       ON u.id  = b.guest_id
LEFT JOIN payments pay ON pay.booking_id = b.id
WHERE h.user_id    = $1
  AND b.check_in  >= CURRENT_DATE
  AND b.status NOT IN ('cancelled', 'rejected')
ORDER BY b.check_in ASC;

-- #48 | GET /api/host/:hostId/revenue | Severity: MEDIUM
-- Anti-pattern: TO_CHAR preventing index + incorrect business logic in query
SELECT TO_CHAR(b.check_in, 'YYYY-MM') AS month,
  COUNT(b.id)                                                              AS bookings,
  SUM(pay.amount)                                                          AS revenue,
  AVG(pay.amount / NULLIF(b.check_out - b.check_in, 0))                  AS avg_nightly_rate,
  SUM(b.check_out - b.check_in) * 100.0 / (COUNT(DISTINCT p.id) * 30)   AS occupancy_rate
FROM bookings b
JOIN properties p      ON p.id         = b.property_id
LEFT JOIN payments pay ON pay.booking_id = b.id AND pay.status = 'completed'
WHERE p.host_id    = $1
  AND b.status     = 'completed'
  AND b.check_in  >= NOW() - INTERVAL '12 months'
GROUP BY TO_CHAR(b.check_in, 'YYYY-MM')
ORDER BY month DESC;

-- #49 | GET /api/properties/:propertyId/calendar | Severity: HIGH
-- Anti-pattern: Three correlated subqueries per generated series row = 270 queries
SELECT dates.d AS date,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM blocked_dates WHERE property_id = $1 AND blocked_date = dates.d
    ) THEN 'blocked'
    WHEN EXISTS (
      SELECT 1 FROM bookings
      WHERE property_id = $1 AND status = 'confirmed'
        AND check_in <= dates.d AND check_out > dates.d
    ) THEN 'booked'
    ELSE 'available'
  END AS availability,
  COALESCE(
    (SELECT price_override FROM pricing_rules
     WHERE property_id = $1 AND dates.d BETWEEN date_from AND date_to LIMIT 1),
    p.base_price
  ) AS price
FROM generate_series(
  CURRENT_DATE,
  CURRENT_DATE + INTERVAL '90 days',
  INTERVAL '1 day'
) AS dates(d)
CROSS JOIN properties p
WHERE p.id = $1;

-- #50 | GET /api/platform/stats | Severity: MEDIUM
-- Anti-pattern: Five scalar subqueries on admin dashboard replaceable by CTEs
SELECT
  (SELECT COUNT(*)    FROM properties WHERE status = 'active')                                                    AS listings,
  (SELECT COUNT(*)    FROM bookings   WHERE DATE(created_at) = CURRENT_DATE)                                      AS bookings_today,
  (SELECT SUM(amount) FROM payments   WHERE status = 'completed'
     AND DATE_TRUNC('month', paid_at) = DATE_TRUNC('month', NOW()))                                               AS monthly_revenue,
  (SELECT json_agg(cs)
   FROM (
     SELECT city, COUNT(*) AS cnt FROM properties WHERE status = 'active'
     GROUP BY city ORDER BY cnt DESC LIMIT 5
   ) cs)                                                                                                           AS top_cities
FROM (SELECT 1) dummy;

-- ============================================================
-- END OF bad_queries.sql
-- ============================================================
