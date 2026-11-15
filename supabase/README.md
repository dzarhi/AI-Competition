# Supabase voting backend

The existing GitHub Pages voting UI stores votes in Supabase through SQL RPCs. The browser uses only the project's public publishable key; never put a `service_role` or secret key in `supabase-config.js`.

## Setup

1. Create a Supabase project.
2. In the Supabase SQL Editor, run `schema.sql`, then `rpc.sql`. The schema seeds the presenter roster, creates the votes table and duplicate-vote constraint, and enables row-level security. The RPC script exposes only the intended operations to the browser.
3. Generate a private judge code of at least 16 characters. In the SQL Editor, replace the placeholder and run:

   ```sql
   insert into public.judge_access (singleton, code)
   values (true, 'REPLACE_WITH_A_PRIVATE_JUDGE_CODE')
   on conflict (singleton) do update set code = excluded.code;
   ```

   Share the code with judges privately. Do not put it in the website or commit it to the repository.
4. Set `url` and `publishableKey` in the local `supabase-config.js` from the Supabase project's API settings. This file is intended to be published with the site.
5. In Supabase Dashboard, add an `ADMIN_RESET_PASSWORD` Edge Function secret with a randomly generated password of at least 32 characters. Keep it private; do not put it in `supabase-config.js` or commit it.
6. Deploy the reset function with JWT verification disabled (it authenticates the reset request using the private password):

   ```sh
   supabase functions deploy reset-votes --project-ref ialphxylbjouynilanqu --no-verify-jwt
   ```

7. Publish `voting.html` and `supabase-config.js` to the GitHub Pages branch, then test the deployed page.

The results panel includes an **איפוס כל ההצבעות** button. It prompts for the administrator password and clears only the `votes` table. The password is checked by the Edge Function and is never stored in the website or returned in responses. Use a unique, high-entropy password and keep it in a password manager.

## Behavior and limits

- The public page loads presenters, checks a voter's existing votes, saves one vote per presenter and role, and shows public results through `list_presenters`, `get_my_votes`, `submit_vote`, and `get_results`.
- The weighted score is 40% audience average and 60% judge average. It remains blank until both groups have votes for a presenter.
- Voter names are typed, not authenticated identities. The unique constraint prevents duplicate votes for the same typed name, role, and presenter, but cannot prevent name impersonation.
- The judge code gates access to the judge role; it does not authenticate a judge's personal identity.
- The reset password is a separate Edge Function secret. The reset endpoint requires a password of at least 32 characters and uses the server-only service role key; never expose that key to the browser.
- Votes are stored in Supabase. Writing them automatically into the separate SharePoint `Results.xlsx` file needs an additional Power Automate flow or Microsoft Graph integration.
