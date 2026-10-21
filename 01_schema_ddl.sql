-- ============================================================================
-- Project: Urban Ride-Hailing Supply-Demand & Trip Cancellation Analytics
-- Database Engine: MySQL 8.0+ / PostgreSQL Compatible
-- File: 01_schema_ddl.sql
-- Description: Creates the ride_hailing database, 4 normalized relational
-- tables, primary keys, foreign keys, check constraints, and performance indexes.
-- ============================================================================

-- Create and switch to project database
CREATE DATABASE IF NOT EXISTS ride_hailing;
USE ride_hailing;

-- Temporarily disable foreign key checks to allow safe recreation
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS ride_requests;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS passengers;
DROP TABLE IF EXISTS locations;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 1. LOCATIONS TABLE
-- Master table storing urban micro-zones, sectors, and traffic profiles
-- ----------------------------------------------------------------------------
CREATE TABLE locations (
    location_id INT PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL,
    borough VARCHAR(50) NOT NULL,
    zone_type VARCHAR(30) NOT NULL,
    avg_traffic_index DECIMAL(3, 1) NOT NULL,
    CONSTRAINT chk_zone_type CHECK (zone_type IN ('Airport', 'Commercial Hub', 'Residential', 'Suburban', 'Transit Hub')),
    CONSTRAINT chk_traffic_index CHECK (avg_traffic_index BETWEEN 1.0 AND 10.0)
);

-- ----------------------------------------------------------------------------
-- 2. DRIVERS TABLE
-- Driver partners, vehicle categories, ratings, and active statuses
-- ----------------------------------------------------------------------------
CREATE TABLE drivers (
    driver_id INT PRIMARY KEY,
    driver_name VARCHAR(100) NOT NULL,
    vehicle_type VARCHAR(30) NOT NULL,
    rating DECIMAL(3, 2) NOT NULL,
    total_trips_completed INT NOT NULL DEFAULT 0,
    joining_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_vehicle_type CHECK (vehicle_type IN ('Auto', 'Mini', 'Sedan', 'SUV_Premium')),
    CONSTRAINT chk_driver_rating CHECK (rating BETWEEN 1.00 AND 5.00),
    CONSTRAINT chk_trips_completed CHECK (total_trips_completed >= 0)
);

-- ----------------------------------------------------------------------------
-- 3. PASSENGERS TABLE
-- Customer profiles, loyalty tiers (Prime vs. Standard), and ratings
-- ----------------------------------------------------------------------------
CREATE TABLE passengers (
    passenger_id INT PRIMARY KEY,
    passenger_name VARCHAR(100) NOT NULL,
    membership_tier VARCHAR(20) NOT NULL,
    rating DECIMAL(3, 2) NOT NULL,
    signup_date DATE NOT NULL,
    CONSTRAINT chk_tier CHECK (membership_tier IN ('Standard', 'Prime')),
    CONSTRAINT chk_passenger_rating CHECK (rating BETWEEN 1.00 AND 5.00)
);

-- ----------------------------------------------------------------------------
-- 4. RIDE_REQUESTS TABLE (Core Fact Table)
-- Captures the lifecycle of every trip request from dispatch to completion/cancellation
-- ----------------------------------------------------------------------------
CREATE TABLE ride_requests (
    trip_id VARCHAR(36) PRIMARY KEY,
    passenger_id INT NOT NULL,
    driver_id INT,
    pickup_location_id INT NOT NULL,
    drop_location_id INT NOT NULL,
    request_timestamp DATETIME NOT NULL,
    pickup_timestamp DATETIME,
    drop_timestamp DATETIME,
    driver_eta_minutes INT,
    actual_wait_minutes INT,
    trip_distance_km DECIMAL(5, 2) NOT NULL,
    base_fare DECIMAL(8, 2) NOT NULL,
    surge_multiplier DECIMAL(3, 2) NOT NULL DEFAULT 1.00,
    final_fare DECIMAL(8, 2) NOT NULL,
    status VARCHAR(30) NOT NULL,
    cancellation_reason VARCHAR(150),
    driver_rating_given DECIMAL(2, 1),
    passenger_rating_given DECIMAL(2, 1),
    CONSTRAINT fk_req_passenger FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id),
    CONSTRAINT fk_req_driver FOREIGN KEY (driver_id) REFERENCES drivers(driver_id) ON DELETE SET NULL,
    CONSTRAINT fk_req_pickup FOREIGN KEY (pickup_location_id) REFERENCES locations(location_id),
    CONSTRAINT fk_req_drop FOREIGN KEY (drop_location_id) REFERENCES locations(location_id),
    CONSTRAINT chk_req_distance CHECK (trip_distance_km > 0),
    CONSTRAINT chk_req_base_fare CHECK (base_fare >= 0),
    CONSTRAINT chk_req_surge CHECK (surge_multiplier >= 1.00),
    CONSTRAINT chk_req_final_fare CHECK (final_fare >= 0),
    CONSTRAINT chk_req_status CHECK (status IN ('COMPLETED', 'CANCELLED_BY_PASSENGER', 'CANCELLED_BY_DRIVER', 'UNFULFILLED_NO_DRIVER'))
);

-- ----------------------------------------------------------------------------
-- PERFORMANCE INDEXES
-- Indexing high-frequency filter and join columns for query optimization
-- ----------------------------------------------------------------------------
CREATE INDEX idx_requests_request_time ON ride_requests(request_timestamp);
CREATE INDEX idx_requests_status ON ride_requests(status);
CREATE INDEX idx_requests_pickup_loc ON ride_requests(pickup_location_id);
CREATE INDEX idx_requests_driver_id ON ride_requests(driver_id);
CREATE INDEX idx_requests_passenger_id ON ride_requests(passenger_id);
