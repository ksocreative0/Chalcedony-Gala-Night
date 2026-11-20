-- Chalcedony Gala feature update (safe to run on the existing project)
-- 1) Multiple category sponsorships per RSVP
CREATE TABLE IF NOT EXISTS public.rsvp_sponsorships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rsvp_id UUID NOT NULL REFERENCES public.rsvps(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.award_categories(id) ON DELETE RESTRICT,
  sponsored_item TEXT NOT NULL CHECK (NULLIF(TRIM(sponsored_item),'') IS NOT NULL),
  delivery_date DATE NOT NULL CHECK (delivery_date <= DATE '2026-12-18'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(rsvp_id, category_id)
);
ALTER TABLE public.rsvp_sponsorships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins manage RSVP sponsorships" ON public.rsvp_sponsorships;
CREATE POLICY "Admins manage RSVP sponsorships" ON public.rsvp_sponsorships
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rsvp_sponsorships TO authenticated;

-- Preserve existing single-category sponsorships in the new child table.
INSERT INTO public.rsvp_sponsorships(rsvp_id,category_id,sponsored_item,delivery_date)
SELECT id,sponsored_category_id,sponsored_item,sponsorship_delivery_date
FROM public.rsvps
WHERE is_sponsoring=TRUE AND sponsored_category_id IS NOT NULL
  AND NULLIF(TRIM(sponsored_item),'') IS NOT NULL
  AND sponsorship_delivery_date IS NOT NULL
ON CONFLICT (rsvp_id,category_id) DO NOTHING;

-- Atomic public RSVP + multiple sponsorship submission.
CREATE OR REPLACE FUNCTION public.submit_gala_rsvp(p_rsvp JSONB, p_sponsorships JSONB DEFAULT '[]'::jsonb)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  new_rsvp_id UUID := gen_random_uuid();
  first_sponsor JSONB;
  sponsor_count INTEGER := 0;
  distinct_count INTEGER := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.event_settings e
    WHERE e.id=1 AND e.rsvp_open=TRUE
      AND (e.rsvp_closes_at IS NULL OR NOW()<e.rsvp_closes_at)
  ) THEN
    RAISE EXCEPTION 'RSVP registration is closed';
  END IF;

  IF COALESCE(p_rsvp->>'full_name','')='' OR COALESCE(p_rsvp->>'email','')='' THEN
    RAISE EXCEPTION 'Full name and email are required';
  END IF;
  IF COALESCE(p_rsvp->>'attendance_decision','') NOT IN ('attending','not_attending','undecided') THEN
    RAISE EXCEPTION 'Invalid attendance decision';
  END IF;

  sponsor_count := jsonb_array_length(COALESCE(p_sponsorships,'[]'::jsonb));
  SELECT COUNT(DISTINCT x->>'category_id') INTO distinct_count
  FROM jsonb_array_elements(COALESCE(p_sponsorships,'[]'::jsonb)) AS t(x);
  IF sponsor_count <> distinct_count THEN
    RAISE EXCEPTION 'Choose each award category only once';
  END IF;
  IF sponsor_count > 0 THEN
    SELECT x INTO first_sponsor
    FROM jsonb_array_elements(p_sponsorships) AS t(x) LIMIT 1;
    IF EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_sponsorships) AS t(x)
      WHERE COALESCE(x->>'category_id','')='' OR
            COALESCE(NULLIF(TRIM(x->>'sponsored_item'),''),'')='' OR
            COALESCE(x->>'delivery_date','')=''
    ) THEN
      RAISE EXCEPTION 'Complete every sponsorship category, item and delivery date';
    END IF;
    IF EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_sponsorships) AS t(x)
      LEFT JOIN public.award_categories c ON c.id=(x->>'category_id')::uuid
      WHERE c.id IS NULL OR c.is_active IS NOT TRUE
         OR (x->>'delivery_date')::date > DATE '2026-12-18'
    ) THEN
      RAISE EXCEPTION 'One or more sponsorship categories or dates are invalid';
    END IF;
  END IF;

  INSERT INTO public.rsvps(
    id,full_name,email,attendance_decision,is_sponsoring,
    sponsored_category_id,sponsored_item,sponsorship_delivery_date
  ) VALUES (
    new_rsvp_id,
    TRIM(p_rsvp->>'full_name'),
    LOWER(TRIM(p_rsvp->>'email')),
    p_rsvp->>'attendance_decision',
    sponsor_count > 0,
    CASE WHEN sponsor_count > 0 THEN (first_sponsor->>'category_id')::uuid ELSE NULL END,
    CASE WHEN sponsor_count > 0 THEN first_sponsor->>'sponsored_item' ELSE NULL END,
    CASE WHEN sponsor_count > 0 THEN (first_sponsor->>'delivery_date')::date ELSE NULL END
  );

  IF sponsor_count > 0 THEN
    INSERT INTO public.rsvp_sponsorships(rsvp_id,category_id,sponsored_item,delivery_date)
    SELECT new_rsvp_id,(x->>'category_id')::uuid,x->>'sponsored_item',(x->>'delivery_date')::date
    FROM jsonb_array_elements(p_sponsorships) AS t(x);
  END IF;
  RETURN new_rsvp_id;
END;
$$;
REVOKE ALL ON FUNCTION public.submit_gala_rsvp(JSONB,JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_gala_rsvp(JSONB,JSONB) TO anon, authenticated;

-- 2) Vote hide/unhide. Hidden votes are retained but not counted.
ALTER TABLE public.votes ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT FALSE;
DROP POLICY IF EXISTS "Admins update votes" ON public.votes;
CREATE POLICY "Admins update votes" ON public.votes
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
GRANT UPDATE ON public.votes TO authenticated;

-- 3) Public results omit hidden votes; publishing remains a separate action.
CREATE OR REPLACE VIEW public.published_award_results
WITH (security_invoker=false) AS
SELECT c.id AS category_id,c.title AS category,n.id AS nominee_id,
       s.full_name AS nominee_name,s.designation AS nominee_role,
       d.name AS department,COUNT(v.id)::BIGINT AS total_votes
FROM public.award_categories c
JOIN public.award_nominees n ON n.category_id=c.id
JOIN public.staff s ON s.id=n.staff_id
LEFT JOIN public.departments d ON d.id=s.department_id
LEFT JOIN public.votes v ON v.nominee_id=n.id AND v.is_hidden=FALSE
CROSS JOIN public.event_settings e
WHERE e.id=1 AND e.results_published=TRUE
  AND c.is_active=TRUE AND n.is_active=TRUE
GROUP BY c.id,c.title,n.id,s.full_name,s.designation,d.name;

NOTIFY pgrst, 'reload schema';
