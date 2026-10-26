# Quiz — AWS S3 Data Lake

Test yourself before you peek at the answers. No cheating — the lake knows.

## 1. Why should the Bronze zone be immutable (append-only)?

<details>
<summary>Answer</summary>

Because Bronze is your only exact copy of the source data. If an ETL job corrupts
Silver or Gold, you can always rebuild from Bronze. If Bronze itself was
overwritten, that history is gone for good.
</details>

## 2. Why store Silver and Gold as Parquet instead of CSV?

<details>
<summary>Answer</summary>

Parquet is columnar: a query that asks for 3 columns out of 50 only scans those
3 columns. With CSV, Athena scans the whole file every time. For the same
question, Parquet typically costs a fraction of CSV — often ~10× less.
</details>

## 3. What is the Glue Data Catalog actually for?

<details>
<summary>Answer</summary>

It is the single registry of what tables exist, what columns they have, and
where the data lives. Crawlers register raw tables; ETL jobs register cleaned
ones. Consumers (Athena, QuickSight, ML jobs) query through the catalog, not
by guessing S3 paths.
</details>

## 4. An analyst needs revenue data but must NOT see customer email addresses. How do you handle that?

<details>
<summary>Answer</summary>

Use Lake Formation column-level permissions: grant the analyst role access to
the Gold table but exclude the email column. Do not copy the table, do not
hand out bucket access, and do not rely on "just don't query that column."
</details>

## 5. Your Athena bill suddenly triples. Name two likely causes and their fixes.

<details>
<summary>Answer</summary>

1. **Unpartitioned or full-table scans** — queries without a partition filter
   scan everything. Fix: partition by date and always filter on the partition key.
2. **Small files / CSV format** — thousands of tiny objects or row-based files
   inflate scans. Fix: compact files in ETL and store Parquet + Snappy.
   (Bonus third cause: lifecycle rules missing, so old data never cools down.)
</details>
