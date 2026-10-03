# Security

This repository is a standalone portfolio snapshot. It includes fictional demo data and optional backend setup code. It has no default Supabase project, hosted domain, production credentials, or original deployment configuration.

## Using your own backend

- Use a separate project for demos and experiments. Do not place real financial records in a publicly shared demo.
- Never commit database passwords, Supabase secret/service-role keys, signing keys, session tokens, or data exports. The repository ignores common local credential files.
- Supabase publishable keys are visible in client builds by design. Protect data with least-privilege grants and ownership policies on every exposed table.
- Run the Supabase Security Advisor, review function execution grants, and verify both allowed and denied access for signed-out users and different authenticated users.
- Restrict Auth redirect URLs to your own app addresses. Review password requirements, Auth rate limits, and bot protection before exposing sign-in publicly.
- Browser/native sessions are persisted through SharedPreferences. Protect shared devices, sign out after use, and review storage/session controls before a production rollout.
- The included SQL setup is for a new project; it is not permission to modify another project's production database.

## Reporting an issue

Use the repository's **Security → Report a vulnerability** option when enabled. If private reporting is unavailable, open an issue requesting a private contact channel without publishing exploit details, credentials, personal records, or tokens.

## Third-party assets

The bundled Roboto font retains its license at `assets/fonts/LICENSE.txt`. Flutter and dependencies retain their respective upstream licenses. Review asset and dependency licenses before redistributing an application.
