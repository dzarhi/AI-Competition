# Supabase voting backend

This backend lets the existing GitHub Pages voting UI save votes without exposing a service-role key.

## Setup

1. Create a Supabase project.
2. In the Supabase SQL Editor, run `schema.sql`. It creates the presenter roster, the votes table, duplicate-vote protection, and row-level security with no direct public table access.
3. Install the Supabase CLI, run `supabase login`, then from this folder run `supabase link --project-ref <project-ref>`.
4. Set server-side secrets. Use a newly generated judge code of at least 16 characters, and never put it in `supabase-config.js`:

   ```powershell
   supabase secrets set JUDGE_CODE="<private judge code>" ALLOWED_ORIGINS="https://dzarhi.github.io,http://localhost:8000"
   ```

5. Deploy the Edge Function:

   ```powershell
   supabase functions deploy voting-api --no-verify-jwt
   ```

6. In `supabase-config.js`, replace `YOUR_PROJECT_REF` with the Supabase project URL and `YOUR_SUPABASE_ANON_KEY` with the project's public anon key. The anon key is intended for browser use; never use the `service_role` key in this file.
7. Commit and push `supabase-config.js` and `voting.html` to GitHub Pages. Confirm the GitHub Pages deployment succeeds before testing votes.

## Behavior and limits

- Names are currently seeded in `schema.sql`; update that seed if the presenter roster changes.
- Each typed voter name can submit one vote per presenter per role. Names are not authenticated identities, so a public site cannot prevent someone from entering another person's name.
- The judge code is checked by the Edge Function and stored only as a Supabase secret. It is not embedded in the public JavaScript.
- The `results` action returns aggregate audience and judge averages, with a final score of 40% audience and 60% judges once both groups have votes.
- Votes are stored in Supabase. Writing them automatically into the separate SharePoint `Results.xlsx` file needs an additional Power Automate flow or Microsoft Graph integration.
