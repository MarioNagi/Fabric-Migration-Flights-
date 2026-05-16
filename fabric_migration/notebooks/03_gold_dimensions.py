# Fabric notebook — 03_gold_dimensions
# Builds gold dim_carrier and dim_airport using deterministic SHA-256 hash keys.
#
# Why hash keys: the same business key produces the same surrogate everywhere.
# No more "what was the last ID in the on-prem warehouse?" — that question
# becomes meaningless. See docs/adr/0001-hash-keys-over-identity.md.

from pyspark.sql import functions as F

LAKEHOUSE = "FlightDataLakehouse"
WAREHOUSE = "FlightDataWarehouse"
SILVER    = f"{LAKEHOUSE}.silver_flights"

silver = spark.table(SILVER)

def sha256_hex(col):
    return F.sha2(F.upper(F.trim(F.col(col))), 256)

# ---------- DimCarrier (SCD2) -----------------------------------------------
carrier_lookup = spark.createDataFrame([
    ("AA","American Airlines","Major","USA"),
    ("AS","Alaska Airlines","Major","USA"),
    ("B6","JetBlue Airways","Major","USA"),
    ("DL","Delta Air Lines","Major","USA"),
    ("F9","Frontier Airlines","Low-Cost","USA"),
    ("G4","Allegiant Air","Low-Cost","USA"),
    ("HA","Hawaiian Airlines","Major","USA"),
    ("MQ","Envoy Air","Regional","USA"),
    ("NK","Spirit Airlines","Low-Cost","USA"),
    ("OH","PSA Airlines","Regional","USA"),
    ("OO","SkyWest Airlines","Regional","USA"),
    ("UA","United Airlines","Major","USA"),
    ("WN","Southwest Airlines","Major","USA"),
    ("YX","Republic Airways","Regional","USA"),
    ("9E","Endeavor Air","Regional","USA"),
], ["CarrierCode","CarrierName","CarrierType","Country"])

dim_carrier = (
    carrier_lookup
    .withColumn("CarrierHK",  sha256_hex("CarrierCode"))
    .withColumn("ValidFrom",  F.lit("2020-01-01").cast("timestamp"))
    .withColumn("ValidTo",    F.lit(None).cast("timestamp"))
    .withColumn("IsCurrent",  F.lit(True))
    .withColumn("RecordSource", F.lit("BTS"))
    .withColumn("LoadedAt",   F.current_timestamp())
)

(dim_carrier.write.format("delta").mode("overwrite").saveAsTable(f"{WAREHOUSE}.dim_carrier"))

# ---------- DimAirport (SCD1) -----------------------------------------------
airports = (
    silver.select(F.col("OriginCode").alias("AirportCode"),
                  F.col("OriginCity").alias("CityName"))
    .union(silver.select(F.col("DestCode").alias("AirportCode"),
                         F.col("DestCity").alias("CityName")))
    .filter(F.col("AirportCode").isNotNull())
    .dropDuplicates(["AirportCode"])
    .withColumn("AirportHK",   sha256_hex("AirportCode"))
    .withColumn("RecordSource", F.lit("STAGING"))
    .withColumn("LoadedAt",    F.current_timestamp())
)

(airports.write.format("delta").mode("overwrite").saveAsTable(f"{WAREHOUSE}.dim_airport"))

print("dim_carrier rows:", dim_carrier.count(), "| dim_airport rows:", airports.count())
