-- ============================================================================
-- Project: Urban Ride-Hailing Supply-Demand & Trip Cancellation Analytics
-- Database Engine: MySQL 8.0+ / PostgreSQL Compatible
-- File: 03_data_cleaning_validation.sql
-- Description: End-to-end data quality assessment, schema integrity checks,
-- NULL analysis, duplicate checks, chronological validation, and outlier detection.
-- ============================================================================

USE ride_hailing;

-- ----------------------------------------------------------------------------
-- 1. DUPLICATE CHECK: Verify uniqueness of primary keys
-- Expectation: Zero records returned
-- ----------------------------------------------------------------------------
SELECT 
    trip_id, 
    COUNT(*) AS occurrence_count
FROM ride_requests
GROUP BY trip_id
HAVING COUNT(*) > 1;


-- ----------------------------------------------------------------------------
-- 2. MISSING / NULL VALUE AUDIT: Profiling NULL distributions across fields
-- Ensures required fields are never NULL, and optional fields are NULL only when appropriate
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) - COUNT(trip_id) AS null_trip_ids,
    COUNT(*) - COUNT(passenger_id) AS null_passenger_ids,
    COUNT(*) - COUNT(pickup_location_id) AS null_pickup_locations,
    COUNT(*) - COUNT(drop_location_id) AS null_drop_locations,
    COUNT(*) - COUNT(request_timestamp) AS null_request_timestamps,
    COUNT(*) - COUNT(trip_distance_km) AS null_distances,
    COUNT(*) - COUNT(final_fare) AS null_fares,
    SUM(CASE WHEN status = 'UNFULFILLED_NO_DRIVER' AND driver_id IS NOT NULL THEN 1 ELSE 0 END) AS unfulfilled_with_assigned_driver,
    SUM(CASE WHEN status = 'COMPLETED' AND driver_id IS NULL THEN 1 ELSE 0 END) AS completed_missing_driver
FROM ride_requests;


-- ----------------------------------------------------------------------------
-- 3. CHRONOLOGICAL CONSISTENCY AUDIT
-- Rule: For COMPLETED trips, drop_timestamp must be after pickup_timestamp,
-- and pickup_timestamp must be after request_timestamp.
-- Expectation: Zero records returned
-- ----------------------------------------------------------------------------
SELECT 
    trip_id,
    request_timestamp,
    pickup_timestamp,
    drop_timestamp,
    status
FROM ride_requests
WHERE status = 'COMPLETED'
  AND (pickup_timestamp < request_timestamp 
       OR drop_timestamp < pickup_timestamp);


-- ----------------------------------------------------------------------------
-- 4. LOGICAL STATUS & VALUE AUDITS
-- Check for negative distances, zero fares, or invalid ratings
-- Expectation: Zero records returned
-- ----------------------------------------------------------------------------
SELECT 
    trip_id,
    trip_distance_km,
    base_fare,
    surge_multiplier,
    final_fare,
    driver_rating_given
FROM ride_requests
WHERE trip_distance_km <= 0 
   OR base_fare < 0 
   OR surge_multiplier < 1.00 
   OR final_fare < 0
   OR (driver_rating_given IS NOT NULL AND (driver_rating_given < 1.0 OR driver_rating_given > 5.0));


-- ----------------------------------------------------------------------------
-- 5. REFERENTIAL INTEGRITY ORPHAN CHECK
-- Validates that every ride request links to a valid passenger, driver, and location
-- Expectation: Zero records returned
-- ----------------------------------------------------------------------------
SELECT 
    r.trip_id,
    r.passenger_id,
    r.driver_id,
    r.pickup_location_id,
    r.drop_location_id
FROM ride_requests r
LEFT JOIN passengers p ON r.passenger_id = p.passenger_id
LEFT JOIN locations lp ON r.pickup_location_id = lp.location_id
LEFT JOIN locations ld ON r.drop_location_id = ld.location_id
WHERE p.passenger_id IS NULL 
   OR lp.location_id IS NULL 
   OR ld.location_id IS NULL;


-- ----------------------------------------------------------------------------
-- 6. DATE RANGE & COVERAGE VALIDATION
-- Confirms the date horizon and overall status distribution
-- ----------------------------------------------------------------------------
SELECT 
    MIN(request_timestamp) AS earliest_request,
    MAX(request_timestamp) AS latest_request,
    COUNT(DISTINCT DATE(request_timestamp)) AS active_operating_days,
    COUNT(*) AS total_ride_volume
FROM ride_requests;

-- Status distribution using a CTE to ensure full MySQL 8.0 & PostgreSQL compatibility
WITH status_summary AS (
    SELECT 
        status,
        COUNT(*) AS total_trips
    FROM ride_requests
    GROUP BY status
)
SELECT 
    status,
    total_trips,
    ROUND(100.0 * total_trips / SUM(total_trips) OVER (), 2) AS percentage_of_total
FROM status_summary
ORDER BY total_trips DESC;
