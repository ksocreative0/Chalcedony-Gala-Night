// Add your Supabase project credentials here.
// Project Settings → API → Project URL and anon/public key.
// NEVER put your service_role key in browser code.
window.GALA_SUPABASE_URL = "https://magspyjlbvaffzzflddu.supabase.co";
window.GALA_SUPABASE_ANON_KEY = "sb_publishable_OigIDM_9j9IVPkwHXscw3Q_A-H0lUV-";
window.galaSupabase = (window.supabase && window.GALA_SUPABASE_URL.startsWith("https://") && window.GALA_SUPABASE_ANON_KEY !== "YOUR_SUPABASE_ANON_KEY")
  ? window.supabase.createClient(window.GALA_SUPABASE_URL, window.GALA_SUPABASE_ANON_KEY)
  : null;
