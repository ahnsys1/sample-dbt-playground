`dbt run` completed successfully through the project’s virtual environment.

All 23 models built successfully:

- 6 incremental bronze models
- 8 silver table models
- 9 gold table models

Result: `PASS=23 WARN=0 ERROR=0`

Use this command from sample-dbt-playground:

```bash
uv run dbt run \
  --project-dir product_sales \
  --profiles-dir product_sales
```

The traceback from plain `dbt run` is still caused by the broken global executable at dbt; it is unrelated to the dbt models or PostgreSQL connection.

# sample-dbt-playground
