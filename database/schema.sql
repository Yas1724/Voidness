-- ============================================================
-- QueryOptBench - Database Schema
-- Yashraj Singh
-- PostgreSQL (Neon Serverless)
-- ============================================================
-- All tables are inferred from the 50 bad query scenarios.
-- Compatible with PostgreSQL 14+
-- ============================================================

-- =====================
-- DOMAIN 1: E-COMMERCE
-- =====================

CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    username        VARCHAR(50) UNIQUE NOT NULL,
    display_name    VARCHAR(100),
    email           VARCHAR(255) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    avatar_url      TEXT,
    follower_count  INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE products (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    description   TEXT,
    price         NUMERIC(10, 2) NOT NULL,
    category_id   INT REFERENCES categories(id),
    stock         INT DEFAULT 0,
    sku           VARCHAR(100) UNIQUE,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE discount_codes (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50) UNIQUE NOT NULL,
    percentage  NUMERIC(5, 2),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE orders (
    id               SERIAL PRIMARY KEY,
    user_id          INT REFERENCES users(id),
    discount_code_id INT REFERENCES discount_codes(id),
    status           VARCHAR(50) DEFAULT 'pending',
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE order_items (
    id          SERIAL PRIMARY KEY,
    order_id    INT REFERENCES orders(id),
    product_id  INT REFERENCES products(id),
    quantity    INT NOT NULL,
    price       NUMERIC(10, 2) NOT NULL
);

CREATE TABLE shipping (
    id          SERIAL PRIMARY KEY,
    order_id    INT REFERENCES orders(id),
    status      VARCHAR(50) DEFAULT 'pending',
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE carts (
    id          SERIAL PRIMARY KEY,
    user_id     INT REFERENCES users(id),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE cart_items (
    id          SERIAL PRIMARY KEY,
    cart_id     INT REFERENCES carts(id),
    product_id  INT REFERENCES products(id),
    quantity    INT DEFAULT 1
);

-- ======================
-- DOMAIN 2: SOCIAL MEDIA
-- ======================

CREATE TABLE posts (
    id          SERIAL PRIMARY KEY,
    user_id     INT REFERENCES users(id),
    content     TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE follows (
    id            SERIAL PRIMARY KEY,
    follower_id   INT REFERENCES users(id),
    following_id  INT REFERENCES users(id),
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(follower_id, following_id)
);

CREATE TABLE likes (
    id          SERIAL PRIMARY KEY,
    post_id     INT REFERENCES posts(id),
    user_id     INT REFERENCES users(id),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

CREATE TABLE comments (
    id          SERIAL PRIMARY KEY,
    post_id     INT REFERENCES posts(id),
    user_id     INT REFERENCES users(id),
    parent_id   INT REFERENCES comments(id),
    content     TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE comment_likes (
    id          SERIAL PRIMARY KEY,
    comment_id  INT REFERENCES comments(id),
    user_id     INT REFERENCES users(id),
    UNIQUE(comment_id, user_id)
);

CREATE TABLE notifications (
    id           SERIAL PRIMARY KEY,
    user_id      INT REFERENCES users(id),
    actor_id     INT REFERENCES users(id),
    entity_type  VARCHAR(50),  -- 'post' | 'comment'
    entity_id    INT,
    read         BOOLEAN DEFAULT FALSE,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ====================
-- DOMAIN 3: HEALTHCARE
-- ====================

CREATE TABLE patients (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    phone       VARCHAR(20),
    dob         DATE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE departments (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL
);

CREATE TABLE doctors (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    specialization  VARCHAR(100),
    department_id   INT REFERENCES departments(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE doctor_schedules (
    id           SERIAL PRIMARY KEY,
    doctor_id    INT REFERENCES doctors(id),
    day_of_week  INT,  -- 0=Sunday .. 6=Saturday
    start_time   TIME,
    end_time     TIME
);

CREATE TABLE doctor_leaves (
    id          SERIAL PRIMARY KEY,
    doctor_id   INT REFERENCES doctors(id),
    leave_date  DATE NOT NULL
);

CREATE TABLE appointments (
    id               SERIAL PRIMARY KEY,
    patient_id       INT REFERENCES patients(id),
    doctor_id        INT REFERENCES doctors(id),
    scheduled_at     TIMESTAMPTZ,
    actual_start_at  TIMESTAMPTZ,
    status           VARCHAR(50) DEFAULT 'scheduled'  -- 'scheduled' | 'completed' | 'cancelled'
);

CREATE TABLE prescriptions (
    id          SERIAL PRIMARY KEY,
    patient_id  INT REFERENCES patients(id),
    doctor_id   INT REFERENCES doctors(id),
    notes       TEXT,
    issued_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lab_results (
    id          SERIAL PRIMARY KEY,
    patient_id  INT REFERENCES patients(id),
    doctor_id   INT REFERENCES doctors(id),
    result      TEXT,
    status      VARCHAR(50) DEFAULT 'pending',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- DOMAIN 4: SAAS/MULTI-TENANT
-- ===========================

CREATE TABLE workspaces (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE workspace_members (
    id            SERIAL PRIMARY KEY,
    workspace_id  INT REFERENCES workspaces(id),
    user_id       INT REFERENCES users(id),
    role          VARCHAR(50) DEFAULT 'member',
    joined_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE permissions (
    id            SERIAL PRIMARY KEY,
    user_id       INT REFERENCES users(id),
    workspace_id  INT REFERENCES workspaces(id),
    action        VARCHAR(100) NOT NULL
);

CREATE TABLE user_activity (
    id            SERIAL PRIMARY KEY,
    user_id       INT REFERENCES users(id),
    workspace_id  INT REFERENCES workspaces(id),
    action        VARCHAR(255),
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE projects (
    id            SERIAL PRIMARY KEY,
    workspace_id  INT REFERENCES workspaces(id),
    name          VARCHAR(255) NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tasks (
    id          SERIAL PRIMARY KEY,
    project_id  INT REFERENCES projects(id),
    title       VARCHAR(255) NOT NULL,
    status      VARCHAR(50) DEFAULT 'open',
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE task_assignees (
    id       SERIAL PRIMARY KEY,
    task_id  INT REFERENCES tasks(id),
    user_id  INT REFERENCES users(id)
);

CREATE TABLE labels (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL
);

CREATE TABLE task_labels (
    id        SERIAL PRIMARY KEY,
    task_id   INT REFERENCES tasks(id),
    label_id  INT REFERENCES labels(id)
);

CREATE TABLE attachments (
    id          SERIAL PRIMARY KEY,
    task_id     INT REFERENCES tasks(id),
    url         TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE invoices (
    id             SERIAL PRIMARY KEY,
    workspace_id   INT REFERENCES workspaces(id),
    period_start   TIMESTAMPTZ,
    period_end     TIMESTAMPTZ,
    status         VARCHAR(50) DEFAULT 'pending',
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE invoice_items (
    id          SERIAL PRIMARY KEY,
    invoice_id  INT REFERENCES invoices(id),
    description TEXT,
    amount      NUMERIC(12, 2)
);

CREATE TABLE payments (
    id          SERIAL PRIMARY KEY,
    invoice_id  INT REFERENCES invoices(id),
    booking_id  INT,  -- also used by Real Estate domain
    amount      NUMERIC(12, 2),
    status      VARCHAR(50) DEFAULT 'pending',
    paid_at     TIMESTAMPTZ
);

CREATE TABLE usage_records (
    id            SERIAL PRIMARY KEY,
    workspace_id  INT REFERENCES workspaces(id),
    metric        VARCHAR(100),
    value         NUMERIC(12, 2),
    recorded_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE audit_logs (
    id            SERIAL PRIMARY KEY,
    workspace_id  INT REFERENCES workspaces(id),
    actor_id      INT REFERENCES users(id),
    action        VARCHAR(255),
    resource_type VARCHAR(100),
    resource_id   INT,
    ip_address    INET,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE events (
    id            SERIAL PRIMARY KEY,
    workspace_id  INT REFERENCES workspaces(id),
    user_id       INT REFERENCES users(id),
    event_type    VARCHAR(100),
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ==================
-- DOMAIN 5: FINTECH
-- ==================

CREATE TABLE accounts (
    id          SERIAL PRIMARY KEY,
    user_id     INT REFERENCES users(id),
    type        VARCHAR(50),
    balance     NUMERIC(15, 2) DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE merchants (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    risk_score  NUMERIC(4, 2) DEFAULT 0
);

CREATE TABLE transactions (
    id                SERIAL PRIMARY KEY,
    account_id        INT REFERENCES accounts(id),
    merchant_id       INT REFERENCES merchants(id),
    amount            NUMERIC(15, 2) NOT NULL,
    type              VARCHAR(20) NOT NULL,  -- 'credit' | 'debit'
    category          VARCHAR(100),
    status            VARCHAR(50) DEFAULT 'completed',
    location_country  VARCHAR(10),
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE loans (
    id           SERIAL PRIMARY KEY,
    user_id      INT REFERENCES users(id),
    amount       NUMERIC(15, 2),
    emi_amount   NUMERIC(15, 2),
    status       VARCHAR(50) DEFAULT 'active',
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE account_patterns (
    id                SERIAL PRIMARY KEY,
    account_id        INT REFERENCES accounts(id),
    common_countries  TEXT[]  -- array of ISO country codes
);

CREATE TABLE portfolios (
    id          SERIAL PRIMARY KEY,
    user_id     INT REFERENCES users(id),
    name        VARCHAR(100),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE assets (
    id             SERIAL PRIMARY KEY,
    symbol         VARCHAR(20) UNIQUE NOT NULL,
    name           VARCHAR(255),
    current_price  NUMERIC(15, 4)
);

CREATE TABLE holdings (
    id            SERIAL PRIMARY KEY,
    portfolio_id  INT REFERENCES portfolios(id),
    asset_id      INT REFERENCES assets(id),
    quantity      NUMERIC(18, 8)
);

-- ==================
-- DOMAIN 6: EDTECH
-- ==================

CREATE TABLE courses (
    id             SERIAL PRIMARY KEY,
    instructor_id  INT REFERENCES users(id),
    title          VARCHAR(255) NOT NULL,
    category_id    INT REFERENCES categories(id),
    difficulty     INT DEFAULT 1,  -- 1=Beginner, 5=Expert
    rating         NUMERIC(3, 2) DEFAULT 0,
    status         VARCHAR(50) DEFAULT 'published',
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE modules (
    id         SERIAL PRIMARY KEY,
    course_id  INT REFERENCES courses(id),
    title      VARCHAR(255),
    position   INT
);

CREATE TABLE lessons (
    id         SERIAL PRIMARY KEY,
    module_id  INT REFERENCES modules(id),
    course_id  INT REFERENCES courses(id),
    title      VARCHAR(255),
    duration   INT  -- seconds
);

CREATE TABLE enrollments (
    id              SERIAL PRIMARY KEY,
    course_id       INT REFERENCES courses(id),
    user_id         INT REFERENCES users(id),
    payment_amount  NUMERIC(10, 2),
    enrolled_at     TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

CREATE TABLE user_progress (
    id                  SERIAL PRIMARY KEY,
    user_id             INT REFERENCES users(id),
    lesson_id           INT REFERENCES lessons(id),
    status              VARCHAR(50) DEFAULT 'in_progress',
    time_spent_seconds  INT DEFAULT 0,
    completed_at        TIMESTAMPTZ
);

CREATE TABLE quiz_attempts (
    id          SERIAL PRIMARY KEY,
    user_id     INT REFERENCES users(id),
    lesson_id   INT REFERENCES lessons(id),
    course_id   INT REFERENCES courses(id),
    score       NUMERIC(5, 2),
    attempted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE certificates (
    id          SERIAL PRIMARY KEY,
    user_id     INT REFERENCES users(id),
    course_id   INT REFERENCES courses(id),
    issued_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ===================
-- DOMAIN 7: LOGISTICS
-- ===================

CREATE TABLE carriers (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(255) NOT NULL
);

CREATE TABLE addresses (
    id      SERIAL PRIMARY KEY,
    street  VARCHAR(255),
    city    VARCHAR(100),
    country VARCHAR(100),
    lat     NUMERIC(9, 6),
    lng     NUMERIC(9, 6)
);

CREATE TABLE shipments (
    id                       SERIAL PRIMARY KEY,
    order_id                 INT REFERENCES orders(id),
    carrier                  INT REFERENCES carriers(id),
    origin                   INT REFERENCES addresses(id),
    destination              INT REFERENCES addresses(id),
    destination_address_id   INT REFERENCES addresses(id),
    weight                   NUMERIC(8, 2),
    status                   VARCHAR(50) DEFAULT 'pending',
    estimated_delivery       TIMESTAMPTZ,
    actual_delivery          TIMESTAMPTZ,
    created_at               TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tracking_events (
    id           SERIAL PRIMARY KEY,
    shipment_id  INT REFERENCES shipments(id),
    status       VARCHAR(100),
    location     VARCHAR(255),
    event_time   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE drivers (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(255),
    status       VARCHAR(50) DEFAULT 'available',
    current_lat  NUMERIC(9, 6),
    current_lng  NUMERIC(9, 6)
);

CREATE TABLE customers (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(255),
    email VARCHAR(255)
);

CREATE TABLE deliveries (
    id              SERIAL PRIMARY KEY,
    shipment_id     INT REFERENCES shipments(id),
    driver_id       INT REFERENCES drivers(id),
    zone_id         INT,
    status          VARCHAR(50) DEFAULT 'pending',
    scheduled_date  DATE,
    sequence_order  INT,
    time_window_start TIME,
    time_window_end   TIME
);

CREATE TABLE inventory (
    id                SERIAL PRIMARY KEY,
    product_id        INT REFERENCES products(id),
    warehouse_id      INT,
    quantity          INT DEFAULT 0,
    reserved_quantity INT DEFAULT 0
);

CREATE TABLE pending_orders (
    id            SERIAL PRIMARY KEY,
    product_id    INT REFERENCES products(id),
    warehouse_id  INT,
    quantity      INT
);

-- =======================
-- DOMAIN 8: CONTENT/MEDIA
-- =======================

CREATE TABLE articles (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    body        TEXT,
    status      VARCHAR(50) DEFAULT 'published',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE article_views (
    id          SERIAL PRIMARY KEY,
    article_id  INT REFERENCES articles(id),
    user_id     INT REFERENCES users(id),
    viewed_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE article_shares (
    id          SERIAL PRIMARY KEY,
    article_id  INT REFERENCES articles(id),
    user_id     INT REFERENCES users(id),
    shared_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE videos (
    id           SERIAL PRIMARY KEY,
    creator_id   INT REFERENCES users(id),
    title        VARCHAR(255) NOT NULL,
    transcript   TEXT,
    duration     INT,  -- seconds
    category_id  INT REFERENCES categories(id),
    status       VARCHAR(50) DEFAULT 'published',
    view_count   INT DEFAULT 0,
    published_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE video_tags (
    id        SERIAL PRIMARY KEY,
    video_id  INT REFERENCES videos(id),
    tag_id    INT
);

CREATE TABLE video_views (
    id                SERIAL PRIMARY KEY,
    video_id          INT REFERENCES videos(id),
    user_id           INT REFERENCES users(id),
    revenue_generated NUMERIC(10, 4) DEFAULT 0,
    viewed_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE subscriptions (
    id            SERIAL PRIMARY KEY,
    creator_id    INT REFERENCES users(id),
    subscriber_id INT REFERENCES users(id),
    subscribed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE podcasts (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    description TEXT,
    status      VARCHAR(50) DEFAULT 'published',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE playlist_videos (
    id           SERIAL PRIMARY KEY,
    playlist_id  INT,
    video_id     INT REFERENCES videos(id),
    position     INT
);

CREATE TABLE watch_history (
    id              SERIAL PRIMARY KEY,
    video_id        INT REFERENCES videos(id),
    user_id         INT REFERENCES users(id),
    watch_duration  INT,
    completed       BOOLEAN DEFAULT FALSE,
    watched_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ======================
-- DOMAIN 9: HR/PEOPLE OPS
-- ======================

CREATE TABLE employees (
    id               SERIAL PRIMARY KEY,
    name             VARCHAR(255) NOT NULL,
    email            VARCHAR(255) UNIQUE,
    job_title        VARCHAR(100),
    avatar_url       TEXT,
    department_id    INT REFERENCES departments(id),
    manager_id       INT REFERENCES employees(id),
    employment_type  VARCHAR(50),
    salary           NUMERIC(12, 2),
    bank_account     VARCHAR(50),
    status           VARCHAR(50) DEFAULT 'active',
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE skills (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL
);

CREATE TABLE employee_skills (
    id           SERIAL PRIMARY KEY,
    employee_id  INT REFERENCES employees(id),
    skill_id     INT REFERENCES skills(id),
    proficiency  INT DEFAULT 1  -- 1-5
);

CREATE TABLE performance_reviews (
    id           SERIAL PRIMARY KEY,
    employee_id  INT REFERENCES employees(id),
    score        NUMERIC(4, 2),
    notes        TEXT,
    review_date  DATE
);

CREATE TABLE payroll_periods (
    id          SERIAL PRIMARY KEY,
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    name        VARCHAR(100)
);

CREATE TABLE attendance (
    id             SERIAL PRIMARY KEY,
    employee_id    INT REFERENCES employees(id),
    date           DATE NOT NULL,
    hours_worked   NUMERIC(4, 2),
    overtime_hours NUMERIC(4, 2) DEFAULT 0
);

CREATE TABLE bonuses (
    id           SERIAL PRIMARY KEY,
    employee_id  INT REFERENCES employees(id),
    period_id    INT REFERENCES payroll_periods(id),
    amount       NUMERIC(12, 2)
);

CREATE TABLE deductions (
    id           SERIAL PRIMARY KEY,
    employee_id  INT REFERENCES employees(id),
    period_id    INT REFERENCES payroll_periods(id),
    amount       NUMERIC(12, 2),
    reason       VARCHAR(255)
);

CREATE TABLE candidates (
    id     SERIAL PRIMARY KEY,
    name   VARCHAR(255) NOT NULL,
    email  VARCHAR(255)
);

CREATE TABLE applications (
    id             SERIAL PRIMARY KEY,
    job_id         INT,
    candidate_id   INT REFERENCES candidates(id),
    current_stage  VARCHAR(100),
    applied_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE interview_stages (
    id              SERIAL PRIMARY KEY,
    application_id  INT REFERENCES applications(id),
    stage_name      VARCHAR(100),
    score           NUMERIC(4, 2),
    feedback        TEXT,
    scheduled_at    TIMESTAMPTZ
);

CREATE TABLE leave_policies (
    id               SERIAL PRIMARY KEY,
    leave_type       VARCHAR(100),
    annual_days      INT,
    employment_type  VARCHAR(50)
);

CREATE TABLE leave_requests (
    id           SERIAL PRIMARY KEY,
    employee_id  INT REFERENCES employees(id),
    leave_type   VARCHAR(100),
    start_date   DATE,
    end_date     DATE,
    days         INT,
    status       VARCHAR(50) DEFAULT 'pending'
);

CREATE TABLE leave_adjustments (
    id           SERIAL PRIMARY KEY,
    employee_id  INT REFERENCES employees(id),
    leave_type   VARCHAR(100),
    days         INT,
    reason       VARCHAR(255)
);

-- ============================
-- DOMAIN 10: REAL ESTATE/BOOKING
-- ============================

CREATE TABLE hosts (
    id       SERIAL PRIMARY KEY,
    user_id  INT REFERENCES users(id),
    bio      TEXT
);

CREATE TABLE properties (
    id               SERIAL PRIMARY KEY,
    host_id          INT REFERENCES hosts(id),
    title            VARCHAR(255) NOT NULL,
    city             VARCHAR(100),
    max_guests       INT,
    price_per_night  NUMERIC(10, 2),
    base_price       NUMERIC(10, 2),
    status           VARCHAR(50) DEFAULT 'active',
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE amenities (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL
);

CREATE TABLE property_amenities (
    id           SERIAL PRIMARY KEY,
    property_id  INT REFERENCES properties(id),
    amenity_id   INT REFERENCES amenities(id)
);

CREATE TABLE reviews (
    id           SERIAL PRIMARY KEY,
    property_id  INT REFERENCES properties(id),
    booking_id   INT,
    guest_id     INT REFERENCES users(id),
    rating       NUMERIC(3, 2),
    comment      TEXT,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE bookings (
    id           SERIAL PRIMARY KEY,
    property_id  INT REFERENCES properties(id),
    guest_id     INT REFERENCES users(id),
    check_in     DATE NOT NULL,
    check_out    DATE NOT NULL,
    status       VARCHAR(50) DEFAULT 'pending',
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE blocked_dates (
    id           SERIAL PRIMARY KEY,
    property_id  INT REFERENCES properties(id),
    blocked_date DATE NOT NULL
);

CREATE TABLE pricing_rules (
    id              SERIAL PRIMARY KEY,
    property_id     INT REFERENCES properties(id),
    date_from       DATE,
    date_to         DATE,
    price_override  NUMERIC(10, 2)
);

-- ============================================================
-- RECOMMENDED INDEXES
-- (fixes the missing index anti-patterns from the 50 scenarios)
-- ============================================================

-- E-Commerce
CREATE INDEX idx_orders_user_id         ON orders(user_id);
CREATE INDEX idx_orders_created_at      ON orders(created_at DESC);
CREATE INDEX idx_order_items_order_id   ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_products_name_trgm     ON products USING gin(name gin_trgm_ops);  -- needs pg_trgm
CREATE INDEX idx_carts_user_id          ON carts(user_id);

-- Social Media
CREATE INDEX idx_posts_user_id          ON posts(user_id);
CREATE INDEX idx_posts_created_at       ON posts(created_at DESC);
CREATE INDEX idx_likes_post_id          ON likes(post_id);
CREATE INDEX idx_comments_post_id       ON comments(post_id);
CREATE INDEX idx_follows_follower_id    ON follows(follower_id);
CREATE INDEX idx_notifications_user_id  ON notifications(user_id);
CREATE INDEX idx_users_username_lower   ON users(LOWER(username));  -- fixes LOWER() anti-pattern

-- Healthcare
CREATE INDEX idx_appointments_doctor_id   ON appointments(doctor_id);
CREATE INDEX idx_appointments_patient_id  ON appointments(patient_id);
CREATE INDEX idx_appointments_range       ON appointments(scheduled_at);  -- range scan fix
CREATE INDEX idx_lab_results_doctor_id    ON lab_results(doctor_id);

-- SaaS
CREATE INDEX idx_workspace_members_ws    ON workspace_members(workspace_id);
CREATE INDEX idx_user_activity_user_ws   ON user_activity(user_id, workspace_id);
CREATE INDEX idx_audit_logs_ws_created   ON audit_logs(workspace_id, created_at DESC);  -- composite
CREATE INDEX idx_events_ws_created       ON events(workspace_id, created_at DESC);

-- Fintech
CREATE INDEX idx_transactions_account_id  ON transactions(account_id);
CREATE INDEX idx_transactions_created_at  ON transactions(created_at DESC);
CREATE INDEX idx_loans_user_id            ON loans(user_id);

-- EdTech
CREATE INDEX idx_enrollments_course_id  ON enrollments(course_id);
CREATE INDEX idx_enrollments_user_id    ON enrollments(user_id);
CREATE INDEX idx_user_progress_user_id  ON user_progress(user_id);
CREATE INDEX idx_quiz_attempts_user_id  ON quiz_attempts(user_id);

-- Logistics
CREATE INDEX idx_deliveries_driver_date  ON deliveries(driver_id, scheduled_date);
CREATE INDEX idx_deliveries_zone_date    ON deliveries(zone_id, scheduled_date);
CREATE INDEX idx_shipments_order_id      ON shipments(order_id);

-- Content / Media
CREATE INDEX idx_article_views_recent    ON article_views(article_id, viewed_at DESC);
CREATE INDEX idx_video_views_recent      ON video_views(video_id, viewed_at DESC);
CREATE INDEX idx_articles_search         ON articles USING gin(to_tsvector('english', title || ' ' || body));
CREATE INDEX idx_videos_search           ON videos USING gin(to_tsvector('english', title));

-- HR / People Ops
CREATE INDEX idx_employees_department    ON employees(department_id);
CREATE INDEX idx_employees_manager       ON employees(manager_id);
CREATE INDEX idx_attendance_employee     ON attendance(employee_id, date);
CREATE INDEX idx_leave_requests_employee ON leave_requests(employee_id, leave_type);

-- Real Estate / Booking
CREATE INDEX idx_bookings_property_id    ON bookings(property_id);
CREATE INDEX idx_bookings_check_in       ON bookings(check_in, check_out);
CREATE INDEX idx_properties_city         ON properties(city);
CREATE INDEX idx_reviews_property_id     ON reviews(property_id);
