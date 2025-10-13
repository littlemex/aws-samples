-- =============================================================================
-- Aurora PostgreSQL - Tenant Schemas Creation
-- =============================================================================
-- Creates tenant schemas and tables for multitenant analytics platform

-- Create Tenant Schemas
CREATE SCHEMA IF NOT EXISTS tenant_a;
CREATE SCHEMA IF NOT EXISTS tenant_b;
CREATE SCHEMA IF NOT EXISTS tenant_c;

-- Tenant A Users Table
CREATE TABLE IF NOT EXISTS tenant_a.users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    registration_date DATE NOT NULL,
    last_login_date TIMESTAMP,
    account_status VARCHAR(20) NOT NULL CHECK (account_status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    subscription_tier VARCHAR(20) NOT NULL CHECK (subscription_tier IN ('free', 'premium', 'enterprise')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tenant B Users Table  
CREATE TABLE IF NOT EXISTS tenant_b.users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    registration_date DATE NOT NULL,
    last_login_date TIMESTAMP,
    account_status VARCHAR(20) NOT NULL CHECK (account_status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    subscription_tier VARCHAR(20) NOT NULL CHECK (subscription_tier IN ('free', 'premium', 'enterprise')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tenant C Users Table
CREATE TABLE IF NOT EXISTS tenant_c.users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    registration_date DATE NOT NULL,
    last_login_date TIMESTAMP,
    account_status VARCHAR(20) NOT NULL CHECK (account_status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    subscription_tier VARCHAR(20) NOT NULL CHECK (subscription_tier IN ('free', 'premium', 'enterprise')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_tenant_a_users_email ON tenant_a.users(email);
CREATE INDEX IF NOT EXISTS idx_tenant_a_users_status ON tenant_a.users(account_status);
CREATE INDEX IF NOT EXISTS idx_tenant_a_users_tier ON tenant_a.users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_tenant_a_users_reg_date ON tenant_a.users(registration_date);

CREATE INDEX IF NOT EXISTS idx_tenant_b_users_email ON tenant_b.users(email);
CREATE INDEX IF NOT EXISTS idx_tenant_b_users_status ON tenant_b.users(account_status);
CREATE INDEX IF NOT EXISTS idx_tenant_b_users_tier ON tenant_b.users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_tenant_b_users_reg_date ON tenant_b.users(registration_date);

CREATE INDEX IF NOT EXISTS idx_tenant_c_users_email ON tenant_c.users(email);
CREATE INDEX IF NOT EXISTS idx_tenant_c_users_status ON tenant_c.users(account_status);
CREATE INDEX IF NOT EXISTS idx_tenant_c_users_tier ON tenant_c.users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_tenant_c_users_reg_date ON tenant_c.users(registration_date);
