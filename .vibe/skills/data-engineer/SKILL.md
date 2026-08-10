---
name: data-engineer
description: "Use when processing, transforming, or analyzing data in Ruby - CSV/JSON parsing, ETL pipelines, data validation, batch processing, and file format conversion."
user-invocable: true
---

# RubyDev Data Engineer — Data Processing Pipelines

## Overview

Ruby excels at data processing: CSV and JSON parsing are stdlib, the `enumerable` module provides powerful transformation chains, and gems like `smarter_csv`, `roo` (spreadsheets), and `sequel` (database bulk operations) extend this to real-world data engineering workloads.

The data-engineer skill covers reading, transforming, validating, and writing data at scale — from one-off report generation to scheduled ETL runs.

## When to Use

- User provides a CSV/JSON/XML file for processing or analysis
- User asks for data transformation, filtering, or aggregation
- Building an ETL pipeline between systems (API → CSV, DB → JSON, etc.)
- Data validation — checking schema, types, ranges, required fields
- Batch processing files in a directory

**Don't use for:**
- Interactive data exploration (use Jupyter + Python instead)
- SQL queries on a live database (use the database-native tooling)
- Very large datasets (>1GB) in memory (use streaming or a DB)

## Processing Modes

### 1. In-Memory (Standard)

Load entire dataset into memory. Good for files under 100MB.

```ruby
require "csv"
rows = CSV.read("data.csv", headers: true)
# Process with Enumerable
results = rows.select { |r| r["status"] == "active" }
              .map    { |r| { id: r["id"], name: r["name"].strip } }
CSV.open("output.csv", "w") { |csv| csv << %w[id name]; results.each { |r| csv << r.values } }
```

### 2. Streaming (Lazy)

Process one row at a time. Good for files >100MB or memory-constrained environments.

```ruby
require "csv"
CSV.foreach("large.csv", headers: true) do |row|
  next unless row["status"] == "active"
  # Process and write immediately
  write_to_api(row)
end
```

### 3. Batch (Chunked)

Group rows for database inserts or API calls.

```ruby
require "csv"
rows = CSV.read("data.csv", headers: true)
rows.each_slice(100) do |batch|
  DB.transaction do
    DB[:records].multi_insert(batch.map(&:to_h))
  end
  sleep 0.5 # Rate limit
end
```

Each batch commits as a unit — a failure partway through a batch rolls back that batch instead of leaving a partial insert. Don't wrap the entire `each_slice` loop in one transaction; that would hold a lock for the whole run and lose the benefit of chunking.

## Common Transformations

| Input | Output | Tooling | When |
|-------|--------|---------|------|
| CSV | JSON | `CSV` + `JSON` | API ingestion |
| JSON | CSV | `JSON.parse` + `CSV` | Spreadsheet export |
| CSV | Database | `Sequel` + `multi_insert` | Data warehouse load |
| XML | Hash | `Ox` or `Nokogiri` | Legacy system integration |
| Spreadsheet (xlsx) | CSV | `roo` gem | Excel processing |
| Fixed-width | CSV | `String#unpack` | Mainframe/mainframe legacy |

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| `CSV` (stdlib) | Always available (stdlib) | N/A — no fallback needed |
| `JSON` (stdlib) | Always available (stdlib) | N/A — no fallback needed |
| `sequel` | Gem not installed | Use raw SQL with `pg` or `mysql2` gem. If DB not available, write to JSON file. |
| `smarter_csv` | Gem not installed | Use stdlib `CSV` with manual chunking. |
| `roo` (spreadsheets) | Gem not installed | Convert xlsx to CSV first (command line: `ssconvert` or LibreOffice headless). |

## Common Pitfalls

1. **Memory blowup**: `CSV.read` loads everything. Use `CSV.foreach` for files >100MB or unknown sizes.
2. **String encoding**: CSV files from Windows may have `UTF-16LE` or `ISO-8859-1` encoding. Set `encoding: "bom|utf-8"` on CSV.open.
3. **Header row inconsistencies**: Always check `CSV.read("file.csv", headers: true).headers` before processing. Headers may have trailing whitespace.
4. **Inferring types**: CSV values are always strings. Convert explicitly: `r["count"].to_i`, `r["price"].to_f`.
5. **Empty rows**: CSV files often have trailing blank lines. Filter with `.reject { |r| r.to_h.values.all?(&:nil?) }`.
6. **Transaction boundaries**: Wrap database bulk inserts in a transaction to avoid partial loads on failure.

## Verification Checklist

- [ ] Source file exists and is readable
- [ ] Encoding detected correctly (check with `file -bi data.csv`)
- [ ] Headers parsed and cleaned of whitespace/symbols
- [ ] Row count matches expected (input → output count)
- [ ] Data types converted correctly (string → integer, date, etc.)
- [ ] Output file format matches requirements
- [ ] Edge cases handled: empty file, single row, duplicate headers, BOM