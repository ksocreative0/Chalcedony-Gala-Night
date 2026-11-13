-- CHALCEDONY GALA: additive update for the existing live project
-- Safe for existing staff/gallery uploads: no storage objects or staff image URLs are changed.
-- Run once in Supabase SQL Editor.

-- Keep department IDs intact so existing staff records and their uploaded pictures remain linked.
UPDATE public.departments SET name='Executive Director and Heads', sort_order=1 WHERE name='Head of School';
UPDATE public.departments SET name='Administrative Department', sort_order=2 WHERE name='Administration';
UPDATE public.departments SET name='High School', sort_order=3 WHERE name='Senior Secondary';
UPDATE public.departments SET name='Junior School', sort_order=4 WHERE name='Junior Secondary';
UPDATE public.departments SET name='Preschool', sort_order=5 WHERE name='Preschool';
UPDATE public.departments SET name='Support Staff', sort_order=6 WHERE name='Support Staff';

-- RSVP sponsorship data is stored with the original RSVP; no separate guest record is created.
ALTER TABLE public.rsvps
  ADD COLUMN IF NOT EXISTS is_sponsoring BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS sponsored_category_id UUID NULL REFERENCES public.award_categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS sponsored_item TEXT NULL,
  ADD COLUMN IF NOT EXISTS sponsorship_delivery_date DATE NULL;

ALTER TABLE public.rsvps
  DROP CONSTRAINT IF EXISTS rsvps_sponsorship_delivery_date_check;
ALTER TABLE public.rsvps
  ADD CONSTRAINT rsvps_sponsorship_delivery_date_check
  CHECK (sponsorship_delivery_date IS NULL OR sponsorship_delivery_date <= DATE '2026-12-18');

ALTER TABLE public.rsvps
  DROP CONSTRAINT IF EXISTS rsvps_sponsorship_fields_check;
ALTER TABLE public.rsvps
  ADD CONSTRAINT rsvps_sponsorship_fields_check
  CHECK (
    (is_sponsoring = FALSE AND sponsored_category_id IS NULL AND sponsored_item IS NULL AND sponsorship_delivery_date IS NULL)
    OR
    (is_sponsoring = TRUE AND sponsored_category_id IS NOT NULL AND NULLIF(TRIM(sponsored_item),'') IS NOT NULL AND sponsorship_delivery_date IS NOT NULL)
  );

CREATE INDEX IF NOT EXISTS rsvps_sponsored_category_idx ON public.rsvps(sponsored_category_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rsvps TO authenticated;
GRANT INSERT ON public.rsvps TO anon;

-- Ensure the department order is exactly as requested, including any differently cased legacy names.
