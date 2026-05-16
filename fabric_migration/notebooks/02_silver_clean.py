# Fabric notebook — 02_silver_clean
# Typed, cleansed flights table. Drops duplicates, casts times, computes
# IsOnTime, filters out rows that fail hard DQ rules.

from pyspark.sql import functions as F
from pyspark.sql.window import Window

LAKEHOUSE = "FlightDataLakehouse"
BRONZE = f"{LAKEHOUSE}.bronze_flights"
SILVER = f"{LAKEHOUSE}.silver_flights"
QUARANTINE = f"{LAKEHOUSE}.silver_flights_quarantine"

bronze = spark.table(BRONZE)

def hhmm_to_time(col):
    s = F.lpad(F.col(col).cast("string"), 4, "0")
    return F.expr(f"to_timestamp(substring({s._jc.toString()},1,2) || ':' || substring({s._jc.toString()},3,2), 'HH:mm')").cast("timestamp")

cleaned = (
    bronze
    .withColumn("DepTimeT", F.expr("CASE WHEN DepTime IS NULL OR DepTime = 2400 THEN NULL "
                                   "ELSE to_timestamp(LPAD(CAST(DepTime AS STRING), 4, '0'), 'HHmm') END"))
    .withColumn("ArrTimeT", F.expr("CASE WHEN ArrTime IS NULL OR ArrTime = 2400 THEN NULL "
                                   "ELSE to_timestamp(LPAD(CAST(ArrTime AS STRING), 4, '0'), 'HHmm') END"))
    .withColumn("IsOnTime", F.when((F.col("ArrDelay") < 15) & (F.col("Cancelled") == 0), 1).otherwise(0))
    .withColumn("Cancelled", F.coalesce(F.col("Cancelled"), F.lit(0)))
    .withColumn("Diverted",  F.coalesce(F.col("Diverted"),  F.lit(0)))
)

# Hard-rule failures go to quarantine
hard_pass = cleaned.filter(
    F.col("OriginCode").isNotNull()
    & F.col("DestCode").isNotNull()
    & F.col("FlightDate").isNotNull()
    & F.col("Cancelled").isin(0, 1)
)
quarantine = cleaned.subtract(hard_pass)

(quarantine.write.format("delta").mode("append").saveAsTable(QUARANTINE))

# de-dupe within file by natural key
w = Window.partitionBy("FlightDate", "CarrierCode", "OriginCode", "DestCode", "DepTime") \
          .orderBy(F.col("_loaded_at").desc())
deduped = hard_pass.withColumn("_rn", F.row_number().over(w)).filter(F.col("_rn") == 1).drop("_rn")

(
    deduped.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .partitionBy("Year", "Month")
    .saveAsTable(SILVER)
)

print(f"silver rows: {deduped.count()} | quarantined: {quarantine.count()}")
