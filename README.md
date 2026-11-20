# Chalcedony-Gala-Night
Award ceremony/ event


## Feature update: multiple sponsorships and vote controls

For an existing Supabase Gala project, run `feature_update.sql` in the Supabase SQL Editor **before** deploying the updated website files. This migration:
- Adds the `rsvp_sponsorships` table and an atomic `submit_gala_rsvp` function for multiple category commitments in one RSVP.
- Adds the `votes.is_hidden` flag and admin-only update permission for hide/unhide.
- Updates the public results view so hidden votes are excluded from totals.
- Keeps vote deletion restricted to authenticated admins.

After the SQL succeeds, deploy the updated `index.html`, `admin.html`, `main.js`, `admin.js`, and `style.css` together. Ending voting only sets `event_settings.voting_open` to false; it does not publish results. Publishing remains a separate admin action.
