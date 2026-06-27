select
  to_regprocedure('public.claim_pending_payment_orders_sharded(integer,text,text,text,integer,integer,integer)') is not null
    as function_claim_pending_payment_orders_sharded,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'payment_scanner_heartbeats'
      and column_name = 'scan_jitter_ms'
  ) as heartbeat_scan_jitter_ms_column,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'payment_scanner_heartbeats'
      and column_name = 'scan_concurrency'
  ) as heartbeat_scan_concurrency_column,
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'idx_payment_orders_scanner_claim_100x'
  ) as index_payment_orders_scanner_claim_100x,
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'idx_payment_scanner_heartbeats_live_100x'
  ) as index_payment_scanner_heartbeats_live_100x,
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'idx_payment_orders_user_status_100x'
  ) as index_payment_orders_user_status_100x,
  now() as checked_at;
