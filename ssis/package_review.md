# SSIS package review — `Load_Flights_2024.dtsx`

> Reviewed: 2026-05-11. Package version 8, SSIS for SQL Server 2022.

## Pipeline shape (what's there today)

```
Foreach Loop Container (one .csv at a time, User::FileName)
  └─ DF_Load_Flights (Data Flow)
       ├─ Flat File Source     (all 19 cols as str/wstr len 50, locale 1033, codepage 1252)
       ├─ Derived Column        (TRIM + null-string handling + Cancelled→bool + numeric coercion)
       ├─ Data Conversion       (str→i4/i8/dbDate/wstr/bool to match destination types)
       └─ OLE DB Destination    (dbo.Flights_2024, fast-load, TABLOCK,CHECK_CONSTRAINTS)
```

- **Connection managers:** `CM_FlatFile_Flights` (path = `User::FolderPath` + `User::FileName`), `CM_OLEDB_Staging` (Integrated Security, `MSOLEDBSQL.1`, `Auto Translate=False`).
- **Loop variable:** `User::FileName`, base folder `C:\Users\Mario\python projects\fabric project\raw csv\`.

## What's good

1. **Fast-load is on with `TABLOCK,CHECK_CONSTRAINTS`.** Right call for a single-writer staging load — minimally logged when the recovery model permits.
2. **`Auto Translate=False`** on the OLE DB connection. Avoids implicit codepage conversion on insert.
3. **Foreach loop drives the file iteration**, not a hardcoded path. Adding July/August later just means dropping the file in the folder.
4. **MSOLEDBSQL driver** (not legacy SQLNCLI). Correct for SQL 2019+.
5. **Error outputs are wired** on Flat File Source and Derived Column (FailComponent disposition) — bad rows fail loudly instead of being silently dropped.

## What I'd change (ranked by impact)

### 1. `FastLoadMaxInsertCommitSize = 2147483647` (max int32) — biggest issue

Current setting means **one commit at end of file**. For a 700k-row CSV that's fine. For the full year (~4M rows in a single feed) you risk:
- Huge transaction log growth (you mitigated that with `SIMPLE` recovery — good).
- All-or-nothing failure: one bad row and you re-run the whole file.
- Lock escalation to table-level for the whole insert.

**Recommendation:** set to `100000` (100k rows per commit). That's the SSIS sweet spot for OLE DB Destination on a single-instance SQL Server. Keeps the log manageable and gives you partial progress on failure. Property is on the OLE DB Destination → "Maximum insert commit size".

### 2. Buffer settings are at default

`DefaultBufferMaxRows` (10,000) and `DefaultBufferSize` (10 MB) aren't overridden on the Data Flow Task. For 19 narrow columns (most ints + short strings), the buffer is row-count-bound, not size-bound. You can lift throughput ~2-3x by setting:

- `DefaultBufferMaxRows = 50000`
- `DefaultBufferSize = 67108864` (64 MB — the post-SSIS-2016 upper end)

Set these on the **Data Flow Task** properties, not the package. Verify with `Information: 0x4004800C` messages in the log (buffer-size warnings).

### 3. Two-step transform (Derived Column → Data Conversion) does work twice

You currently:
- Derived Column produces `*_t` columns (mostly `wstr len 50`, some `i4` for the numeric ones).
- Data Conversion then converts the string `*_t` columns to their final types (`i4`, `i8`, `dbDate`, `wstr len 10/100`, `bool`).

This is the wizard's default but it materialises **two extra buffer columns per source column** (32+ extra columns in the buffer). Memory waste and a second pass. **Fold both into the Derived Column** by casting in the same expression:

```
(DT_I4)(DT_R8)TRIM(YEAR)            -- replaces Year_t + Data Conversion
(DT_DBDATE)TRIM(FL_DATE)            -- replaces FlightDate_clean + Data Conversion
```

This is mechanical work but it noticeably cuts memory.

### 4. `FastParse = false` on every Flat File Source column

`FastParse` skips locale-aware date/integer parsing — about 20–30% faster for known-format columns. Safe for `YEAR`, `MONTH`, `FL_DATE` (BTS format is always `yyyy-mm-dd`), all the `*_AIRPORT_ID` ints, and the delay/time ints. Turn it on per-column in the advanced editor on the Flat File Source.

### 5. `DEP_DELAY` cleansing expression is a horror

Lines 1238/1244 of the package XML chain 13 nested `REPLACE` calls to strip digit characters and check what's left, in order to detect non-numeric values. That works but it runs 13 string ops per row × 4M rows = ~52M string allocations just for one column. Two options, both cleaner:

- **Move it to T-SQL.** Land the column as `NVARCHAR(20)`, then do `TRY_CAST(value AS INT)` in a staging-cleanup step. T-SQL does this in one CPU op per row.
- **Use `FINDSTRING`** for a single-pass check, or just rely on the error output of `(DT_I4)(DT_R8)TRIM(DEP_DELAY)` — invalid rows fall to the error output, where you can route them to a quarantine table.

### 6. Source string length 50 is wasteful

Every input column is declared `str len 50`. `OP_UNIQUE_CARRIER` is 2 chars. `ORIGIN`/`DEST` are 3 chars. `CANCELLED`/`DIVERTED` are 1 char. This inflates buffer rows by ~700 bytes each. Tighten the **Flat File Connection Manager** advanced columns to the real max lengths (2, 3, 1 respectively). Saves ~30% buffer memory.

### 7. No row-count or file-name tracking

The package loads the row but doesn't record which file the row came from. Your `dbo.Flights_2024` table already has a `SourceFile NVARCHAR(260)` column ready for this. Two ways:

- **Flat File Source → `FileNameColumnName`** property — emits the file name as a new column for free (it's currently blank).
- **Add a Row Count transform** between Derived Column and Destination, write to an SSIS variable, log to `etl.RunLog` after each iteration.

The first one is free and ships the lineage column you already designed.

### 8. No package-level logging

`PackageFormatVersion=8` means logging is configured via the project deployment model. There's no `DTS:LoggingOptions` defined in this package, so SSIS catalog logging is the only audit trail. Fine if you've enabled SSISDB Basic logging at the project level, broken if you haven't. Verify via `SELECT * FROM SSISDB.catalog.executions WHERE package_name='Load_Flights_2024.dtsx'` after a run.

### 9. `RetainSameConnection` is not set on `CM_OLEDB_Staging`

Each iteration of the Foreach loop reopens the connection. For 12 files that's 12 connection handshakes. Set `RetainSameConnection = True` on the OLE DB connection manager to share one connection across iterations. Small win, but free.

### 10. No truncate-or-append decision is explicit

The OLE DB Destination just appends. If you re-run for the same month the package will silently double-insert. Two defensible patterns:

- **Pre-execute SQL Task** that does `DELETE FROM dbo.Flights_2024 WHERE SourceFile = ?` (parameter = current file). Idempotent re-runs.
- **MERGE** with a natural-key check inside SQL.

I'd choose option 1 — simpler, makes the package boring.

## Things I'd *not* change

- **Single Data Flow per file** (not parallel Foreach). Single-writer to one OLE DB destination — adding parallelism just creates contention for the same TABLOCK. Keep it serial.
- **`MaximumErrorCount = 1`** (default). Stop on first failure during the lab phase; relax to per-file failure once you have a quarantine table.
- **`DelayValidation = False`** (default). Schema is stable. No reason to defer validation.

## Summary

The package is correct and minimally logged-friendly. The optimisation work to bring it to "interview-grade good" is:

| Priority | Change                                  | Effort | Win |
|----------|-----------------------------------------|--------|------|
| P0       | Set `FastLoadMaxInsertCommitSize=100000` | 30 sec | Big |
| P0       | Add Pre-execute `DELETE WHERE SourceFile=?` for idempotency | 5 min | Big |
| P0       | Wire `FileNameColumnName` → `SourceFile` column | 1 min | Big |
| P1       | Increase buffer (`50000` rows / `64 MB`) | 1 min | Med |
| P1       | Tighten Flat File source column widths   | 5 min | Med |
| P1       | Fold Data Conversion into Derived Column | 30 min | Med |
| P2       | Turn on `FastParse` per column           | 5 min | Small-Med |
| P2       | Replace `DEP_DELAY` regex with T-SQL `TRY_CAST` | 20 min | Med |
| P3       | `RetainSameConnection=True` on OLE DB CM | 30 sec | Small |
| P3       | Enable per-project SSISDB logging        | 2 min | Audit |

The P0 list is what I'd do before the LinkedIn post. The rest is "nice to have, document as known follow-ups."
</content>
</invoke>