User: jaky je spravny postup pro nahravani dat do DBT? mam tim namysli jestli pouzit seed?  akdyz ano tak raw tabulky se budou promazavat nebo se tam budou dalsi a dalsi zaznamy pridavat?  a k cemu je incremental strategy merge?

GitHub Copilot: Podívám se na konkrétní nastavení tohoto dbt projektu a na modely kolem `raw`/`bronze`, abych odpověď vztáhl přímo k vašemu workflow, ne jen k obecnému dbt. Ověřím hlavně, odkud se data načítají a zda už projekt používá incremental modely nebo snapshoty.

Read memory [](file:///home/jan/.config/Code/User/workspaceStorage/6c5e2a9c223a1e7b03f1c1d2d6b0e302/GitHub.copilot-chat/memory-tool/memories/repo/sample-dbt-playground.md)

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales/dbt_project.yml)

Searched for files matching `sample-dbt-playground` · `product_sales/models/**/*.sql`, 23 matches

Searched for regex `materialized|incremental|strategy|raw_|source\(` (`sample-dbt-playground` · `product_sales/**`), 37 results

Z nastavení je už vidět důležitý detail: `raw_*` jsou v tomto projektu dbt seeds z CSV, zatímco `bronze_*` jsou incremental modely se strategií `merge`. Teď ještě ověřím konkrétní CSV/README a SQL jednotlivých vrstev, protože z toho plyne, zda je `raw` jen demo vstup, nebo má být skutečná historická landing vrstva.

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales/models/bronze/bronze_supplies.sql)

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales/README.md)

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales/seeds/raw_supplies.csv#1-1), lines 1 to 20

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales_connector/README.md)

V tomto projektu je současný postup:

`CSV -> dbt seed raw_* -> incremental bronze_* -> table silver_* -> table gold_*`

Konkrétně:

- `seeds/raw_supplies.csv` se načte jako tabulka `raw_supplies`.
- bronze_supplies.sql čte z `raw_supplies`.
- `bronze_supplies` je nastavený jako `incremental` se strategií `merge`.
- `unique_key=['supply_id', 'product_sku']` určuje, podle čeho se řádky identifikují.

**Kdy použít `seed`**

`seed` je vhodný hlavně pro:

- malé statické nebo referenční tabulky,
- testovací data,
- lookup tabulky,
- data, která jsou verzovaná společně s dbt projektem v Git repozitáři.

Například:

```bash
dbt seed --select raw_supplies
dbt run --select bronze_supplies
```

Seed není vhodný jako hlavní mechanismus pro pravidelný ingest produkčních dat. Pro produkci se obvykle používá externí ingestion nástroj, například Airbyte, Fivetran, Kafka, Debezium nebo vlastní ETL. Ten zapisuje data do raw databázových tabulek a dbt je potom transformuje pomocí `source()`.

**Mažou se raw tabulky, nebo se přidávají další řádky?**

Seed se nechová jako append-only ingest. Tabulka se synchronizuje s obsahem CSV:

- řádek přidaný do CSV se objeví v tabulce,
- změněný řádek se aktualizuje,
- řádek odstraněný z CSV se po znovunačtení v tabulce také nemá nacházet.

Technický způsob, jakým dbt tabulku obnoví, závisí na adapteru, ale z pohledu uživatele je důležité toto: **seed není historický log a automaticky do něj nepřidává další a další kopie dat při každém spuštění**.

Pokud chcete raw historii, musí ji uchovávat upstream ingest nebo samostatná append-only tabulka. Alternativně lze pro sledování změn použít dbt snapshot, ale snapshot není totéž co seed.

**Co dělá `incremental_strategy: merge`**

Při prvním běhu se incremental model vytvoří celý. Při dalších bězích dbt porovnává nové řádky se stávající cílovou tabulkou podle `unique_key`.

Zjednodušeně:

```text
pokud klíč existuje:
    UPDATE existujícího řádku
pokud klíč neexistuje:
    INSERT nového řádku
```

U vašeho modelu:

```sql
{{ config(unique_key=['supply_id', 'product_sku']) }}
```

je klíčem dvojice:

```text
supply_id + product_sku
```

Například:

```text
SUP-001 + JAF-001
SUP-001 + JAF-002
```

jsou dva různé záznamy.

`merge` sám o sobě obvykle nemaže řádky, které už nejsou ve zdrojovém datasetu. Pokud tedy odstraníte řádek z CSV, může starý řádek v `bronze_supplies` zůstat. Pro synchronizaci včetně mazání je potřeba mazání explicitně řešit, například full refresh, delete logicí, snapshotem nebo upstream CDC.

**Důležitý detail ve vašem modelu**

Současný SQL model:

```sql
select
    ...
    current_timestamp as bronze_loaded_at
from {{ ref('raw_supplies') }}
```

nemá podmínku `is_incremental()`. To znamená, že při každém běhu znovu načte všechny řádky z `raw_supplies` a `merge` je porovná s cílovou tabulkou. Výsledek bude funkčně správný, ale u velkých tabulek to nebude efektivní.

Typický incremental model by měl filtrovat pouze nové nebo změněné záznamy, například:

```sql
select
    ...
from {{ ref('raw_supplies') }}

{% if is_incremental() %}
where updated_at > (
    select coalesce(max(updated_at), '1900-01-01')
    from {{ this }}
)
{% endif %}
```

To ale vyžaduje, aby zdrojová data měla například `updated_at`, CDC timestamp nebo jiné pole umožňující určit novější záznamy.

**Doporučený postup**

Pro tento demo projekt je `seed` v pořádku:

```text
CSV
  -> dbt seed
  -> raw_* tabulka
  -> bronze incremental merge
  -> silver/gold tabulky
```

Pro reálnou produkční pipeline bych doporučil:

```text
zdrojový systém
  -> ingestion/CDC nástroj
  -> raw tabulky
  -> dbt source()
  -> bronze incremental merge
  -> silver
  -> gold
```

Ve vašem repozitáři už existuje i Debezium/Kafka Connect část. Ta je vhodnější pro průběžné `INSERT`, `UPDATE` a `DELETE` změny než seed z CSV. Db­t by v takovém případě neměl raw data nahrávat, ale pouze je transformovat.

User: Co je to CDC nástroj? Co je dbt source()?

GitHub Copilot: **CDC nástroj**

CDC znamená **Change Data Capture**, tedy zachytávání změn ve zdrojové databázi.

CDC nástroj průběžně sleduje databázi a posílá události například:

```text
INSERT: nový zákazník
UPDATE: změněná cena produktu
DELETE: odstraněný obchod
```

Místo opakovaného načítání celé tabulky tedy přenáší pouze změny.

Ve vašem projektu tuto roli plní **Debezium**:

```text
PostgreSQL source
    -> Debezium
    -> Kafka
    -> Kafka Connect JDBC sink
    -> PostgreSQL raw/bronze tabulky
    -> dbt
    -> silver/gold modely
```

Například když v PostgreSQL změníte cenu produktu:

```sql
update products
set price = 120
where sku = 'JAF-001';
```

Debezium tuto změnu zachytí a odešle ji přes Kafka. Sink konektor pak aktualizuje odpovídající řádek v cílové databázi. Db­t následně pracuje s aktualizovanými daty.

CDC je užitečné, když:

- data přibývají nebo se mění průběžně,
- potřebujete zachytit i `UPDATE` a `DELETE`,
- tabulky jsou příliš velké na pravidelné full loady,
- potřebujete nízkou prodlevu mezi zdrojem a analytickou databází.

Seed z CSV oproti tomu není CDC. Db­t při `dbt seed` pouze synchronizuje CSV s tabulkou. Neví, že se mezitím změnil konkrétní řádek, a neposílá změnové události.

**Co je `source()` v dbt**

`source()` je dbt funkce pro odkaz na tabulku, kterou **nevytvořil dbt**, ale nějaký externí systém nebo ingestion proces.

Příklad:

```sql
select *
from {{ source('sales', 'orders') }}
```

To může odkazovat například na tabulku:

```text
raw.sales_orders
```

Konfigurace bývá v souboru `sources.yml`:

```yaml
version: 2

sources:
  - name: sales
    database: postgres
    schema: raw
    tables:
      - name: orders
      - name: customers
```

Dbt potom zná přesný název zdrojové tabulky a může na ní provádět testy a kontrolovat čerstvost dat.

**Rozdíl mezi `source()` a `ref()`**

Ve vašem projektu se používá například:

```sql
from {{ ref('raw_supplies') }}
```

`ref()` znamená:

> Odkazuji na jiný dbt model nebo seed.

Proto `raw_supplies` v současném projektu funguje jako seed z:

```text
seeds/raw_supplies.csv
```

Při produkčním CDC workflow by místo toho bylo typické:

```sql
from {{ source('raw', 'supplies') }}
```

Rozdíl:

| Funkce | Odkazuje na | Typický původ |
|---|---|---|
| `ref()` | jiný dbt model nebo seed | dbt |
| `source()` | externí zdrojovou tabulku | CDC, ETL, aplikace, datový sklad |

`ref()` zároveň dbt vytvoří závislost mezi modely. Db­t díky tomu ví, v jakém pořadí má modely spouštět.

Například:

```text
raw_supplies seed
    -> bronze_supplies
    -> silver_supplies
    -> dim_supplies
```

`source()` zase označuje vstupní hranici dbt projektu:

```text
Debezium/Kafka/ETL
    -> raw.supplies
    -> {{ source('raw', 'supplies') }}
    -> bronze_supplies
```

Prakticky tedy:

- pro váš současný demo projekt: `ref('raw_supplies')` je správně,
- pro produkční tabulky plněné Debezium nebo jiným ingestion nástrojem: použil bych `source('raw', 'supplies')`,
- `source()` sám data nenačítá; pouze dbt říká, kde externí data najde.

User: jak mam nahrat vsechny data do cilovych tabulek pred spustenim dbt ru. Hlavne kde je mam nahrat? A taky zda je mam nahrat do raw tabulek nebo do bronze? nebo jak je to spravne?

GitHub Copilot: Zkontroluji ještě konkrétní konektorovou konfiguraci v projektu, protože zde jsou dvě možné databáze a názvy `raw`/`bronze` se mohou snadno zaměnit. Pak popíšu přesný pořadník příkazů pro váš současný seed workflow i pro CDC variantu.

Searched for files matching `sample-dbt-playground` · `product_sales_connector/connectors/*.json`, 7 matches

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales_connector/sql/01-source-prepare-logical-replication.sql)

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales_connector/sql/02-target-prepare-schema.sql)

Read [](file:///home/jan/Desktop/sample-dbt-playground/product_sales_connector/README.md#1-1), lines 1 to 100

V tomto projektu jsou dvě možné varianty. Pro začátek doporučuji použít tu první, protože odpovídá současnému nastavení dbt.

## Varianta 1: Data jsou v CSV souborech

V současném projektu jsou vstupní data zde:

```text
product_sales/seeds/raw_*.csv
```

Například:

```text
product_sales/seeds/raw_supplies.csv
product_sales/seeds/raw_products.csv
product_sales/seeds/raw_orders.csv
```

Data tedy nahrajete nebo vložíte do těchto CSV souborů. **Nenahráváte je přímo do `bronze` tabulek.**

Potom spusťte z adresáře product_sales:

```bash
dbt seed
dbt run
```

Nebo vše najednou:

```bash
dbt build
```

Výsledek bude přibližně:

```text
raw_supplies       <- vytvoří dbt seed z raw_supplies.csv
bronze_supplies    <- vytvoří nebo aktualizuje dbt model
silver_supplies    <- vytvoří dbt model
dim_supplies       <- vytvoří dbt model
```

Přesněji:

```text
CSV soubor
    -> raw tabulka
    -> bronze tabulka
    -> silver tabulka
    -> gold tabulka
```

### Kam tedy nahrát data?

| Vrstva | Kdo ji plní | Co do ní patří |
|---|---|---|
| `raw` | seed nebo ingestion nástroj | původní data bez větších úprav |
| `bronze` | dbt | lehce očištěná a typovaná data |
| `silver` | dbt | transformovaná a obohacená data |
| `gold` | dbt | reportingové tabulky a dimenze/fakta |

Do `bronze` ručně nevkládejte data. V tomto projektu je `bronze` dbt model:

```sql
from {{ ref('raw_supplies') }}
```

Dbt ho vytváří podle SQL definice v souboru bronze_supplies.sql.

## Varianta 2: Data přicházejí z aplikace nebo jiné databáze

V produkčním řešení by aplikace zapisovala do zdrojové databáze, například:

```text
aplikace
    -> PostgreSQL source
    -> CDC/ETL nástroj
    -> raw tabulky
    -> dbt
    -> bronze/silver/gold
```

V takovém případě se data nenahrávají do CSV ani přímo do bronze. Ingestion nástroj je zapíše do `raw` tabulek. Db­t je potom načte přes:

```sql
from {{ source('raw', 'supplies') }}
```

Konfigurace by mohla vypadat takto:

```yaml
version: 2

sources:
  - name: raw
    schema: raw
    tables:
      - name: supplies
      - name: products
      - name: orders
```

A bronze model:

```sql
select
    cast(id as varchar) as supply_id,
    cast(name as varchar) as supply_name,
    cast(cost as numeric) as cost,
    cast(perishable as boolean) as is_perishable,
    cast(sku as varchar) as product_sku,
    current_timestamp as bronze_loaded_at
from {{ source('raw', 'supplies') }}
```

## Jak to souvisí s vaším Debezium konektorem?

Ve vašem repozitáři je trochu specifické zapojení:

```text
dbt vytvoří bronze tabulky v source PostgreSQL
    -> Debezium zachytí jejich změny
    -> Kafka
    -> JDBC sink
    -> target PostgreSQL
```

Podle konfigurace se Debezium připojuje ke zdrojové PostgreSQL na portu `5431` a kopíruje tabulky `product_sales_bronze.bronze_*` do cílové PostgreSQL na portu `5432`.

Pro první naplnění tedy postup v tomto projektu vypadá takto:

```bash
cd /home/jan/Desktop/sample-dbt-playground/product_sales

dbt seed
dbt run
```

Tím vzniknou a naplní se `raw_*` a `bronze_*` tabulky ve zdrojové databázi. Poté Debezium při `snapshot.mode=initial` provede počáteční snapshot bronze tabulek do cílové databáze.

Následně:

```text
nový nebo změněný řádek
    -> dbt aktualizuje bronze
    -> Debezium zachytí změnu
    -> Kafka
    -> cílová databáze
```

## Co bych doporučil pro váš případ

Pro aktuální demo:

1. Vložte kompletní data do `product_sales/seeds/raw_*.csv`.
2. Zkontrolujte, že CSV neobsahují duplicitní klíče.
3. Spusťte:

```bash
dbt seed
dbt build
```

4. Teprve potom spusťte nebo zaregistrujte Debezium/Kafka Connect konektory.

Pro produkční řešení:

```text
aplikace/zdrojová DB
    -> CDC nebo ETL
    -> raw tabulky
    -> dbt source()
    -> bronze
    -> silver
    -> gold
```

Nejdůležitější pravidlo je:

> Data se načítají do `raw`; `bronze`, `silver` a `gold` vytváří dbt.