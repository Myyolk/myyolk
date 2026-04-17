-- MyYolk — Monthly Check-In Reminder Setup
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor)

-- ── Step 1: Enable pg_cron extension ─────────────────────────────────────────
-- (Only needed once. If already enabled, skip this.)
create extension if not exists pg_cron;

-- ── Step 2: Grant usage to postgres role ─────────────────────────────────────
grant usage on schema cron to postgres;

-- ── Step 3: Schedule the edge function on the 3rd of every month at 9am UTC ──
-- This calls the edge function via HTTP using Supabase's internal invoke mechanism.
-- Replace YOUR_PROJECT_REF with your actual Supabase project ref (e.g. lcecdqihjdpmsmiwabkk)

select cron.schedule(
  'myyolk-monthly-checkin-reminder',   -- job name (unique)
  '0 9 3 * *',                          -- cron: 9:00 AM UTC on the 3rd of every month
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-checkin-reminder',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- ── Step 4: Verify the job was created ───────────────────────────────────────
select jobid, jobname, schedule, active from cron.job;

-- ── To manually trigger for testing (run in SQL editor) ──────────────────────
-- select net.http_post(
--   url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-checkin-reminder',
--   headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb,
--   body := '{}'::jsonb
-- );

-- ── To remove the job if needed ───────────────────────────────────────────────
-- select cron.unschedule('myyolk-monthly-checkin-reminder');
