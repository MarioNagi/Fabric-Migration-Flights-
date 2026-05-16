# Fabric notebook — 01_bronze_ingest
# Lands raw CSVs from the Lakehouse Files area into bronze Delta tables.
# Idempotent: re-running over the same file does not duplicate (overwrite by
# source-file partition).

from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, IntegerType, StringType, DateType,
)

LAKEHOUSE = "FlightDataLakehouse"
BRONZE_TABLE = f"{LAKEHOUSE}.bronze_flights"
RAW_DIR = f"Files/raw_csv"

schema = StructType([
    StructField("Year",            IntegerType(), True),
    StructField("Month",           IntegerType(), True),
    StructField("FlightDate",      DateType(),    True),
    StructField("CarrierCode",     StringType(),  True),
    StructField("OriginAirportID", IntegerType(), True),
    StructField("OriginCode",      StringType(),  True),
    StructField("OriginCity",      StringType(),  True),
    StructField("DestAirportID",   IntegerType(), True),
    StructField("DestCode",        StringType(),  True),
    StructField("DestCity",        StringType(),  True),
    StructField("DepTime",         IntegerType(), True),
    StructField("DepDelay",        IntegerType(), True),
    StructField("ArrTime",         IntegerType(), True),
    StructField("ArrDelay",        IntegerType(), True),
    StructField("Cancelled",       IntegerType(), True),
    StructField("CancellationCode",StringType(),  True),
    StructField("Diverted",        IntegerType(), True),
    StructField("Distance",        IntegerType(), True),
])

df = (
    spark.read
    .option("header", "true")
    .schema(schema)
    .csv(RAW_DIR)
    .withColumn("_source_file", F.input_file_name())
    .withColumn("_loaded_at",   F.current_timestamp())
)

(
    df.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .partitionBy("Year", "Month")
    .saveAsTable(BRONZE_TABLE)
)

print(f"bronze rows: {df.count()}")
