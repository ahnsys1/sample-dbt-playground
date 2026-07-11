with source_dates as (

    select order_date as date_day
    from {{ ref('silver_orders') }}

    union

    select cast(opened_at as date) as date_day
    from {{ ref('silver_stores') }}

),

dates as (

    select distinct date_day
    from source_dates
    where date_day is not null

)

select
    cast(to_char(date_day, 'YYYYMMDD') as integer) as date_id,
    date_day,
    extract(year from date_day)::integer as year_number,
    extract(quarter from date_day)::integer as quarter_number,
    extract(month from date_day)::integer as month_number,
    extract(day from date_day)::integer as day_of_month,
    extract(isodow from date_day)::integer as day_of_week,
    to_char(date_day, 'Day') as day_name,
    to_char(date_day, 'Month') as month_name
from dates