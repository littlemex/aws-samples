-- =============================================================================
-- Aurora PostgreSQL - Sample Data Insertion
-- =============================================================================
-- Inserts sample data into tenant tables for testing Zero-ETL integration

-- Sample data for tenant_a
INSERT INTO tenant_a.users (email, first_name, last_name, registration_date, last_login_date, account_status, subscription_tier) VALUES
('john.doe@tenant-a.com', 'John', 'Doe', '2024-01-15', '2024-10-10 14:30:00', 'ACTIVE', 'premium'),
('jane.smith@tenant-a.com', 'Jane', 'Smith', '2024-02-20', '2024-10-09 09:15:00', 'ACTIVE', 'free'),
('bob.wilson@tenant-a.com', 'Bob', 'Wilson', '2024-03-10', '2024-10-08 16:45:00', 'INACTIVE', 'enterprise'),
('alice.brown@tenant-a.com', 'Alice', 'Brown', '2024-04-05', '2024-10-11 11:20:00', 'ACTIVE', 'premium'),
('charlie.davis@tenant-a.com', 'Charlie', 'Davis', '2024-05-12', '2024-10-07 13:10:00', 'SUSPENDED', 'free')
ON CONFLICT (email) DO NOTHING;

-- Sample data for tenant_b
INSERT INTO tenant_b.users (email, first_name, last_name, registration_date, last_login_date, account_status, subscription_tier) VALUES
('emma.johnson@tenant-b.com', 'Emma', 'Johnson', '2024-01-20', '2024-10-11 08:30:00', 'ACTIVE', 'enterprise'),
('michael.lee@tenant-b.com', 'Michael', 'Lee', '2024-02-15', '2024-10-10 15:45:00', 'ACTIVE', 'premium'),
('sarah.garcia@tenant-b.com', 'Sarah', 'Garcia', '2024-03-22', '2024-10-09 12:20:00', 'INACTIVE', 'free'),
('david.martinez@tenant-b.com', 'David', 'Martinez', '2024-04-18', '2024-10-11 10:10:00', 'ACTIVE', 'enterprise'),
('lisa.anderson@tenant-b.com', 'Lisa', 'Anderson', '2024-05-25', '2024-10-08 17:30:00', 'ACTIVE', 'premium')
ON CONFLICT (email) DO NOTHING;

-- Sample data for tenant_c
INSERT INTO tenant_c.users (email, first_name, last_name, registration_date, last_login_date, account_status, subscription_tier) VALUES
('alex.taylor@tenant-c.com', 'Alex', 'Taylor', '2024-02-01', '2024-10-11 09:45:00', 'ACTIVE', 'free'),
('rachel.thomas@tenant-c.com', 'Rachel', 'Thomas', '2024-03-15', '2024-10-10 14:15:00', 'ACTIVE', 'premium'),
('kevin.white@tenant-c.com', 'Kevin', 'White', '2024-04-08', '2024-10-09 11:30:00', 'SUSPENDED', 'enterprise'),
('maria.rodriguez@tenant-c.com', 'Maria', 'Rodriguez', '2024-05-20', '2024-10-11 16:20:00', 'ACTIVE', 'premium'),
('james.clark@tenant-c.com', 'James', 'Clark', '2024-06-10', '2024-10-08 08:45:00', 'INACTIVE', 'free')
ON CONFLICT (email) DO NOTHING;
