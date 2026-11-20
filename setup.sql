-- ============================================================
-- CHALCEDONY SCHOOL GALA NIGHT - DATABASE SETUP
-- Run this script in Supabase SQL Editor on a NEW project.
-- Event date: 18 December 2026 | Timezone: Africa/Lagos
-- ============================================================

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'admin'
    CHECK (role IN ('admin','super_admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.event_settings (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  event_title TEXT NOT NULL DEFAULT 'Chalcedony School Gala Night',
  event_date DATE NOT NULL DEFAULT '2026-12-18',
  event_time TEXT,
  timezone TEXT NOT NULL DEFAULT 'Africa/Lagos',
  venue_name TEXT DEFAULT 'Patron Hotel',
  venue_address TEXT,
  venue_map_url TEXT,
  head_name TEXT,
  head_role TEXT DEFAULT 'Head of School',
  head_message TEXT,
  head_image_url TEXT,
  event_description TEXT,
  voting_open BOOLEAN NOT NULL DEFAULT TRUE,
  results_published BOOLEAN NOT NULL DEFAULT FALSE,
  results_published_at TIMESTAMPTZ,
  rsvp_open BOOLEAN NOT NULL DEFAULT TRUE,
  rsvp_closes_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO public.event_settings(id) VALUES (1) ON CONFLICT DO NOTHING;

CREATE TABLE public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO public.departments(name,sort_order) VALUES
 ('Executive Director and Heads',1),('Administrative Department',2),('High School',3),
 ('Junior School',4),('Preschool',5),('Support Staff',6)
ON CONFLICT(name) DO NOTHING;

CREATE TABLE public.staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  full_name TEXT NOT NULL,
  designation TEXT NOT NULL,
  image_url TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.award_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  voting_open BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.award_nominees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.award_categories(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES public.staff(id) ON DELETE RESTRICT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(category_id,staff_id),
  UNIQUE(id,category_id)
);

CREATE TABLE public.votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL,
  nominee_id UUID NOT NULL,
  voter_key UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT votes_nominee_category_fk
    FOREIGN KEY(nominee_id,category_id)
    REFERENCES public.award_nominees(id,category_id) ON DELETE CASCADE,
  UNIQUE(category_id,voter_key)
);

CREATE TABLE public.rsvps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  attendance_decision TEXT NOT NULL
    CHECK(attendance_decision IN ('attending','not_attending','undecided')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_sponsoring BOOLEAN NOT NULL DEFAULT FALSE,
  sponsored_category_id UUID NULL REFERENCES public.award_categories(id) ON DELETE SET NULL,
  sponsored_item TEXT NULL,
  sponsorship_delivery_date DATE NULL,
  CONSTRAINT rsvps_sponsorship_delivery_date_check CHECK (sponsorship_delivery_date IS NULL OR sponsorship_delivery_date <= DATE '2026-12-18'),
  CONSTRAINT rsvps_sponsorship_fields_check CHECK (
    (is_sponsoring = FALSE AND sponsored_category_id IS NULL AND sponsored_item IS NULL AND sponsorship_delivery_date IS NULL)
    OR (is_sponsoring = TRUE AND sponsored_category_id IS NOT NULL AND NULLIF(TRIM(sponsored_item),'') IS NOT NULL AND sponsorship_delivery_date IS NOT NULL)
  )
);
CREATE UNIQUE INDEX rsvps_email_unique ON public.rsvps(LOWER(TRIM(email)));

CREATE TABLE public.event_programme (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity TEXT NOT NULL,
  description TEXT,
  start_time TIME,
  end_time TIME,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at=NOW(); RETURN NEW; END; $$;

CREATE TRIGGER event_settings_updated BEFORE UPDATE ON public.event_settings
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER staff_updated BEFORE UPDATE ON public.staff
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER categories_updated BEFORE UPDATE ON public.award_categories
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER rsvps_updated BEFORE UPDATE ON public.rsvps
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER programme_updated BEFORE UPDATE ON public.event_programme
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Admin existence check. Admin profiles are provisioned manually in SQL,
-- not through a public sign-up form.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id=(SELECT auth.uid())
  );
$$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.award_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.award_nominees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_programme ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read profiles" ON public.profiles FOR SELECT TO authenticated
USING(public.is_admin());
CREATE POLICY "Admins update profiles" ON public.profiles FOR UPDATE TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());

CREATE POLICY "Public read event settings" ON public.event_settings FOR SELECT TO anon,authenticated USING(TRUE);
CREATE POLICY "Admins manage event settings" ON public.event_settings FOR ALL TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());

CREATE POLICY "Public read active departments" ON public.departments FOR SELECT TO anon,authenticated
USING(is_active=TRUE OR public.is_admin());
CREATE POLICY "Admins manage departments" ON public.departments FOR ALL TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());

CREATE POLICY "Public read active staff" ON public.staff FOR SELECT TO anon,authenticated
USING(is_active=TRUE OR public.is_admin());
CREATE POLICY "Admins manage staff" ON public.staff FOR ALL TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());

CREATE POLICY "Public read active categories" ON public.award_categories FOR SELECT TO anon,authenticated
USING(is_active=TRUE OR public.is_admin());
CREATE POLICY "Admins manage categories" ON public.award_categories FOR ALL TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());

CREATE POLICY "Public read active nominees" ON public.award_nominees FOR SELECT TO anon,authenticated
USING(
  (is_active=TRUE AND EXISTS(
    SELECT 1 FROM public.award_categories c
    WHERE c.id=category_id AND c.is_active=TRUE
  )) OR public.is_admin()
);
CREATE POLICY "Admins manage nominees" ON public.award_nominees FOR ALL TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());

CREATE POLICY "Public submit valid votes" ON public.votes FOR INSERT TO anon,authenticated
WITH CHECK(EXISTS(
  SELECT 1 FROM public.event_settings e
  JOIN public.award_categories c ON c.id=category_id
  JOIN public.award_nominees n ON n.id=nominee_id AND n.category_id=c.id
  WHERE e.id=1 AND e.voting_open=TRUE AND c.is_active=TRUE
    AND c.voting_open=TRUE AND n.is_active=TRUE
));
CREATE POLICY "Admins view votes" ON public.votes FOR SELECT TO authenticated
USING(public.is_admin());
CREATE POLICY "Admins delete votes" ON public.votes FOR DELETE TO authenticated
USING(public.is_admin());

CREATE POLICY "Public submit RSVP before deadline" ON public.rsvps FOR INSERT TO anon,authenticated
WITH CHECK(EXISTS(
  SELECT 1 FROM public.event_settings
  WHERE id=1 AND rsvp_open=TRUE
    AND (rsvp_closes_at IS NULL OR NOW()<rsvp_closes_at)
));
CREATE POLICY "Admins view RSVPs" ON public.rsvps FOR SELECT TO authenticated
USING(public.is_admin());
CREATE POLICY "Admins update RSVPs" ON public.rsvps FOR UPDATE TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());
CREATE POLICY "Admins delete RSVPs" ON public.rsvps FOR DELETE TO authenticated
USING(public.is_admin());

CREATE POLICY "Public read active programme" ON public.event_programme FOR SELECT TO anon,authenticated
USING(is_active=TRUE OR public.is_admin());
CREATE POLICY "Admins manage programme" ON public.event_programme FOR ALL TO authenticated
USING(public.is_admin()) WITH CHECK(public.is_admin());

CREATE INDEX staff_department_idx ON public.staff(department_id);
CREATE INDEX nominees_category_idx ON public.award_nominees(category_id);
CREATE INDEX votes_category_idx ON public.votes(category_id);
CREATE INDEX votes_nominee_idx ON public.votes(nominee_id);
CREATE INDEX rsvps_created_idx ON public.rsvps(created_at DESC);
CREATE INDEX programme_order_idx ON public.event_programme(sort_order);

-- Public-facing results are aggregated and only exposed after admin publication.
CREATE OR REPLACE VIEW public.published_award_results
WITH(security_invoker=false) AS
SELECT c.id AS category_id,c.title AS category,n.id AS nominee_id,
       s.full_name AS nominee_name,s.designation AS nominee_role,
       d.name AS department,COUNT(v.id)::BIGINT AS total_votes
FROM public.award_categories c
JOIN public.award_nominees n ON n.category_id=c.id
JOIN public.staff s ON s.id=n.staff_id
LEFT JOIN public.departments d ON d.id=s.department_id
LEFT JOIN public.votes v ON v.nominee_id=n.id
CROSS JOIN public.event_settings e
WHERE e.id=1 AND e.results_published=TRUE
  AND c.is_active=TRUE AND n.is_active=TRUE
GROUP BY c.id,c.title,n.id,s.full_name,s.designation,d.name;

GRANT USAGE ON SCHEMA public TO anon,authenticated;
GRANT SELECT ON public.event_settings,public.departments,public.staff,
 public.award_categories,public.award_nominees,public.event_programme
 TO anon,authenticated;
GRANT INSERT ON public.rsvps,public.votes TO anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.profiles,public.event_settings,
 public.departments,public.staff,public.award_categories,public.award_nominees,
 public.votes,public.rsvps,public.event_programme TO authenticated;
GRANT SELECT ON public.published_award_results TO anon,authenticated;

-- Storage buckets
INSERT INTO storage.buckets(id,name,public) VALUES
 ('staff-gallery','staff-gallery',TRUE),
 ('event-assets','event-assets',TRUE)
ON CONFLICT(id) DO UPDATE SET public=EXCLUDED.public;

CREATE POLICY "Public view gala images" ON storage.objects FOR SELECT TO anon,authenticated
USING(bucket_id IN('staff-gallery','event-assets'));
CREATE POLICY "Admins upload gala images" ON storage.objects FOR INSERT TO authenticated
WITH CHECK(bucket_id IN('staff-gallery','event-assets') AND public.is_admin());
CREATE POLICY "Admins update gala images" ON storage.objects FOR UPDATE TO authenticated
USING(bucket_id IN('staff-gallery','event-assets') AND public.is_admin())
WITH CHECK(bucket_id IN('staff-gallery','event-assets') AND public.is_admin());
CREATE POLICY "Admins delete gala images" ON storage.objects FOR DELETE TO authenticated
USING(bucket_id IN('staff-gallery','event-assets') AND public.is_admin());

-- ============================================================
-- AFTER RUNNING THIS SCRIPT:
-- 1. Create an admin user in Authentication > Users.
-- 2. Copy that user's UUID.
-- 3. Run the profile INSERT below with the real UUID:
--
-- INSERT INTO public.profiles(id,full_name,role)
-- VALUES('YOUR-AUTH-USER-UUID','Gala Administrator','super_admin');
--
-- Do not expose a service_role key in the browser.
-- ============================================================
