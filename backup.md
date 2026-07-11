**User: jaky je spravny postup pro nahravani dat do DBT? mam tim namysli jestli pouzit seed?  akdyz ano tak raw tabulky se budou promazavat nebo se tam budou dalsi a dalsi zaznamy pridavat?  a k cemu je incremental strategy merge?**

GitHub Copilot: Podívám se na konkrétní nastavení tohoto dbt projektu a na modely kolem `raw`/`bronze`, abych odpověď vztáhl přímo k vašemu workflow, ne jen k obecnému dbt. Ověřím hlavně, odkud se data načítají a zda už projekt používá incremental modely nebo snapshoty.

Read memory 

Read 

Searched for files matching `sample-dbt-playground` · `product\_sales/models/\*\*/\*.sql`, 23 matches

Searched for regex `materialized|incremental|strategy|raw\_|source\\(` (`sample-dbt-playground` · `product\_sales/\*\*`), 37 results

Z nastavení je už vidět důležitý detail: `raw\_\*` jsou v tomto projektu dbt seeds z CSV, zatímco `bronze\_\*` jsou incremental modely se strategií `merge`. Teď ještě ověřím konkrétní CSV/README a SQL jednotlivých vrstev, protože z toho plyne, zda je `raw` jen demo vstup, nebo má být skutečná historická landing vrstva.

Read 

Read 

Read , lines 1 to 20

Read 

V tomto projektu je současný postup:

`CSV -\> dbt seed raw\_\* -\> incremental bronze\_\* -\> table silver\_\* -\> table gold\_\*`

Konkrétně:

- `seeds/raw\_supplies.csv` se načte jako tabulka `raw\_supplies`.

- bronze\_supplies.sql čte z `raw\_supplies`.

- `bronze\_supplies` je nastavený jako `incremental` se strategií `merge`.

- `unique\_key=\['supply\_id', 'product\_sku'\]` určuje, podle čeho se řádky identifikují.

**Kdy použít `seed`**

`seed` je vhodný hlavně pro:

- malé statické nebo referenční tabulky,

- testovací data,

- lookup tabulky,

- data, která jsou verzovaná společně s dbt projektem v Git repozitáři.

Například:

```
dbt seed --select raw\_supplies  
dbt run --select bronze\_supplies
```

Seed není vhodný jako hlavní mechanismus pro pravidelný ingest produkčních dat. Pro produkci se obvykle používá externí ingestion nástroj, například Airbyte, Fivetran, Kafka, Debezium nebo vlastní ETL. Ten zapisuje data do raw databázových tabulek a dbt je potom transformuje pomocí `source()`.

**Mažou se raw tabulky, nebo se přidávají další řádky?**

Seed se nechová jako append-only ingest. Tabulka se synchronizuje s obsahem CSV:

- řádek přidaný do CSV se objeví v tabulce,

- změněný řádek se aktualizuje,

- řádek odstraněný z CSV se po znovunačtení v tabulce také nemá nacházet.

Technický způsob, jakým dbt tabulku obnoví, závisí na adapteru, ale z pohledu uživatele je důležité toto: **seed není historický log a automaticky do něj nepřidává další a další kopie dat při každém spuštění**.

Pokud chcete raw historii, musí ji uchovávat upstream ingest nebo samostatná append-only tabulka. Alternativně lze pro sledování změn použít dbt snapshot, ale snapshot není totéž co seed.

**Co dělá `incremental\_strategy: merge`**

Při prvním běhu se incremental model vytvoří celý. Při dalších bězích dbt porovnává nové řádky se stávající cílovou tabulkou podle `unique\_key`.

Zjednodušeně:

```
pokud klíč existuje:  
    UPDATE existujícího řádku  
pokud klíč neexistuje:  
    INSERT nového řádku
```

U vašeho modelu:

```
\{\{ config(unique\_key=\['supply\_id', 'product\_sku'\]) \}\}
```

je klíčem dvojice:

```
supply\_id + product\_sku
```

Například:

```
SUP-001 + JAF-001  
SUP-001 + JAF-002
```

jsou dva různé záznamy.

`merge` sám o sobě obvykle nemaže řádky, které už nejsou ve zdrojovém datasetu. Pokud tedy odstraníte řádek z CSV, může starý řádek v `bronze\_supplies` zůstat. Pro synchronizaci včetně mazání je potřeba mazání explicitně řešit, například full refresh, delete logicí, snapshotem nebo upstream CDC.

**Důležitý detail ve vašem modelu**

Současný SQL model:

```
select  
    ...  
    current\_timestamp as bronze\_loaded\_at  
from \{\{ ref('raw\_supplies') \}\}
```

nemá podmínku `is\_incremental()`. To znamená, že při každém běhu znovu načte všechny řádky z `raw\_supplies` a `merge` je porovná s cílovou tabulkou. Výsledek bude funkčně správný, ale u velkých tabulek to nebude efektivní.

Typický incremental model by měl filtrovat pouze nové nebo změněné záznamy, například:

```
select  
    ...  
from \{\{ ref('raw\_supplies') \}\}  
  
\{% if is\_incremental() %\}  
where updated\_at \> (  
    select coalesce(max(updated\_at), '1900-01-01')  
    from \{\{ this \}\}  
)  
\{% endif %\}
```

To ale vyžaduje, aby zdrojová data měla například `updated\_at`, CDC timestamp nebo jiné pole umožňující určit novější záznamy.

**Doporučený postup**

Pro tento demo projekt je `seed` v pořádku:

```
CSV  
  -\> dbt seed  
  -\> raw\_\* tabulka  
  -\> bronze incremental merge  
  -\> silver/gold tabulky
```

Pro reálnou produkční pipeline bych doporučil:

```
zdrojový systém  
  -\> ingestion/CDC nástroj  
  -\> raw tabulky  
  -\> dbt source()  
  -\> bronze incremental merge  
  -\> silver  
  -\> gold
```

Ve vašem repozitáři už existuje i Debezium/Kafka Connect část. Ta je vhodnější pro průběžné `INSERT`, `UPDATE` a `DELETE` změny než seed z CSV. Db­t by v takovém případě neměl raw data nahrávat, ale pouze je transformovat.




User: Co je to CDC nástroj? Co je dbt source()?

GitHub Copilot: **CDC nástroj**

CDC znamená **Change Data Capture**, tedy zachytávání změn ve zdrojové databázi.

CDC nástroj průběžně sleduje databázi a posílá události například:

```
INSERT: nový zákazník  
UPDATE: změněná cena produktu  
DELETE: odstraněný obchod
```

Místo opakovaného načítání celé tabulky tedy přenáší pouze změny.

Ve vašem projektu tuto roli plní **Debezium**:

```
PostgreSQL source  
    -\> Debezium  
    -\> Kafka  
    -\> Kafka Connect JDBC sink  
    -\> PostgreSQL raw/bronze tabulky  
    -\> dbt  
    -\> silver/gold modely
```

Například když v PostgreSQL změníte cenu produktu:

```
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

```
select \*  
from \{\{ source('sales', 'orders') \}\}
```

To může odkazovat například na tabulku:

```
raw.sales\_orders
```

Konfigurace bývá v souboru `sources.yml`:

```
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

```
from \{\{ ref('raw\_supplies') \}\}
```

`ref()` znamená:

> Odkazuji na jiný dbt model nebo seed.

Proto `raw\_supplies` v současném projektu funguje jako seed z:

```
seeds/raw\_supplies.csv
```

Při produkčním CDC workflow by místo toho bylo typické:

```
from \{\{ source('raw', 'supplies') \}\}
```

Rozdíl:

| Funkce | Odkazuje na | Typický původ |
| - | - | - |
| `ref()` | jiný dbt model nebo seed | dbt |
| `source()` | externí zdrojovou tabulku | CDC, ETL, aplikace, datový sklad |


`ref()` zároveň dbt vytvoří závislost mezi modely. Db­t díky tomu ví, v jakém pořadí má modely spouštět.

Například:

```
raw\_supplies seed  
    -\> bronze\_supplies  
    -\> silver\_supplies  
    -\> dim\_supplies
```

`source()` zase označuje vstupní hranici dbt projektu:

```
Debezium/Kafka/ETL  
    -\> raw.supplies  
    -\> \{\{ source('raw', 'supplies') \}\}  
    -\> bronze\_supplies
```

Prakticky tedy:

- pro váš současný demo projekt: `ref('raw\_supplies')` je správně,

- pro produkční tabulky plněné Debezium nebo jiným ingestion nástrojem: použil bych `source('raw', 'supplies')`,

- `source()` sám data nenačítá; pouze dbt říká, kde externí data najde.







V tomto projektu je současný postup:

`CSV -\> dbt seed raw\_\* -\> incremental bronze\_\* -\> table silver\_\* -\> table gold\_\*`

Konkrétně:

- `seeds/raw\_supplies.csv` se načte jako tabulka `raw\_supplies`.

- bronze\_supplies.sql čte z `raw\_supplies`.

- `bronze\_supplies` je nastavený jako `incremental` se strategií `merge`.

- `unique\_key=\['supply\_id', 'product\_sku'\]` určuje, podle čeho se řádky identifikují.

**Kdy použít `seed`**

`seed` je vhodný hlavně pro:

- malé statické nebo referenční tabulky,

- testovací data,

- lookup tabulky,

- data, která jsou verzovaná společně s dbt projektem v Git repozitáři.

Například:

```
dbt seed --select raw\_supplies  
dbt run --select bronze\_supplies
```

Seed není vhodný jako hlavní mechanismus pro pravidelný ingest produkčních dat. Pro produkci se obvykle používá externí ingestion nástroj, například Airbyte, Fivetran, Kafka, Debezium nebo vlastní ETL. Ten zapisuje data do raw databázových tabulek a dbt je potom transformuje pomocí `source()`.

**Mažou se raw tabulky, nebo se přidávají další řádky?**

Seed se nechová jako append-only ingest. Tabulka se synchronizuje s obsahem CSV:

- řádek přidaný do CSV se objeví v tabulce,

- změněný řádek se aktualizuje,

- řádek odstraněný z CSV se po znovunačtení v tabulce také nemá nacházet.

Technický způsob, jakým dbt tabulku obnoví, závisí na adapteru, ale z pohledu uživatele je důležité toto: **seed není historický log a automaticky do něj nepřidává další a další kopie dat při každém spuštění**.

Pokud chcete raw historii, musí ji uchovávat upstream ingest nebo samostatná append-only tabulka. Alternativně lze pro sledování změn použít dbt snapshot, ale snapshot není totéž co seed.

**Co dělá `incremental\_strategy: merge`**

Při prvním běhu se incremental model vytvoří celý. Při dalších bězích dbt porovnává nové řádky se stávající cílovou tabulkou podle `unique\_key`.

Zjednodušeně:

```
pokud klíč existuje:  
    UPDATE existujícího řádku  
pokud klíč neexistuje:  
    INSERT nového řádku
```

U vašeho modelu:

```
\{\{ config(unique\_key=\['supply\_id', 'product\_sku'\]) \}\}
```

je klíčem dvojice:

```
supply\_id + product\_sku
```

Například:

```
SUP-001 + JAF-001  
SUP-001 + JAF-002
```

jsou dva různé záznamy.

`merge` sám o sobě obvykle nemaže řádky, které už nejsou ve zdrojovém datasetu. Pokud tedy odstraníte řádek z CSV, může starý řádek v `bronze\_supplies` zůstat. Pro synchronizaci včetně mazání je potřeba mazání explicitně řešit, například full refresh, delete logicí, snapshotem nebo upstream CDC.

**Důležitý detail ve vašem modelu**

Současný SQL model:

```
select  
    ...  
    current\_timestamp as bronze\_loaded\_at  
from \{\{ ref('raw\_supplies') \}\}
```

nemá podmínku `is\_incremental()`. To znamená, že při každém běhu znovu načte všechny řádky z `raw\_supplies` a `merge` je porovná s cílovou tabulkou. Výsledek bude funkčně správný, ale u velkých tabulek to nebude efektivní.

Typický incremental model by měl filtrovat pouze nové nebo změněné záznamy, například:

```
select  
    ...  
from \{\{ ref('raw\_supplies') \}\}  
  
\{% if is\_incremental() %\}  
where updated\_at \> (  
    select coalesce(max(updated\_at), '1900-01-01')  
    from \{\{ this \}\}  
)  
\{% endif %\}
```

To ale vyžaduje, aby zdrojová data měla například `updated\_at`, CDC timestamp nebo jiné pole umožňující určit novější záznamy.

**Doporučený postup**

Pro tento demo projekt je `seed` v pořádku:

```
CSV  
  -\> dbt seed  
  -\> raw\_\* tabulka  
  -\> bronze incremental merge  
  -\> silver/gold tabulky
```

Pro reálnou produkční pipeline bych doporučil:

```
zdrojový systém  
  -\> ingestion/CDC nástroj  
  -\> raw tabulky  
  -\> dbt source()  
  -\> bronze incremental merge  
  -\> silver  
  -\> gold
```

Ve vašem repozitáři už existuje i Debezium/Kafka Connect část. Ta je vhodnější pro průběžné `INSERT`, `UPDATE` a `DELETE` změny než seed z CSV. Db­t by v takovém případě neměl raw data nahrávat, ale pouze je transformovat.




V tomto projektu je současný postup:

`CSV -\> dbt seed raw\_\* -\> incremental bronze\_\* -\> table silver\_\* -\> table gold\_\*`

Konkrétně:

- `seeds/raw\_supplies.csv` se načte jako tabulka `raw\_supplies`.

- bronze\_supplies.sql čte z `raw\_supplies`.

- `bronze\_supplies` je nastavený jako `incremental` se strategií `merge`.

- `unique\_key=\['supply\_id', 'product\_sku'\]` určuje, podle čeho se řádky identifikují.

**Kdy použít `seed`**

`seed` je vhodný hlavně pro:

- malé statické nebo referenční tabulky,

- testovací data,

- lookup tabulky,

- data, která jsou verzovaná společně s dbt projektem v Git repozitáři.

Například:

```
dbt seed --select raw\_supplies  
dbt run --select bronze\_supplies
```

Seed není vhodný jako hlavní mechanismus pro pravidelný ingest produkčních dat. Pro produkci se obvykle používá externí ingestion nástroj, například Airbyte, Fivetran, Kafka, Debezium nebo vlastní ETL. Ten zapisuje data do raw databázových tabulek a dbt je potom transformuje pomocí `source()`.

**Mažou se raw tabulky, nebo se přidávají další řádky?**

Seed se nechová jako append-only ingest. Tabulka se synchronizuje s obsahem CSV:

- řádek přidaný do CSV se objeví v tabulce,

- změněný řádek se aktualizuje,

- řádek odstraněný z CSV se po znovunačtení v tabulce také nemá nacházet.

Technický způsob, jakým dbt tabulku obnoví, závisí na adapteru, ale z pohledu uživatele je důležité toto: **seed není historický log a automaticky do něj nepřidává další a další kopie dat při každém spuštění**.

Pokud chcete raw historii, musí ji uchovávat upstream ingest nebo samostatná append-only tabulka. Alternativně lze pro sledování změn použít dbt snapshot, ale snapshot není totéž co seed.

**Co dělá `incremental\_strategy: merge`**

Při prvním běhu se incremental model vytvoří celý. Při dalších bězích dbt porovnává nové řádky se stávající cílovou tabulkou podle `unique\_key`.

Zjednodušeně:

```
pokud klíč existuje:  
    UPDATE existujícího řádku  
pokud klíč neexistuje:  
    INSERT nového řádku
```

U vašeho modelu:

```
\{\{ config(unique\_key=\['supply\_id', 'product\_sku'\]) \}\}
```

je klíčem dvojice:

```
supply\_id + product\_sku
```

Například:

```
SUP-001 + JAF-001  
SUP-001 + JAF-002
```

jsou dva různé záznamy.

`merge` sám o sobě obvykle nemaže řádky, které už nejsou ve zdrojovém datasetu. Pokud tedy odstraníte řádek z CSV, může starý řádek v `bronze\_supplies` zůstat. Pro synchronizaci včetně mazání je potřeba mazání explicitně řešit, například full refresh, delete logicí, snapshotem nebo upstream CDC.

**Důležitý detail ve vašem modelu**

Současný SQL model:

```
select  
    ...  
    current\_timestamp as bronze\_loaded\_at  
from \{\{ ref('raw\_supplies') \}\}
```

nemá podmínku `is\_incremental()`. To znamená, že při každém běhu znovu načte všechny řádky z `raw\_supplies` a `merge` je porovná s cílovou tabulkou. Výsledek bude funkčně správný, ale u velkých tabulek to nebude efektivní.

Typický incremental model by měl filtrovat pouze nové nebo změněné záznamy, například:

```
select  
    ...  
from \{\{ ref('raw\_supplies') \}\}  
  
\{% if is\_incremental() %\}  
where updated\_at \> (  
    select coalesce(max(updated\_at), '1900-01-01')  
    from \{\{ this \}\}  
)  
\{% endif %\}
```

To ale vyžaduje, aby zdrojová data měla například `updated\_at`, CDC timestamp nebo jiné pole umožňující určit novější záznamy.

**Doporučený postup**

Pro tento demo projekt je `seed` v pořádku:

```
CSV  
  -\> dbt seed  
  -\> raw\_\* tabulka  
  -\> bronze incremental merge  
  -\> silver/gold tabulky
```

Pro reálnou produkční pipeline bych doporučil:

```
zdrojový systém  
  -\> ingestion/CDC nástroj  
  -\> raw tabulky  
  -\> dbt source()  
  -\> bronze incremental merge  
  -\> silver  
  -\> gold
```

Ve vašem repozitáři už existuje i Debezium/Kafka Connect část. Ta je vhodnější pro průběžné `INSERT`, `UPDATE` a `DELETE` změny než seed z CSV. Db­t by v takovém případě neměl raw data nahrávat, ale pouze je transformovat.
























**CDC nástroj**

CDC znamená **Change Data Capture**, tedy zachytávání změn ve zdrojové databázi.

CDC nástroj průběžně sleduje databázi a posílá události například:

```
INSERT: nový zákazník  
UPDATE: změněná cena produktu  
DELETE: odstraněný obchod
```

Místo opakovaného načítání celé tabulky tedy přenáší pouze změny.

Ve vašem projektu tuto roli plní **Debezium**:

```
PostgreSQL source  
    -\> Debezium  
    -\> Kafka  
    -\> Kafka Connect JDBC sink  
    -\> PostgreSQL raw/bronze tabulky  
    -\> dbt  
    -\> silver/gold modely
```

Například když v PostgreSQL změníte cenu produktu:

```
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

```
select \*  
from \{\{ source('sales', 'orders') \}\}
```

To může odkazovat například na tabulku:

```
raw.sales\_orders
```

Konfigurace bývá v souboru `sources.yml`:

```
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

```
from \{\{ ref('raw\_supplies') \}\}
```

`ref()` znamená:

> Odkazuji na jiný dbt model nebo seed.

Proto `raw\_supplies` v současném projektu funguje jako seed z:

```
seeds/raw\_supplies.csv
```

Při produkčním CDC workflow by místo toho bylo typické:

```
from \{\{ source('raw', 'supplies') \}\}
```

Rozdíl:

| Funkce | Odkazuje na | Typický původ |
| - | - | - |
| `ref()` | jiný dbt model nebo seed | dbt |
| `source()` | externí zdrojovou tabulku | CDC, ETL, aplikace, datový sklad |


`ref()` zároveň dbt vytvoří závislost mezi modely. Db­t díky tomu ví, v jakém pořadí má modely spouštět.

Například:

```
raw\_supplies seed  
    -\> bronze\_supplies  
    -\> silver\_supplies  
    -\> dim\_supplies
```

`source()` zase označuje vstupní hranici dbt projektu:

```
Debezium/Kafka/ETL  
    -\> raw.supplies  
    -\> \{\{ source('raw', 'supplies') \}\}  
    -\> bronze\_supplies
```

Prakticky tedy:

- pro váš současný demo projekt: `ref('raw\_supplies')` je správně,

- pro produkční tabulky plněné Debezium nebo jiným ingestion nástrojem: použil bych `source('raw', 'supplies')`,

- `source()` sám data nenačítá; pouze dbt říká, kde externí data najde.


`dbt run` completed successfully through the project’s virtual environment.

All 23 models built successfully:

- 6 incremental bronze models

- 8 silver table models

- 9 gold table models

Result: `PASS=23 WARN=0 ERROR=0`

Use this command from sample-dbt-playground:

```
uv run dbt run \\  
  --project-dir product\_sales \\  
  --profiles-dir product\_sales
```

The traceback from plain `dbt run` is still caused by the broken global executable at dbt; it is unrelated to the dbt models or PostgreSQL connection.

# sample-dbt-playground




















User: jaky je spravny postup pro nahravani dat do DBT? mam tim namysli jestli pouzit seed?  akdyz ano tak raw tabulky se budou promazavat nebo se tam budou dalsi a dalsi zaznamy pridavat?  a k cemu je incremental strategy merge?

GitHub Copilot: Podívám se na konkrétní nastavení tohoto dbt projektu a na modely kolem `raw`/`bronze`, abych odpověď vztáhl přímo k vašemu workflow, ne jen k obecnému dbt. Ověřím hlavně, odkud se data načítají a zda už projekt používá incremental modely nebo snapshoty.

Read memory 

Read 

Searched for files matching `sample-dbt-playground` · `product\_sales/models/\*\*/\*.sql`, 23 matches

Searched for regex `materialized|incremental|strategy|raw\_|source\\(` (`sample-dbt-playground` · `product\_sales/\*\*`), 37 results

Z nastavení je už vidět důležitý detail: `raw\_\*` jsou v tomto projektu dbt seeds z CSV, zatímco `bronze\_\*` jsou incremental modely se strategií `merge`. Teď ještě ověřím konkrétní CSV/README a SQL jednotlivých vrstev, protože z toho plyne, zda je `raw` jen demo vstup, nebo má být skutečná historická landing vrstva.

Read 

Read 

Read , lines 1 to 20

Read 

V tomto projektu je současný postup:

`CSV -\> dbt seed raw\_\* -\> incremental bronze\_\* -\> table silver\_\* -\> table gold\_\*`

Konkrétně:

- `seeds/raw\_supplies.csv` se načte jako tabulka `raw\_supplies`.

- bronze\_supplies.sql čte z `raw\_supplies`.

- `bronze\_supplies` je nastavený jako `incremental` se strategií `merge`.

- `unique\_key=\['supply\_id', 'product\_sku'\]` určuje, podle čeho se řádky identifikují.

**Kdy použít `seed`**

`seed` je vhodný hlavně pro:

- malé statické nebo referenční tabulky,

- testovací data,

- lookup tabulky,

- data, která jsou verzovaná společně s dbt projektem v Git repozitáři.

Například:

```
dbt seed --select raw\_supplies  
dbt run --select bronze\_supplies
```

Seed není vhodný jako hlavní mechanismus pro pravidelný ingest produkčních dat. Pro produkci se obvykle používá externí ingestion nástroj, například Airbyte, Fivetran, Kafka, Debezium nebo vlastní ETL. Ten zapisuje data do raw databázových tabulek a dbt je potom transformuje pomocí `source()`.

**Mažou se raw tabulky, nebo se přidávají další řádky?**

Seed se nechová jako append-only ingest. Tabulka se synchronizuje s obsahem CSV:

- řádek přidaný do CSV se objeví v tabulce,

- změněný řádek se aktualizuje,

- řádek odstraněný z CSV se po znovunačtení v tabulce také nemá nacházet.

Technický způsob, jakým dbt tabulku obnoví, závisí na adapteru, ale z pohledu uživatele je důležité toto: **seed není historický log a automaticky do něj nepřidává další a další kopie dat při každém spuštění**.

Pokud chcete raw historii, musí ji uchovávat upstream ingest nebo samostatná append-only tabulka. Alternativně lze pro sledování změn použít dbt snapshot, ale snapshot není totéž co seed.

**Co dělá `incremental\_strategy: merge`**

Při prvním běhu se incremental model vytvoří celý. Při dalších bězích dbt porovnává nové řádky se stávající cílovou tabulkou podle `unique\_key`.

Zjednodušeně:

```
pokud klíč existuje:  
    UPDATE existujícího řádku  
pokud klíč neexistuje:  
    INSERT nového řádku
```

U vašeho modelu:

```
\{\{ config(unique\_key=\['supply\_id', 'product\_sku'\]) \}\}
```

je klíčem dvojice:

```
supply\_id + product\_sku
```

Například:

```
SUP-001 + JAF-001  
SUP-001 + JAF-002
```

jsou dva různé záznamy.

`merge` sám o sobě obvykle nemaže řádky, které už nejsou ve zdrojovém datasetu. Pokud tedy odstraníte řádek z CSV, může starý řádek v `bronze\_supplies` zůstat. Pro synchronizaci včetně mazání je potřeba mazání explicitně řešit, například full refresh, delete logicí, snapshotem nebo upstream CDC.

**Důležitý detail ve vašem modelu**

Současný SQL model:

```
select  
    ...  
    current\_timestamp as bronze\_loaded\_at  
from \{\{ ref('raw\_supplies') \}\}
```

nemá podmínku `is\_incremental()`. To znamená, že při každém běhu znovu načte všechny řádky z `raw\_supplies` a `merge` je porovná s cílovou tabulkou. Výsledek bude funkčně správný, ale u velkých tabulek to nebude efektivní.

Typický incremental model by měl filtrovat pouze nové nebo změněné záznamy, například:

```
select  
    ...  
from \{\{ ref('raw\_supplies') \}\}  
  
\{% if is\_incremental() %\}  
where updated\_at \> (  
    select coalesce(max(updated\_at), '1900-01-01')  
    from \{\{ this \}\}  
)  
\{% endif %\}
```

To ale vyžaduje, aby zdrojová data měla například `updated\_at`, CDC timestamp nebo jiné pole umožňující určit novější záznamy.

**Doporučený postup**

Pro tento demo projekt je `seed` v pořádku:

```
CSV  
  -\> dbt seed  
  -\> raw\_\* tabulka  
  -\> bronze incremental merge  
  -\> silver/gold tabulky
```

Pro reálnou produkční pipeline bych doporučil:

```
zdrojový systém  
  -\> ingestion/CDC nástroj  
  -\> raw tabulky  
  -\> dbt source()  
  -\> bronze incremental merge  
  -\> silver  
  -\> gold
```

Ve vašem repozitáři už existuje i Debezium/Kafka Connect část. Ta je vhodnější pro průběžné `INSERT`, `UPDATE` a `DELETE` změny než seed z CSV. Db­t by v takovém případě neměl raw data nahrávat, ale pouze je transformovat.


User: Co je to CDC nástroj? Co je dbt source()?

GitHub Copilot: **CDC nástroj**

CDC znamená **Change Data Capture**, tedy zachytávání změn ve zdrojové databázi.

CDC nástroj průběžně sleduje databázi a posílá události například:

```
INSERT: nový zákazník  
UPDATE: změněná cena produktu  
DELETE: odstraněný obchod
```

Místo opakovaného načítání celé tabulky tedy přenáší pouze změny.

Ve vašem projektu tuto roli plní **Debezium**:

```
PostgreSQL source  
    -\> Debezium  
    -\> Kafka  
    -\> Kafka Connect JDBC sink  
    -\> PostgreSQL raw/bronze tabulky  
    -\> dbt  
    -\> silver/gold modely
```

Například když v PostgreSQL změníte cenu produktu:

```
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

```
select \*  
from \{\{ source('sales', 'orders') \}\}
```

To může odkazovat například na tabulku:

```
raw.sales\_orders
```

Konfigurace bývá v souboru `sources.yml`:

```
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

```
from \{\{ ref('raw\_supplies') \}\}
```

`ref()` znamená:

> Odkazuji na jiný dbt model nebo seed.

Proto `raw\_supplies` v současném projektu funguje jako seed z:

```
seeds/raw\_supplies.csv
```

Při produkčním CDC workflow by místo toho bylo typické:

```
from \{\{ source('raw', 'supplies') \}\}
```

Rozdíl:

| Funkce | Odkazuje na | Typický původ |
| - | - | - |
| `ref()` | jiný dbt model nebo seed | dbt |
| `source()` | externí zdrojovou tabulku | CDC, ETL, aplikace, datový sklad |


`ref()` zároveň dbt vytvoří závislost mezi modely. Db­t díky tomu ví, v jakém pořadí má modely spouštět.

Například:

```
raw\_supplies seed  
    -\> bronze\_supplies  
    -\> silver\_supplies  
    -\> dim\_supplies
```

`source()` zase označuje vstupní hranici dbt projektu:

```
Debezium/Kafka/ETL  
    -\> raw.supplies  
    -\> \{\{ source('raw', 'supplies') \}\}  
    -\> bronze\_supplies
```

Prakticky tedy:

- pro váš současný demo projekt: `ref('raw\_supplies')` je správně,

- pro produkční tabulky plněné Debezium nebo jiným ingestion nástrojem: použil bych `source('raw', 'supplies')`,

- `source()` sám data nenačítá; pouze dbt říká, kde externí data najde.

User: jak mam nahrat vsechny data do cilovych tabulek pred spustenim dbt ru. Hlavne kde je mam nahrat? A taky zda je mam nahrat do raw tabulek nebo do bronze? nebo jak je to spravne?

GitHub Copilot: Zkontroluji ještě konkrétní konektorovou konfiguraci v projektu, protože zde jsou dvě možné databáze a názvy `raw`/`bronze` se mohou snadno zaměnit. Pak popíšu přesný pořadník příkazů pro váš současný seed workflow i pro CDC variantu.

Searched for files matching `sample-dbt-playground` · `product\_sales\_connector/connectors/\*.json`, 7 matches

Read 

Read 

Read , lines 1 to 100

V tomto projektu jsou dvě možné varianty. Pro začátek doporučuji použít tu první, protože odpovídá současnému nastavení dbt.

## Varianta 1: Data jsou v CSV souborech

V současném projektu jsou vstupní data zde:

```
product\_sales/seeds/raw\_\*.csv
```

Například:

```
product\_sales/seeds/raw\_supplies.csv  
product\_sales/seeds/raw\_products.csv  
product\_sales/seeds/raw\_orders.csv
```

Data tedy nahrajete nebo vložíte do těchto CSV souborů. **Nenahráváte je přímo do `bronze` tabulek.**

Potom spusťte z adresáře product\_sales:

```
dbt seed  
dbt run
```

Nebo vše najednou:

```
dbt build
```

Výsledek bude přibližně:

```
raw\_supplies       \<- vytvoří dbt seed z raw\_supplies.csv  
bronze\_supplies    \<- vytvoří nebo aktualizuje dbt model  
silver\_supplies    \<- vytvoří dbt model  
dim\_supplies       \<- vytvoří dbt model
```

Přesněji:

```
CSV soubor  
    -\> raw tabulka  
    -\> bronze tabulka  
    -\> silver tabulka  
    -\> gold tabulka
```

### Kam tedy nahrát data?

| Vrstva | Kdo ji plní | Co do ní patří |
| - | - | - |
| `raw` | seed nebo ingestion nástroj | původní data bez větších úprav |
| `bronze` | dbt | lehce očištěná a typovaná data |
| `silver` | dbt | transformovaná a obohacená data |
| `gold` | dbt | reportingové tabulky a dimenze/fakta |


Do `bronze` ručně nevkládejte data. V tomto projektu je `bronze` dbt model:

```
from \{\{ ref('raw\_supplies') \}\}
```

Dbt ho vytváří podle SQL definice v souboru bronze\_supplies.sql.

## Varianta 2: Data přicházejí z aplikace nebo jiné databáze

V produkčním řešení by aplikace zapisovala do zdrojové databáze, například:

```
aplikace  
    -\> PostgreSQL source  
    -\> CDC/ETL nástroj  
    -\> raw tabulky  
    -\> dbt  
    -\> bronze/silver/gold
```

V takovém případě se data nenahrávají do CSV ani přímo do bronze. Ingestion nástroj je zapíše do `raw` tabulek. Db­t je potom načte přes:

```
from \{\{ source('raw', 'supplies') \}\}
```

Konfigurace by mohla vypadat takto:

```
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

```
select  
    cast(id as varchar) as supply\_id,  
    cast(name as varchar) as supply\_name,  
    cast(cost as numeric) as cost,  
    cast(perishable as boolean) as is\_perishable,  
    cast(sku as varchar) as product\_sku,  
    current\_timestamp as bronze\_loaded\_at  
from \{\{ source('raw', 'supplies') \}\}
```

## Jak to souvisí s vaším Debezium konektorem?

Ve vašem repozitáři je trochu specifické zapojení:

```
dbt vytvoří bronze tabulky v source PostgreSQL  
    -\> Debezium zachytí jejich změny  
    -\> Kafka  
    -\> JDBC sink  
    -\> target PostgreSQL
```

Podle konfigurace se Debezium připojuje ke zdrojové PostgreSQL na portu `5431` a kopíruje tabulky `product\_sales\_bronze.bronze\_\*` do cílové PostgreSQL na portu `5432`.

Pro první naplnění tedy postup v tomto projektu vypadá takto:

```
cd /home/jan/Desktop/sample-dbt-playground/product\_sales  
  
dbt seed  
dbt run
```

Tím vzniknou a naplní se `raw\_\*` a `bronze\_\*` tabulky ve zdrojové databázi. Poté Debezium při `snapshot.mode=initial` provede počáteční snapshot bronze tabulek do cílové databáze.

Následně:

```
nový nebo změněný řádek  
    -\> dbt aktualizuje bronze  
    -\> Debezium zachytí změnu  
    -\> Kafka  
    -\> cílová databáze
```

## Co bych doporučil pro váš případ

Pro aktuální demo:

1. Vložte kompletní data do `product\_sales/seeds/raw\_\*.csv`.

2. Zkontrolujte, že CSV neobsahují duplicitní klíče.

3. Spusťte:

```
dbt seed  
dbt build
```

1. Teprve potom spusťte nebo zaregistrujte Debezium/Kafka Connect konektory.

Pro produkční řešení:

```
aplikace/zdrojová DB  
    -\> CDC nebo ETL  
    -\> raw tabulky  
    -\> dbt source()  
    -\> bronze  
    -\> silver  
    -\> gold
```

Nejdůležitější pravidlo je:

> Data se načítají do `raw`; `bronze`, `silver` a `gold` vytváří dbt.

