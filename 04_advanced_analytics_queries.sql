-- ============================================================================
-- Project: Urban Ride-Hailing Supply-Demand & Trip Cancellation Analytics
-- Database Engine: MySQL 8.0+ / PostgreSQL Compatible
-- File: 04_advanced_analytics_queries.sql
-- Description: 8 advanced analytical queries addressing operational bottlenecks,
-- supply-demand deficits, cancellation root causes, surge elasticity, and lost revenue.
-- ============================================================================

USE ride_hailing;

-- ============================================================================
-- QUERY 1: Hourly Supply-Demand Gap & Fulfillment Bottleneck Analysis
-- Business Purpose: Identify the exact hours of the day where rider demand outstrips
-- driver supply, driving high unfulfilled rides and cancellation spikes.
-- Technical Skills: Conditional Aggregations (CASE WHEN), Date/Time extraction, Window Totals
-- ============================================================================
WITH hourly_metrics AS (
    SELECT 
        EXTRACT(HOUR FROM request_timestamp) AS hour_of_day,
        COUNT(*) AS total_ride_requests,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_trips,
        SUM(CASE WHEN status = 'CANCELLED_BY_PASSENGER' THEN 1 ELSE 0 END) AS passenger_cancellations,
        SUM(CASE WHEN status = 'CANCELLED_BY_DRIVER' THEN 1 ELSE 0 END) AS driver_cancellations,
        SUM(CASE WHEN status = 'UNFULFILLED_NO_DRIVER' THEN 1 ELSE 0 END) AS unfulfilled_no_driver,
        ROUND(AVG(surge_multiplier), 2) AS avg_surge_multiplier
    FROM ride_requests
    GROUP BY EXTRACT(HOUR FROM request_timestamp)
)
SELECT 
    hour_of_day,
    total_ride_requests,
    completed_trips,
    passenger_cancellations,
    driver_cancellations,
    unfulfilled_no_driver,
    avg_surge_multiplier,
    ROUND(100.0 * completed_trips / total_ride_requests, 1) AS fulfillment_rate_pct,
    ROUND(100.0 * unfulfilled_no_driver / total_ride_requests, 1) AS unfulfilled_rate_pct,
    CASE 
        WHEN (100.0 * completed_trips / total_ride_requests) < 65.0 THEN 'CRITICAL SUPPLY SHORTAGE'
        WHEN (100.0 * completed_trips / total_ride_requests) < 75.0 THEN 'MODERATE DEFICIT'
        ELSE 'BALANCED'
    END AS zone_health_status
FROM hourly_metrics
ORDER BY hour_of_day ASC;


-- ============================================================================
-- QUERY 2: The "Wait-Time Tipping Point" (Driver ETA vs. Passenger Cancellation)
-- Business Purpose: Discover the exact threshold in minutes where passengers abandon
-- their trip requests due to high driver arrival times.
-- Technical Skills: Interval binning (CASE WHEN), Percentage conversions, Subqueries
-- ============================================================================
WITH eta_binned AS (
    SELECT 
        trip_id,
        status,
        driver_eta_minutes,
        cancellation_reason,
        CASE 
            WHEN driver_eta_minutes BETWEEN 0 AND 3 THEN '01. 0 - 3 mins (Immediate)'
            WHEN driver_eta_minutes BETWEEN 4 AND 6 THEN '02. 4 - 6 mins (Standard)'
            WHEN driver_eta_minutes BETWEEN 7 AND 9 THEN '03. 7 - 9 mins (Elevated)'
            WHEN driver_eta_minutes BETWEEN 10 AND 12 THEN '04. 10 - 12 mins (High)'
            ELSE '05. 13+ mins (Severe)'
        END AS eta_bucket
    FROM ride_requests
    WHERE driver_eta_minutes IS NOT NULL
)
SELECT 
    eta_bucket,
    COUNT(*) AS total_dispatches,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_trips,
    SUM(CASE WHEN status = 'CANCELLED_BY_PASSENGER' THEN 1 ELSE 0 END) AS passenger_cancels,
    ROUND(100.0 * SUM(CASE WHEN status = 'CANCELLED_BY_PASSENGER' THEN 1 ELSE 0 END) / COUNT(*), 2) AS passenger_cancellation_rate_pct,
    SUM(CASE WHEN cancellation_reason = 'Driver ETA Too High (>8 mins)' THEN 1 ELSE 0 END) AS eta_explicit_cancels
FROM eta_binned
GROUP BY eta_bucket
ORDER BY eta_bucket ASC;


-- ============================================================================
-- QUERY 3: Surge Pricing Elasticity & Passenger Drop-Off Analysis
-- Business Purpose: Measure how aggressive surge multipliers affect trip completion
-- rates and whether extreme surge leads to lost business.
-- Technical Skills: Numerical categorization, Multi-column aggregation, Ratio calculations
-- ============================================================================
SELECT 
    CASE 
        WHEN surge_multiplier = 1.00 THEN '1. Baseline Fare (1.0x)'
        WHEN surge_multiplier BETWEEN 1.01 AND 1.30 THEN '2. Moderate Surge (1.1x - 1.3x)'
        WHEN surge_multiplier BETWEEN 1.31 AND 1.70 THEN '3. High Surge (1.4x - 1.7x)'
        ELSE '4. Extreme Surge (1.8x+)'
    END AS surge_tier,
    COUNT(*) AS request_count,
    ROUND(AVG(trip_distance_km), 2) AS avg_distance_km,
    ROUND(AVG(final_fare), 2) AS avg_fare_charged,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_rides,
    ROUND(100.0 * SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS completion_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN cancellation_reason = 'Fare Surged Significantly' THEN 1 ELSE 0 END) / COUNT(*), 2) AS price_shock_cancellation_pct
FROM ride_requests
GROUP BY 
    CASE 
        WHEN surge_multiplier = 1.00 THEN '1. Baseline Fare (1.0x)'
        WHEN surge_multiplier BETWEEN 1.01 AND 1.30 THEN '2. Moderate Surge (1.1x - 1.3x)'
        WHEN surge_multiplier BETWEEN 1.31 AND 1.70 THEN '3. High Surge (1.4x - 1.7x)'
        ELSE '4. Extreme Surge (1.8x+)'
    END
ORDER BY surge_tier ASC;


-- ============================================================================
-- QUERY 4: Top 10 High-Demand Corridors & Estimated Lost Revenue
-- Business Purpose: Quantify unrealized revenue in dollars/rupees lost to unfulfilled
-- trips and cancellations across the busiest origin-destination pairs.
-- Technical Skills: Multi-table Joins, CTEs, Aggregated Financial Loss modeling
-- ============================================================================
WITH route_summary AS (
    SELECT 
        l1.zone_name AS pickup_zone,
        l2.zone_name AS drop_zone,
        COUNT(*) AS total_demand_volume,
        SUM(CASE WHEN r.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_trips,
        SUM(CASE WHEN r.status != 'COMPLETED' THEN 1 ELSE 0 END) AS lost_trips,
        ROUND(SUM(CASE WHEN r.status = 'COMPLETED' THEN r.final_fare ELSE 0 END), 2) AS realized_gross_revenue,
        ROUND(SUM(CASE WHEN r.status != 'COMPLETED' THEN r.final_fare ELSE 0 END), 2) AS estimated_lost_revenue,
        ROUND(AVG(r.final_fare), 2) AS avg_route_fare
    FROM ride_requests r
    JOIN locations l1 ON r.pickup_location_id = l1.location_id
    JOIN locations l2 ON r.drop_location_id = l2.location_id
    GROUP BY l1.zone_name, l2.zone_name
)
SELECT 
    pickup_zone,
    drop_zone,
    total_demand_volume,
    completed_trips,
    lost_trips,
    realized_gross_revenue,
    estimated_lost_revenue,
    ROUND(100.0 * lost_trips / total_demand_volume, 1) AS lost_trip_pct,
    ROUND(100.0 * estimated_lost_revenue / (realized_gross_revenue + estimated_lost_revenue), 1) AS revenue_leakage_pct
FROM route_summary
ORDER BY total_demand_volume DESC
LIMIT 10;


-- ============================================================================
-- QUERY 5: Driver Performance Quartiles & Churn/Coaching Segmentation
-- Business Purpose: Categorize active drivers into 4 performance quartiles based on
-- completed trips, acceptance reliability, and passenger ratings.
-- Technical Skills: Window Functions (NTILE, DENSE_RANK), Partitioning, Statistical Ranking
-- ============================================================================
WITH driver_trip_stats AS (
    SELECT 
        d.driver_id,
        d.driver_name,
        d.vehicle_type,
        d.rating AS driver_lifetime_rating,
        COUNT(r.trip_id) AS total_assigned_requests,
        SUM(CASE WHEN r.status = 'COMPLETED' THEN 1 ELSE 0 END) AS trips_completed,
        SUM(CASE WHEN r.status = 'CANCELLED_BY_DRIVER' THEN 1 ELSE 0 END) AS driver_cancellations,
        ROUND(100.0 * SUM(CASE WHEN r.status = 'COMPLETED' THEN 1 ELSE 0 END) / NULLIF(COUNT(r.trip_id), 0), 1) AS fulfillment_reliability_pct,
        ROUND(AVG(r.passenger_rating_given), 2) AS avg_rating_received
    FROM drivers d
    LEFT JOIN ride_requests r ON d.driver_id = r.driver_id
    WHERE d.is_active = TRUE
    GROUP BY d.driver_id, d.driver_name, d.vehicle_type, d.rating
),
driver_ranked AS (
    SELECT 
        driver_id,
        driver_name,
        vehicle_type,
        driver_lifetime_rating,
        total_assigned_requests,
        trips_completed,
        driver_cancellations,
        fulfillment_reliability_pct,
        avg_rating_received,
        NTILE(4) OVER (ORDER BY trips_completed DESC) AS performance_quartile,
        DENSE_RANK() OVER (ORDER BY trips_completed DESC) AS rank_by_volume
    FROM driver_trip_stats
)
SELECT 
    driver_id,
    driver_name,
    vehicle_type,
    trips_completed,
    driver_cancellations,
    fulfillment_reliability_pct,
    avg_rating_received,
    rank_by_volume,
    CASE 
        WHEN performance_quartile = 1 THEN 'Tier 1 - Top Performer (Incentive Eligible)'
        WHEN performance_quartile = 2 THEN 'Tier 2 - Reliable Core'
        WHEN performance_quartile = 3 THEN 'Tier 3 - Average Performer'
        ELSE 'Tier 4 - High Cancellation / Coaching Required'
    END AS driver_tier_status
FROM driver_ranked
ORDER BY trips_completed DESC
LIMIT 15;


-- ============================================================================
-- QUERY 6: Consecutive Driver Cancellation Detection (Anti-Gaming Audit)
-- Business Purpose: Identify drivers who cancel multiple consecutive rides
-- (cherry-picking trips or artificially inflating wait times).
-- Technical Skills: Window Functions (LAG), Sequential ordering, Fraud / Policy audit
-- ============================================================================
WITH sequential_trips AS (
    SELECT 
        trip_id,
        driver_id,
        request_timestamp,
        status,
        cancellation_reason,
        LAG(status, 1) OVER (PARTITION BY driver_id ORDER BY request_timestamp) AS prev_status_1,
        LAG(status, 2) OVER (PARTITION BY driver_id ORDER BY request_timestamp) AS prev_status_2,
        LAG(request_timestamp, 1) OVER (PARTITION BY driver_id ORDER BY request_timestamp) AS prev_timestamp_1
    FROM ride_requests
    WHERE driver_id IS NOT NULL
)
SELECT 
    s.driver_id,
    d.driver_name,
    d.vehicle_type,
    s.trip_id,
    s.request_timestamp,
    s.status AS current_status,
    s.cancellation_reason AS current_reason,
    s.prev_status_1,
    'Consecutive Rejection Streak' AS policy_violation_flag
FROM sequential_trips s
JOIN drivers d ON s.driver_id = d.driver_id
WHERE s.status = 'CANCELLED_BY_DRIVER' 
  AND s.prev_status_1 = 'CANCELLED_BY_DRIVER'
ORDER BY s.driver_id, s.request_timestamp ASC
LIMIT 15;


-- ============================================================================
-- QUERY 7: Customer Loyalty Cohort Analysis (Prime vs. Standard)
-- Business Purpose: Evaluate customer behavior, lifetime value (LTV), cancellation
-- frequency, and average basket spend across Prime vs. Standard members.
-- Technical Skills: Relational Joins, Grouped Metrics, Comparative Cohort Analysis
-- ============================================================================
SELECT 
    p.membership_tier,
    COUNT(DISTINCT p.passenger_id) AS total_registered_customers,
    COUNT(r.trip_id) AS total_requests_made,
    ROUND(1.0 * COUNT(r.trip_id) / COUNT(DISTINCT p.passenger_id), 1) AS avg_rides_per_user,
    SUM(CASE WHEN r.status = 'COMPLETED' THEN 1 ELSE 0 END) AS total_completed_rides,
    ROUND(100.0 * SUM(CASE WHEN r.status = 'COMPLETED' THEN 1 ELSE 0 END) / COUNT(r.trip_id), 2) AS completion_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN r.status = 'CANCELLED_BY_PASSENGER' THEN 1 ELSE 0 END) / COUNT(r.trip_id), 2) AS passenger_cancel_rate_pct,
    ROUND(AVG(CASE WHEN r.status = 'COMPLETED' THEN r.final_fare ELSE NULL END), 2) AS avg_fare_per_completed_trip,
    ROUND(SUM(CASE WHEN r.status = 'COMPLETED' THEN r.final_fare ELSE 0 END), 2) AS total_gross_merchandise_value
FROM passengers p
LEFT JOIN ride_requests r ON p.passenger_id = r.passenger_id
GROUP BY p.membership_tier
ORDER BY total_gross_merchandise_value DESC;


-- ============================================================================
-- QUERY 8: Weekly Cumulative Running Revenue & Operational Growth Velocity
-- Business Purpose: Track weekly completed GMV and running total revenue over time
-- to measure operational trajectory and service expansion.
-- Technical Skills: Window Functions (SUM OVER), MySQL DATE_SUB/WEEKDAY, Cumulative sums
-- ============================================================================
WITH weekly_revenue AS (
    SELECT 
        DATE(DATE_SUB(request_timestamp, INTERVAL WEEKDAY(request_timestamp) DAY)) AS week_start_date,
        COUNT(*) AS weekly_requests,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS weekly_completed_trips,
        ROUND(SUM(CASE WHEN status = 'COMPLETED' THEN final_fare ELSE 0 END), 2) AS weekly_revenue
    FROM ride_requests
    GROUP BY DATE(DATE_SUB(request_timestamp, INTERVAL WEEKDAY(request_timestamp) DAY))
)
SELECT 
    week_start_date,
    weekly_requests,
    weekly_completed_trips,
    weekly_revenue,
    SUM(weekly_completed_trips) OVER (ORDER BY week_start_date) AS running_total_trips,
    SUM(weekly_revenue) OVER (ORDER BY week_start_date) AS running_total_revenue,
    ROUND(100.0 * weekly_completed_trips / weekly_requests, 1) AS weekly_completion_rate_pct
FROM weekly_revenue
ORDER BY week_start_date ASC;
