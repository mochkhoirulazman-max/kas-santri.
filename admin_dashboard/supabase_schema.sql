-- ============================================================================
-- KAS-SANTRI ADMIN COMMAND CENTER — SKEMA CLOUD BACKEND (SUPABASE FREE TIER)
-- ============================================================================
-- Salin seluruh skrip ini ke: Supabase Dashboard -> SQL Editor -> New Query -> Run.
-- Bersifat idempoten (aman dijalankan ulang) dan dilindungi Row Level Security (RLS) ketat.
-- APK klien HANYA mengirim telemetri lisensi non-sensitif (TIDAK PERNAH mengirim data santri/saldo).

create extension if not exists pgcrypto;

-- 1. Tabel Daftar Akun Admin Resmi (hanya email terdaftar yang punya akses penuh CRM & omset)
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  created_at timestamptz not null default now()
);

-- 2. Fungsi Helper Verifikasi Admin
create or replace function public.is_kas_santri_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_users au
    where au.user_id = auth.uid()
  );
$$;

-- 3. Tabel Pelanggan APK (CRM Perangkat Pondok)
create table if not exists public.app_customers (
  device_id text primary key,
  nama_pondok text not null default '',
  nama_bendahara text not null default '',
  no_wa text not null default '',
  tier text not null default 'FREE', -- FREE, TRIAL_14D, MONTHLY, YEARLY, LIFETIME
  status text not null default 'GRATIS', -- AKTIF, TRIAL, GRATIS, EXPIRED, DIBLOKIR
  expiry_date timestamptz null,
  trial_started_at timestamptz null,
  last_seen_at timestamptz not null default now(),
  app_version text not null default '4.2.0',
  total_paid_idr bigint not null default 0,
  payment_channel text not null default 'FREE', -- FREE, TRIAL, DANA, PLAY_STORE
  is_revoked boolean not null default false,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_app_customers_tier on public.app_customers (tier);
create index if not exists idx_app_customers_expiry on public.app_customers (expiry_date);
create index if not exists idx_app_customers_last_seen on public.app_customers (last_seen_at desc);

-- 4. Tabel Riwayat Transaksi Lisensi & Omset Admin
create table if not exists public.license_transactions (
  id uuid primary key default gen_random_uuid(),
  device_id text not null references public.app_customers(device_id) on delete cascade,
  paket text not null, -- MONTHLY, YEARLY, LIFETIME
  nominal_idr bigint not null default 0,
  metode_bayar text not null default 'DANA', -- DANA, PLAY_STORE
  kode_lisensi text null,
  created_at timestamptz not null default now()
);

create index if not exists idx_license_tx_created on public.license_transactions (created_at desc);
create index if not exists idx_license_tx_device on public.license_transactions (device_id);

-- 5. Tabel Remote Config & Pengumuman Update Aplikasi (Singleton id = 1)
create table if not exists public.app_remote_config (
  id integer primary key default 1 check (id = 1),
  latest_version text not null default '4.2.0',
  min_version text not null default '3.0.0',
  announcement_title text not null default '',
  announcement_body text not null default '',
  promo_banner_active boolean not null default false,
  update_url text not null default '',
  updated_at timestamptz not null default now()
);

insert into public.app_remote_config (
  id,
  latest_version,
  min_version,
  announcement_title,
  announcement_body,
  promo_banner_active,
  update_url
)
values (
  1,
  '4.2.0',
  '3.0.0',
  '',
  '',
  false,
  'https://mochkhoirulazman-max.github.io/kas-santri./'
)
on conflict (id) do nothing;

-- ============================================================================
-- AKTIVASI ROW LEVEL SECURITY (RLS) KETAT
-- ============================================================================
alter table public.admin_users enable row level security;
alter table public.app_customers enable row level security;
alter table public.license_transactions enable row level security;
alter table public.app_remote_config enable row level security;

-- Hapus policy lama jika dijalankan ulang
drop policy if exists "admin_users_admin_only" on public.admin_users;
drop policy if exists "app_customers_admin_all" on public.app_customers;
drop policy if exists "license_transactions_admin_all" on public.license_transactions;
drop policy if exists "remote_config_public_read" on public.app_remote_config;
drop policy if exists "remote_config_admin_write" on public.app_remote_config;

-- Hanya Admin terautentikasi yang boleh membaca admin_users, app_customers, dan license_transactions
create policy "admin_users_admin_only"
  on public.admin_users
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (public.is_kas_santri_admin());

create policy "app_customers_admin_all"
  on public.app_customers
  for all
  to authenticated
  using (public.is_kas_santri_admin())
  with check (public.is_kas_santri_admin());

create policy "license_transactions_admin_all"
  on public.license_transactions
  for all
  to authenticated
  using (public.is_kas_santri_admin())
  with check (public.is_kas_santri_admin());

-- Remote config boleh dibaca APK publik, hanya Admin yang bisa mengubah
create policy "remote_config_public_read"
  on public.app_remote_config
  for select
  to anon, authenticated
  using (true);

create policy "remote_config_admin_write"
  on public.app_remote_config
  for all
  to authenticated
  using (public.is_kas_santri_admin())
  with check (public.is_kas_santri_admin());

-- ============================================================================
-- RPC AMAN UNTUK APK KLIEN (TELEMETRI NON-SENSITIF + CEK REMOTE REVOKE)
-- ============================================================================
-- Klien anonim HANYA boleh upsert perangkatnya sendiri dan membaca is_revoked + remote_config.
-- Klien TIDAK PERNAH dapat membaca daftar pelanggan lain atau mengubah is_revoked/total_paid_idr.
create or replace function public.sync_device_telemetry(
  p_device_id text,
  p_nama_pondok text default '',
  p_nama_bendahara text default '',
  p_no_wa text default '',
  p_tier text default 'FREE',
  p_expiry_date timestamptz default null,
  p_app_version text default '4.2.0',
  p_payment_channel text default 'FREE'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id text := upper(trim(coalesce(p_device_id, '')));
  v_tier text := upper(trim(coalesce(p_tier, 'FREE')));
  v_channel text := upper(trim(coalesce(p_payment_channel, 'FREE')));
  v_status text;
  v_row public.app_customers%rowtype;
  v_cfg public.app_remote_config%rowtype;
begin
  -- Validasi format Device ID sesuai LicenseService.getOrCreateDeviceId() (KS-XXXXXXXX maupun format lama KS-XXXX-XXXX)
  if v_device_id !~ '^KS-[A-Z0-9]{4,16}(-[A-Z0-9]{4,16})?$' then
    raise exception 'device_id tidak valid (wajib format KS-XXXXXXXX)';
  end if;

  if v_tier not in ('FREE', 'TRIAL_14D', 'MONTHLY', 'YEARLY', 'LIFETIME') then
    v_tier := 'FREE';
  end if;

  if v_channel not in ('FREE', 'TRIAL', 'DANA', 'PLAY_STORE') then
    v_channel := 'FREE';
  end if;

  -- Cegah klien anonim menaikkan tier sepihak ke paket berbayar tanpa bukti transaksi sah di license_transactions
  -- (kecuali kanal PLAY_STORE atau pelanggan yang memang sudah diaktifkan Admin di app_customers)
  if v_tier in ('MONTHLY', 'YEARLY', 'LIFETIME') and v_channel <> 'PLAY_STORE' then
    if not exists (
      select 1
      from public.license_transactions lt
      where lt.device_id = v_device_id
    ) and not exists (
      select 1
      from public.app_customers ac
      where ac.device_id = v_device_id
        and ac.tier in ('MONTHLY', 'YEARLY', 'LIFETIME')
        and not ac.is_revoked
    ) then
      v_tier := 'FREE';
      v_channel := 'FREE';
    end if;
  end if;

  if v_tier = 'TRIAL_14D' then
    v_status := case when p_expiry_date is not null and p_expiry_date < now() then 'EXPIRED' else 'TRIAL' end;
  elsif v_tier in ('MONTHLY', 'YEARLY', 'LIFETIME') then
    v_status := case when v_tier <> 'LIFETIME' and p_expiry_date is not null and p_expiry_date < now() then 'EXPIRED' else 'AKTIF' end;
  else
    v_status := 'GRATIS';
  end if;

  insert into public.app_customers (
    device_id,
    nama_pondok,
    nama_bendahara,
    no_wa,
    tier,
    status,
    expiry_date,
    trial_started_at,
    last_seen_at,
    app_version,
    payment_channel,
    updated_at
  )
  values (
    v_device_id,
    left(trim(coalesce(p_nama_pondok, '')), 120),
    left(trim(coalesce(p_nama_bendahara, '')), 120),
    left(trim(coalesce(p_no_wa, '')), 32),
    v_tier,
    v_status,
    p_expiry_date,
    case when v_tier = 'TRIAL_14D' then now() else null end,
    now(),
    left(trim(coalesce(p_app_version, '4.2.0')), 32),
    v_channel,
    now()
  )
  on conflict (device_id) do update set
    nama_pondok = case when length(trim(excluded.nama_pondok)) > 0 then excluded.nama_pondok else app_customers.nama_pondok end,
    nama_bendahara = case when length(trim(excluded.nama_bendahara)) > 0 then excluded.nama_bendahara else app_customers.nama_bendahara end,
    no_wa = case when length(trim(excluded.no_wa)) > 0 then excluded.no_wa else app_customers.no_wa end,
    -- Jika sudah diblokir admin (is_revoked), jangan timpa status menjadi AKTIF dari sisi klien
    tier = case when app_customers.is_revoked then 'FREE' else excluded.tier end,
    status = case when app_customers.is_revoked then 'DIBLOKIR' else excluded.status end,
    expiry_date = case when app_customers.is_revoked then null else coalesce(excluded.expiry_date, app_customers.expiry_date) end,
    trial_started_at = coalesce(app_customers.trial_started_at, excluded.trial_started_at),
    payment_channel = case when app_customers.payment_channel in ('DANA', 'PLAY_STORE') and excluded.payment_channel in ('FREE', 'TRIAL')
      then app_customers.payment_channel else excluded.payment_channel end,
    last_seen_at = now(),
    app_version = excluded.app_version,
    updated_at = now()
  returning * into v_row;

  select * into v_cfg from public.app_remote_config where id = 1;

  return jsonb_build_object(
    'device_id', v_row.device_id,
    'is_revoked', v_row.is_revoked,
    'status', v_row.status,
    'tier', v_row.tier,
    'remote_config', case
      when v_cfg.id is null then null
      else jsonb_build_object(
        'latest_version', v_cfg.latest_version,
        'min_version', v_cfg.min_version,
        'announcement_title', v_cfg.announcement_title,
        'announcement_body', v_cfg.announcement_body,
        'promo_banner_active', v_cfg.promo_banner_active,
        'update_url', v_cfg.update_url
      )
    end
  );
end;
$$;

revoke all on function public.sync_device_telemetry(text, text, text, text, text, timestamptz, text, text) from public;
grant execute on function public.sync_device_telemetry(text, text, text, text, text, timestamptz, text, text) to anon, authenticated;

-- ============================================================================
-- 6. TABEL & RPC CLOUD BACKUP ONLINE TERENKRIPSI (SUPABASE CLOUD VAULT v4.3)
-- ============================================================================
-- Payload WAJIB dienkripsi AES-256-GCM (.KSBAK) di perangkat sebelum diunggah.
-- Server cloud tidak pernah menyimpan atau mengetahui password maupun isi data pondok.
create table if not exists public.app_cloud_backups (
  backup_key text primary key,
  device_id text not null default '',
  nama_pondok text not null default '',
  payload_encrypted text not null,
  app_version text not null default '4.3.0',
  size_bytes integer not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists idx_cloud_backups_updated on public.app_cloud_backups (updated_at desc);

alter table public.app_cloud_backups enable row level security;
drop policy if exists "app_cloud_backups_admin_all" on public.app_cloud_backups;
create policy "app_cloud_backups_admin_all"
  on public.app_cloud_backups
  for all
  to authenticated
  using (public.is_kas_santri_admin())
  with check (public.is_kas_santri_admin());

create or replace function public.upsert_cloud_backup(
  p_backup_key text,
  p_device_id text default '',
  p_nama_pondok text default '',
  p_payload_encrypted text default '',
  p_app_version text default '4.3.0'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := upper(regexp_replace(trim(coalesce(p_backup_key, '')), '[^A-Za-z0-9_-]', '', 'g'));
  v_payload text := trim(coalesce(p_payload_encrypted, ''));
  v_size integer := octet_length(v_payload);
  v_row public.app_cloud_backups%rowtype;
begin
  if length(v_key) < 4 or length(v_key) > 48 then
    raise exception 'Kode Backup Pondok wajib 4-48 karakter (huruf, angka, -, _).';
  end if;
  if v_size = 0 or v_size > 8000000 then
    raise exception 'Payload backup terenkripsi tidak valid atau melebihi batas 8 MB.';
  end if;

  insert into public.app_cloud_backups (
    backup_key,
    device_id,
    nama_pondok,
    payload_encrypted,
    app_version,
    size_bytes,
    updated_at
  )
  values (
    v_key,
    left(upper(trim(coalesce(p_device_id, ''))), 48),
    left(trim(coalesce(p_nama_pondok, '')), 120),
    v_payload,
    left(trim(coalesce(p_app_version, '4.3.0')), 32),
    v_size,
    now()
  )
  on conflict (backup_key) do update set
    device_id = excluded.device_id,
    nama_pondok = excluded.nama_pondok,
    payload_encrypted = excluded.payload_encrypted,
    app_version = excluded.app_version,
    size_bytes = excluded.size_bytes,
    updated_at = now()
  returning * into v_row;

  return jsonb_build_object(
    'ok', true,
    'backup_key', v_row.backup_key,
    'size_bytes', v_row.size_bytes,
    'updated_at', v_row.updated_at
  );
end;
$$;

create or replace function public.fetch_cloud_backup(
  p_backup_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := upper(regexp_replace(trim(coalesce(p_backup_key, '')), '[^A-Za-z0-9_-]', '', 'g'));
  v_row public.app_cloud_backups%rowtype;
begin
  if length(v_key) < 4 or length(v_key) > 48 then
    raise exception 'Kode Backup Pondok wajib 4-48 karakter.';
  end if;

  select * into v_row
  from public.app_cloud_backups
  where backup_key = v_key
  limit 1;

  if v_row.backup_key is null then
    return jsonb_build_object(
      'found', false,
      'backup_key', v_key
    );
  end if;

  return jsonb_build_object(
    'found', true,
    'backup_key', v_row.backup_key,
    'nama_pondok', v_row.nama_pondok,
    'payload_encrypted', v_row.payload_encrypted,
    'app_version', v_row.app_version,
    'size_bytes', v_row.size_bytes,
    'updated_at', v_row.updated_at
  );
end;
$$;

revoke all on function public.upsert_cloud_backup(text, text, text, text, text) from public;
grant execute on function public.upsert_cloud_backup(text, text, text, text, text) to anon, authenticated;

revoke all on function public.fetch_cloud_backup(text) from public;
grant execute on function public.fetch_cloud_backup(text) to anon, authenticated;

-- ============================================================================
-- LANGKAH TERAKHIR WAJIB (DAFTARKAN AKUN ADMIN ANDA):
-- 1. Buat user Admin di Supabase -> Authentication -> Users -> Add user (email & password).
-- 2. Jalankan query ini dengan mengganti email admin Anda:
--
-- insert into public.admin_users (user_id, email)
-- select id, email from auth.users where email = 'admin@pondokanda.com'
-- on conflict (user_id) do nothing;
-- ============================================================================
