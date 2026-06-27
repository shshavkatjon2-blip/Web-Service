-- VidiPay hyperscale SQL.
-- Safe additive migration: no deletes, no drops.

select now() as vidipay_hyperscale_sql_started_at;

create table if not exists public.payment_scanner_heartbeats (
  worker_id text primary key,
  worker_mode text,
  network text,
  token text,
  scanner_enabled boolean default false,
  running boolean default false,
  last_seen_at timestamptz,
  last_run_at timestamptz,
  last_error text,
  checked_total bigint default 0,
  confirmed_total bigint default 0,
  scan_interval_ms integer,
  scan_batch_size integer,
  updated_at timestamptz default now()
);

do $$
begin
  execute 'alter table public.payment_scanner_heartbeats add column if not exists shard_count integer default 1';
  execute 'alter table public.payment_scanner_heartbeats add column if not exists shard_index integer default 0';
  execute 'alter table public.payment_scanner_heartbeats add column if not exists scan_concurrency integer default 1';
  execute 'alter table public.payment_scanner_heartbeats add column if not exists scan_jitter_ms integer default 0';
  execute 'alter table public.payment_scanner_heartbeats add column if not exists scan_order_delay_ms integer default 0';
  execute 'alter table public.payment_scanner_heartbeats add column if not exists scan_max_errors_per_run integer default 500';

  execute 'create unique index if not exists payment_scanner_heartbeats_worker_id_uidx
    on public.payment_scanner_heartbeats (worker_id)';

  execute 'create index if not exists idx_payment_scanner_heartbeats_live_hyperscale
    on public.payment_scanner_heartbeats (network, token, worker_mode, last_seen_at desc)';

  execute 'create index if not exists idx_payment_scanner_heartbeats_shard_hyperscale
    on public.payment_scanner_heartbeats (network, token, shard_count, shard_index, last_seen_at desc)';
end $$;

do $$
begin
  if to_regclass('public.payment_orders') is null then
    raise notice 'Skipped hyperscale payment order SQL: public.payment_orders table does not exist.';
  else
    execute 'alter table public.payment_orders add column if not exists scanner_claimed_until timestamptz';
    execute 'alter table public.payment_orders add column if not exists scanner_claimed_by text';
    execute 'alter table public.payment_orders add column if not exists last_checked_at timestamptz';
    execute 'alter table public.payment_orders add column if not exists network text default ''TON''';
    execute 'alter table public.payment_orders add column if not exists token text default ''TON''';
    execute 'alter table public.payment_orders add column if not exists updated_at timestamptz default now()';
    execute 'alter table public.payment_orders add column if not exists created_at timestamptz default now()';
    execute 'alter table public.payment_orders add column if not exists status text default ''pending''';
    execute 'alter table public.payment_orders add column if not exists wallet_address text';

    execute 'update public.payment_orders set network = ''TON'' where network is null or trim(network) = ''''';
    execute 'update public.payment_orders set token = ''TON'' where token is null or trim(token) = '''' or upper(token) = ''TONCOIN''';

    execute 'create index if not exists idx_payment_orders_scanner_claim_hyperscale
      on public.payment_orders (status, network, token, scanner_claimed_until, last_checked_at, created_at)
      where wallet_address is not null';

    execute 'create index if not exists idx_payment_orders_pending_wallet_hyperscale
      on public.payment_orders (network, token, wallet_address, created_at desc)
      where status = ''pending'' and wallet_address is not null';

    execute 'create index if not exists idx_payment_orders_scanner_worker_hyperscale
      on public.payment_orders (scanner_claimed_by, scanner_claimed_until)
      where scanner_claimed_by is not null';

    execute 'create index if not exists idx_payment_orders_user_status_hyperscale
      on public.payment_orders (telegram_id, status, created_at desc)
      where telegram_id is not null';
  end if;

  if to_regclass('public.payment_transactions') is not null then
    execute 'create index if not exists idx_payment_transactions_created_hyperscale
      on public.payment_transactions (created_at desc)';
    execute 'create index if not exists idx_payment_transactions_wallet_created_hyperscale
      on public.payment_transactions (to_wallet, created_at desc)
      where to_wallet is not null';
    execute 'create index if not exists idx_payment_transactions_tx_hash_hyperscale
      on public.payment_transactions (tx_hash)
      where tx_hash is not null';
  end if;

  if to_regclass('public.view_logs') is not null then
    execute 'create index if not exists idx_view_logs_created_hyperscale
      on public.view_logs (created_at desc)';
    execute 'create index if not exists idx_view_logs_user_created_hyperscale
      on public.view_logs (telegram_id, created_at desc)
      where telegram_id is not null';
  end if;
end $$;

create or replace function public.claim_pending_payment_orders_sharded(
  p_limit integer,
  p_worker_id text,
  p_network text default 'TON',
  p_token text default 'TON',
  p_claim_seconds integer default 90,
  p_shard_count integer default 1,
  p_shard_index integer default 0
)
returns setof public.payment_orders
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 500), 1), 5000);
  v_claim_seconds integer := least(greatest(coalesce(p_claim_seconds, 90), 15), 900);
  v_shard_count integer := least(greatest(coalesce(p_shard_count, 1), 1), 2048);
  v_shard_index integer := greatest(coalesce(p_shard_index, 0), 0);
begin
  if v_shard_index >= v_shard_count then
    raise exception 'Invalid scanner shard index %, count %', v_shard_index, v_shard_count;
  end if;

  return query
  with picked as (
    select payment_orders.id
    from public.payment_orders
    where payment_orders.status = 'pending'
      and payment_orders.network = p_network
      and payment_orders.token = p_token
      and payment_orders.wallet_address is not null
      and (
        payment_orders.scanner_claimed_until is null
        or payment_orders.scanner_claimed_until <= now()
      )
      and (
        v_shard_count = 1
        or mod(
          hashtext(coalesce(payment_orders.wallet_address, payment_orders.id::text))::bigint + 2147483648,
          v_shard_count::bigint
        ) = v_shard_index::bigint
      )
    order by
      payment_orders.last_checked_at asc nulls first,
      payment_orders.created_at asc
    for update skip locked
    limit v_limit
  )
  update public.payment_orders target
  set
    scanner_claimed_until = now() + make_interval(secs => v_claim_seconds),
    scanner_claimed_by = p_worker_id,
    updated_at = now()
  where target.id in (select picked.id from picked)
  returning target.*;
end;
$fn$;

select
  'vidipay_hyperscale_sql_finished' as check_name,
  to_regprocedure('public.claim_pending_payment_orders_sharded(integer,text,text,text,integer,integer,integer)') is not null as function_claim_pending_payment_orders_sharded,
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'payment_scanner_heartbeats'
      and column_name = 'scan_order_delay_ms'
  ) as heartbeat_backpressure_ready,
  now() as finished_at;
