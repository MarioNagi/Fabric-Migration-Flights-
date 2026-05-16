# Fabric notebook — 04_gold_fact
# Builds gold fact_flight using deterministic hash keys.
# Idempotent MERGE on FlightHK so CDC re-pulls are safe.

from pyspark.sql import functions as F
from delta.tables import DeltaTable

LAKEHOUSE = "FlightDataLakehouse"
WAREHOUSE = "FlightDataWarehouse"
SILVER    = f"{LAKEHOUSE}.silver_flights"
FACT      = f"{WAREHOUSE}.fact_flight"

silver = spark.table(SILVER)

flights = (
    silver
    .withColumn("DateKey",   F.expr("CAST(date_format(FlightDate,'yyyyMMdd') AS INT)"))
    .withColumn("CarrierHK", F.sha2(F.upper(F.trim("CarrierCode")), 256))
    .withColumn("OriginHK",  F.sha2(F.upper(F.trim("OriginCode")), 256))
    .withColumn("DestHK",    F.sha2(F.upper(F.trim("DestCode")), 256))
    .withColumn("FlightHK",  F.sha2(F.concat_ws("|",
        F.col("FlightDate").cast("string"),
        F.col("CarrierCode"), F.col("OriginCode"), F.col("DestCode"),
        F.col("DepTime").cast("string")), 256))
    .select(
        "FlightHK","DateKey","CarrierHK","OriginHK","DestHK",
        F.col("DepTimeT").alias("DepTime"),
        F.col("ArrTimeT").alias("ArrTime"),
        F.col("DepDelay").alias("DepDelayMin"),
        F.col("ArrDelay").alias("ArrDelayMin"),
        "Cancelled","CancellationCode","Diverted",
        F.col("Distance").alias("DistanceMiles"),
        "IsOnTime",
    )
    .withColumn("LoadedAt", F.current_timestamp())
    .withColumn("RecordSource", F.lit("FABRIC"))
)

if not spark.catalog.tableExists(FACT):
    (flights.write.format("delta").partitionBy("DateKey").saveAsTable(FACT))
else:
    target = DeltaTable.forName(spark, FACT)
    (target.alias("t")
        .merge(flights.alias("s"), "t.FlightHK = s.FlightHK")
        .whenMatchedUpdateAll()
        .whenNotMatchedInsertAll()
        .execute())

print("fact rows:", spark.table(FACT).count())
