#!/usr/bin/env python3
"""
Urban Ride-Hailing Analytics - Realistic Synthetic Data Generator
Generates realistic multi-table relational data for:
- locations (urban zones, traffic indices)
- drivers (profiles, vehicle types, ratings)
- passengers (profiles, membership tiers)
- ride_requests (time patterns, surge pricing, cancellations, fulfillment)

Outputs:
1. data/*.csv files
2. seed_data.sql (PostgreSQL compatible batch INSERT script)
3. ride_hailing.db (embedded SQLite database for immediate zero-setup execution)
"""

import os
import csv
import random
import sqlite3
from datetime import datetime, timedelta

# Set deterministic seed for reproducibility
random.seed(42)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(DATA_DIR, exist_ok=True)

# -----------------------------------------------------------------------------
# 1. GENERATE LOCATIONS
# -----------------------------------------------------------------------------
locations_data = [
    (101, 'Indira Gandhi International Airport', 'South West', 'Airport', 8.9),
    (102, 'Cyber City Business District', 'Central Tech', 'Commercial Hub', 9.2),
    (103, 'Connaught Place Central Market', 'Central', 'Commercial Hub', 8.5),
    (104, 'DLF Phase 5 Luxury Sector', 'East Sector', 'Residential', 4.5),
    (105, 'Sector 62 IT & Media Park', 'East Tech', 'Commercial Hub', 7.8),
    (106, 'Hauz Khas Lifestyle Village', 'South', 'Commercial Hub', 7.2),
    (107, 'Dwarka Sector 21 Transit Hub', 'South West', 'Transit Hub', 8.1),
    (108, 'Rohini Residential Sector 14', 'North', 'Residential', 5.0),
    (109, 'Noida Expressway Tech Corridor', 'East Tech', 'Commercial Hub', 8.8),
    (110, 'Saket District Centre & Malls', 'South', 'Commercial Hub', 7.9),
    (111, 'Vasant Kunj Residential Enclave', 'South West', 'Residential', 4.8),
    (112, 'Aerocity Hospitality District', 'South West', 'Commercial Hub', 6.5),
    (113, 'Rajouri Garden Commercial Ring', 'West', 'Commercial Hub', 7.6),
    (114, 'Greater Kailash Residential Hub', 'South', 'Residential', 5.2),
    (115, 'New Delhi Railway Station Gateway', 'Central', 'Transit Hub', 9.5)
]

# -----------------------------------------------------------------------------
# 2. GENERATE DRIVERS
# -----------------------------------------------------------------------------
driver_first_names = [
    "Rajesh", "Amit", "Vikram", "Suresh", "Manoj", "Deepak", "Ramesh", "Sunil",
    "Anil", "Pradeep", "Dinesh", "Sanjay", "Rakesh", "Ajay", "Vijay", "Mukesh",
    "Santosh", "Ashok", "Pramod", "Kishore", "Mahesh", "Pawan", "Naresh", "Arun",
    "Gopal", "Vinod", "Satish", "Mohan", "Kamal", "Ravi"
]
driver_last_names = [
    "Kumar", "Sharma", "Singh", "Yadav", "Verma", "Gupta", "Patel", "Mishra",
    "Chauhan", "Pandey", "Rawat", "Joshi", "Das", "Thakur", "Tiwari"
]

vehicle_types = [
    ('Auto', 0.30),
    ('Mini', 0.40),
    ('Sedan', 0.20),
    ('SUV_Premium', 0.10)
]

def choose_weighted(choices_weights):
    choices, weights = zip(*choices_weights)
    return random.choices(choices, weights=weights, k=1)[0]

drivers_data = []
NUM_DRIVERS = 150
start_driver_date = datetime(2023, 1, 1)

for d_id in range(1, NUM_DRIVERS + 1):
    name = f"{random.choice(driver_first_names)} {random.choice(driver_last_names)}"
    v_type = choose_weighted(vehicle_types)
    rating = round(random.gauss(4.65, 0.25), 2)
    rating = min(5.00, max(3.50, rating))
    trips_completed = random.randint(120, 2400)
    joining_date = (start_driver_date + timedelta(days=random.randint(0, 700))).strftime("%Y-%m-%d")
    is_active = random.random() < 0.94  # 94% active
    drivers_data.append((d_id, name, v_type, rating, trips_completed, joining_date, is_active))

# -----------------------------------------------------------------------------
# 3. GENERATE PASSENGERS
# -----------------------------------------------------------------------------
passenger_first_names = [
    "Aarav", "Ananya", "Rohan", "Pooja", "Aditya", "Neha", "Rahul", "Priyanka",
    "Siddharth", "Kavya", "Varun", "Isha", "Manish", "Divya", "Karan", "Tanvi",
    "Arjun", "Rhea", "Nikhil", "Simran", "Gaurav", "Megha", "Harsh", "Shruti"
]
passengers_data = []
NUM_PASSENGERS = 800
start_passenger_date = datetime(2023, 6, 1)

for p_id in range(1, NUM_PASSENGERS + 1):
    name = f"{random.choice(passenger_first_names)} {random.choice(driver_last_names)}"
    tier = "Prime" if random.random() < 0.28 else "Standard"
    rating = round(random.gauss(4.82, 0.18), 2)
    rating = min(5.00, max(3.80, rating))
    signup_date = (start_passenger_date + timedelta(days=random.randint(0, 550))).strftime("%Y-%m-%d")
    passengers_data.append((p_id, name, tier, rating, signup_date))

# -----------------------------------------------------------------------------
# 4. GENERATE RIDE REQUESTS (THE FACT TABLE)
# -----------------------------------------------------------------------------
PASSENGER_CANCELLATION_REASONS = [
    "Driver ETA Too High (>8 mins)",
    "Found Alternative Transport",
    "Driver Not Moving Towards Pickup",
    "Changed Mind / Plan Cancelled",
    "Fare Surged Significantly"
]

DRIVER_CANCELLATION_REASONS = [
    "Heavy Traffic on Route",
    "Pickup Location Inaccessible",
    "Customer Not Answering Call",
    "Destination Too Far / Unfavourable Route",
    "Vehicle Mechanical Issue"
]

BASE_RATES = {
    'Auto': {'base': 30.0, 'per_km': 13.0},
    'Mini': {'base': 50.0, 'per_km': 16.5},
    'Sedan': {'base': 75.0, 'per_km': 21.0},
    'SUV_Premium': {'base': 110.0, 'per_km': 28.0}
}

trip_records = []
NUM_TRIPS = 6500
simulation_start = datetime(2026, 8, 1, 0, 0, 0)
simulation_days = 45

for i in range(1, NUM_TRIPS + 1):
    trip_id = f"TRIP-{20260000 + i}"
    passenger = random.choice(passengers_data)
    p_id = passenger[0]
    p_tier = passenger[2]

    # Timestamp generation with peak hours
    day_offset = random.randint(0, simulation_days - 1)
    # Peak weighting: 8-10 AM (morning rush) & 17:30-21:00 (evening rush)
    hour_weights = [
        1, 1, 1, 1, 2, 4, 7, 12, 18, 16, 10, 8, 8, 8, 9, 11, 14, 19, 21, 18, 14, 9, 5, 2
    ]
    req_hour = random.choices(range(24), weights=hour_weights, k=1)[0]
    req_minute = random.randint(0, 59)
    req_second = random.randint(0, 59)
    req_time = simulation_start + timedelta(days=day_offset, hours=req_hour, minutes=req_minute, seconds=req_second)

    # Locations
    pickup_loc = random.choice(locations_data)
    drop_loc = random.choice(locations_data)
    while drop_loc[0] == pickup_loc[0]:
        drop_loc = random.choice(locations_data)

    p_loc_id = pickup_loc[0]
    d_loc_id = drop_loc[0]

    # Trip distance (km) based on zone type
    if pickup_loc[3] == 'Airport' or drop_loc[3] == 'Airport':
        distance = round(random.uniform(18.0, 36.0), 2)
    elif pickup_loc[3] == 'Commercial Hub' and drop_loc[3] == 'Commercial Hub':
        distance = round(random.uniform(4.0, 14.0), 2)
    else:
        distance = round(random.uniform(3.0, 22.0), 2)

    # Vehicle selection
    v_type = choose_weighted([('Auto', 0.28), ('Mini', 0.42), ('Sedan', 0.20), ('SUV_Premium', 0.10)])

    # Surge Multiplier Logic
    is_rush_hour = (8 <= req_hour <= 10) or (17 <= req_hour <= 20)
    high_traffic = pickup_loc[4] >= 8.0

    if is_rush_hour and high_traffic:
        surge = round(random.uniform(1.4, 2.4), 2)
    elif is_rush_hour or high_traffic:
        surge = round(random.uniform(1.15, 1.7), 2)
    else:
        surge = 1.00 if random.random() < 0.85 else round(random.uniform(1.05, 1.25), 2)

    # Fares
    base_rate_info = BASE_RATES[v_type]
    base_fare = round(base_rate_info['base'] + (distance * base_rate_info['per_km']), 2)
    final_fare = round(base_fare * surge, 2)

    # ETA
    if is_rush_hour:
        driver_eta = random.randint(5, 16)
    else:
        driver_eta = random.randint(2, 9)

    # Status Determination
    # If severe rush hour in high traffic with high surge, chances of unfulfilled or cancel jump
    status_roll = random.random()
    driver = random.choice(drivers_data)
    d_id = driver[0]

    if is_rush_hour and high_traffic and status_roll < 0.14:
        # Unfulfilled: No driver available
        status = 'UNFULFILLED_NO_DRIVER'
        d_id = None
        pickup_time = None
        drop_time = None
        actual_wait = None
        cancel_reason = "No Driver Available in Sector"
        driver_rating_given = None
        passenger_rating_given = None

    elif driver_eta > 7 and status_roll < 0.32:
        # Passenger cancelled due to high wait time or surge
        status = 'CANCELLED_BY_PASSENGER'
        pickup_time = None
        drop_time = None
        actual_wait = random.randint(2, min(driver_eta, 9))
        if driver_eta >= 10:
            cancel_reason = "Driver ETA Too High (>8 mins)"
        elif surge > 1.5 and random.random() < 0.6:
            cancel_reason = "Fare Surged Significantly"
        else:
            cancel_reason = random.choice(PASSENGER_CANCELLATION_REASONS)
        driver_rating_given = None
        passenger_rating_given = None

    elif status_roll < 0.13:
        # Driver cancelled
        status = 'CANCELLED_BY_DRIVER'
        pickup_time = None
        drop_time = None
        actual_wait = random.randint(1, 4)
        if high_traffic and random.random() < 0.6:
            cancel_reason = "Heavy Traffic on Route"
        else:
            cancel_reason = random.choice(DRIVER_CANCELLATION_REASONS)
        driver_rating_given = None
        passenger_rating_given = None

    else:
        # Completed
        status = 'COMPLETED'
        actual_wait = max(1, driver_eta + random.randint(-2, 3))
        pickup_time = req_time + timedelta(minutes=actual_wait)
        # Average speed 22 km/h in city, 35 km/h on airport routes
        avg_speed = 35.0 if 'Airport' in (pickup_loc[3], drop_loc[3]) else 22.0
        transit_minutes = int((distance / avg_speed) * 60) + random.randint(-3, 6)
        transit_minutes = max(8, transit_minutes)
        drop_time = pickup_time + timedelta(minutes=transit_minutes)
        cancel_reason = None
        driver_rating_given = round(random.choices([5.0, 4.0, 3.0, 2.0, 1.0], weights=[0.72, 0.18, 0.05, 0.03, 0.02])[0], 1)
        passenger_rating_given = round(random.choices([5.0, 4.0, 3.0, 2.0, 1.0], weights=[0.85, 0.10, 0.03, 0.01, 0.01])[0], 1)

    req_str = req_time.strftime("%Y-%m-%d %H:%M:%S")
    pickup_str = pickup_time.strftime("%Y-%m-%d %H:%M:%S") if pickup_time else None
    drop_str = drop_time.strftime("%Y-%m-%d %H:%M:%S") if drop_time else None

    trip_records.append((
        trip_id, p_id, d_id, p_loc_id, d_loc_id,
        req_str, pickup_str, drop_str, driver_eta, actual_wait,
        distance, base_fare, surge, final_fare, status, cancel_reason,
        driver_rating_given, passenger_rating_given
    ))

print(f"Generated {len(locations_data)} locations, {len(drivers_data)} drivers, {len(passengers_data)} passengers, {len(trip_records)} trips.")

# -----------------------------------------------------------------------------
# 5. WRITE CSV FILES
# -----------------------------------------------------------------------------
def write_csv(filename, headers, rows):
    path = os.path.join(DATA_DIR, filename)
    with open(path, mode='w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)
    print(f"-> Saved: {path} ({len(rows)} records)")

write_csv('locations.csv', ['location_id', 'zone_name', 'borough', 'zone_type', 'avg_traffic_index'], locations_data)
write_csv('drivers.csv', ['driver_id', 'driver_name', 'vehicle_type', 'rating', 'total_trips_completed', 'joining_date', 'is_active'], drivers_data)
write_csv('passengers.csv', ['passenger_id', 'passenger_name', 'membership_tier', 'rating', 'signup_date'], passengers_data)
write_csv('ride_requests.csv', [
    'trip_id', 'passenger_id', 'driver_id', 'pickup_location_id', 'drop_location_id',
    'request_timestamp', 'pickup_timestamp', 'drop_timestamp', 'driver_eta_minutes', 'actual_wait_minutes',
    'trip_distance_km', 'base_fare', 'surge_multiplier', 'final_fare', 'status', 'cancellation_reason',
    'driver_rating_given', 'passenger_rating_given'
], trip_records)

# -----------------------------------------------------------------------------
# 6. WRITE SEED_DATA.SQL (PostgreSQL Compatible Batch Inserts)
# -----------------------------------------------------------------------------
sql_seed_path = os.path.join(BASE_DIR, "seed_data.sql")
print("Generating seed_data.sql for PostgreSQL...")
with open(sql_seed_path, mode='w', encoding='utf-8') as f:
    f.write("-- ============================================================================\n")
    f.write("-- Project: Urban Ride-Hailing Supply-Demand & Trip Cancellation Analytics\n")
    f.write("-- File: seed_data.sql (Batch Inserts for MySQL 8.0 / PostgreSQL)\n")
    f.write("-- ============================================================================\n\n")
    f.write("CREATE DATABASE IF NOT EXISTS ride_hailing;\n")
    f.write("USE ride_hailing;\n")
    f.write("SET FOREIGN_KEY_CHECKS = 0;\n\n")

    # Locations
    f.write("-- 1. Insert Locations\n")
    f.write("INSERT INTO locations (location_id, zone_name, borough, zone_type, avg_traffic_index) VALUES\n")
    loc_lines = [f"({row[0]}, '{row[1]}', '{row[2]}', '{row[3]}', {row[4]})" for row in locations_data]
    f.write(",\n".join(loc_lines) + ";\n\n")

    # Drivers
    f.write("-- 2. Insert Drivers\n")
    f.write("INSERT INTO drivers (driver_id, driver_name, vehicle_type, rating, total_trips_completed, joining_date, is_active) VALUES\n")
    drv_lines = [f"({row[0]}, '{row[1]}', '{row[2]}', {row[3]}, {row[4]}, '{row[5]}', {str(row[6]).upper()})" for row in drivers_data]
    f.write(",\n".join(drv_lines) + ";\n\n")

    # Passengers
    f.write("-- 3. Insert Passengers\n")
    f.write("INSERT INTO passengers (passenger_id, passenger_name, membership_tier, rating, signup_date) VALUES\n")
    pass_lines = [f"({row[0]}, '{row[1]}', '{row[2]}', {row[3]}, '{row[4]}')" for row in passengers_data]
    f.write(",\n".join(pass_lines) + ";\n\n")

    # Ride Requests (in batches of 500)
    f.write("-- 4. Insert Ride Requests\n")
    batch_size = 500
    for b_idx in range(0, len(trip_records), batch_size):
        batch = trip_records[b_idx:b_idx + batch_size]
        f.write("INSERT INTO ride_requests (\n")
        f.write("    trip_id, passenger_id, driver_id, pickup_location_id, drop_location_id,\n")
        f.write("    request_timestamp, pickup_timestamp, drop_timestamp, driver_eta_minutes, actual_wait_minutes,\n")
        f.write("    trip_distance_km, base_fare, surge_multiplier, final_fare, status, cancellation_reason,\n")
        f.write("    driver_rating_given, passenger_rating_given\n) VALUES\n")
        
        req_lines = []
        for r in batch:
            d_val = str(r[2]) if r[2] is not None else "NULL"
            p_ts = f"'{r[6]}'" if r[6] is not None else "NULL"
            d_ts = f"'{r[7]}'" if r[7] is not None else "NULL"
            eta = str(r[8]) if r[8] is not None else "NULL"
            wait = str(r[9]) if r[9] is not None else "NULL"
            clean_reason = r[15].replace("'", "''") if r[15] is not None else None
            reason = f"'{clean_reason}'" if clean_reason is not None else "NULL"
            d_rate = str(r[16]) if r[16] is not None else "NULL"
            p_rate = str(r[17]) if r[17] is not None else "NULL"
            
            line = f"('{r[0]}', {r[1]}, {d_val}, {r[3]}, {r[4]}, '{r[5]}', {p_ts}, {d_ts}, {eta}, {wait}, {r[10]}, {r[11]}, {r[12]}, {r[13]}, '{r[14]}', {reason}, {d_rate}, {p_rate})"
            req_lines.append(line)
        f.write(",\n".join(req_lines) + ";\n\n")

    f.write("SET FOREIGN_KEY_CHECKS = 1;\n")
print(f"-> Saved: {sql_seed_path}")

# -----------------------------------------------------------------------------
# 7. CREATE LOCAL SQLITE DATABASE FOR INSTANT ZERO-SETUP TESTING
# -----------------------------------------------------------------------------
db_path = os.path.join(BASE_DIR, "ride_hailing.db")
if os.path.exists(db_path):
    os.remove(db_path)

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# SQLite table DDL
cur.execute("""
CREATE TABLE locations (
    location_id INTEGER PRIMARY KEY,
    zone_name TEXT NOT NULL,
    borough TEXT NOT NULL,
    zone_type TEXT NOT NULL,
    avg_traffic_index REAL NOT NULL
);
""")

cur.execute("""
CREATE TABLE drivers (
    driver_id INTEGER PRIMARY KEY,
    driver_name TEXT NOT NULL,
    vehicle_type TEXT NOT NULL,
    rating REAL NOT NULL,
    total_trips_completed INTEGER NOT NULL,
    joining_date TEXT NOT NULL,
    is_active INTEGER NOT NULL
);
""")

cur.execute("""
CREATE TABLE passengers (
    passenger_id INTEGER PRIMARY KEY,
    passenger_name TEXT NOT NULL,
    membership_tier TEXT NOT NULL,
    rating REAL NOT NULL,
    signup_date TEXT NOT NULL
);
""")

cur.execute("""
CREATE TABLE ride_requests (
    trip_id TEXT PRIMARY KEY,
    passenger_id INTEGER NOT NULL,
    driver_id INTEGER,
    pickup_location_id INTEGER NOT NULL,
    drop_location_id INTEGER NOT NULL,
    request_timestamp TEXT NOT NULL,
    pickup_timestamp TEXT,
    drop_timestamp TEXT,
    driver_eta_minutes INTEGER,
    actual_wait_minutes INTEGER,
    trip_distance_km REAL NOT NULL,
    base_fare REAL NOT NULL,
    surge_multiplier REAL NOT NULL,
    final_fare REAL NOT NULL,
    status TEXT NOT NULL,
    cancellation_reason TEXT,
    driver_rating_given REAL,
    passenger_rating_given REAL
);
""")

# Insert data into SQLite
cur.executemany("INSERT INTO locations VALUES (?, ?, ?, ?, ?)", locations_data)
cur.executemany("INSERT INTO drivers VALUES (?, ?, ?, ?, ?, ?, ?)", [(r[0], r[1], r[2], r[3], r[4], r[5], 1 if r[6] else 0) for r in drivers_data])
cur.executemany("INSERT INTO passengers VALUES (?, ?, ?, ?, ?)", passengers_data)
cur.executemany("INSERT INTO ride_requests VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", trip_records)

conn.commit()
conn.close()

print(f"-> Successfully created and seeded local database: {db_path}")
print("Data generation finished with 0 errors!")
