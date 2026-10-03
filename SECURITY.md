# Security

Ember starts with fictional demo data and optional backend setup code. No shared Supabase project or production credentials are configured. The GitHub Pages demo runs from the checked `main` branch.

## Supported version

Security fixes are applied to the latest `main` branch. Older commits and privately deployed copies are not maintained separately.

## Repository safeguards

- GitHub secret scanning and push protection detect supported credential patterns.
- A pinned Gitleaks action scans Git history on pushes and pull requests. Findings are not posted as public comments or uploaded as report artifacts.
- Dependencies and action updates are proposed through Dependabot and checked before merging.
- Workflows use read-only permissions for scanning, tests, and builds. Only the Pages deployment job receives Pages and identity-token write permissions; it runs for `main` after checks pass.
- Secrets, local databases, exports, signing files, and deployment metadata are excluded from version control.
- `CODEOWNERS` identifies the maintainer. Private vulnerability reporting provides a confidential channel.

These controls reduce risk; they do not prove the absence of vulnerabilities. Public source can still be copied. The copyright notice records ownership and usage terms; it is not a technical copying barrier.

## Demo privacy

The demo uses browser storage on your device. It has no configured cloud account and performs no ledger sync until you connect your own backend. GitHub hosts the static demo; browser storage is not encrypted secret storage. Use fictional records in the public demo. Clearing browser site data removes local demo edits.

## Using your own backend

- Use a separate project for demos and experiments. Do not place real financial records in a publicly shared demo.
- Never commit database passwords, Supabase secret/service-role keys, signing keys, session tokens, or data exports. The repository ignores common local credential files.
- Supabase publishable keys are visible in client builds by design. Protect data with least-privilege grants and ownership policies on every exposed table.
- Run the Supabase Security Advisor, review function execution grants, and verify both allowed and denied access for signed-out users and different authenticated users.
- Restrict Auth redirect URLs to your own app addresses. Review password requirements, Auth rate limits, and bot protection before exposing sign-in publicly.
- Browser/native sessions are persisted through SharedPreferences. Protect shared devices, sign out after use, and review storage/session controls before a production rollout.
- The included SQL setup is for a new project; it is not permission to modify another project's production database.

## Reporting an issue

Use **[Security → Report a vulnerability](https://github.com/Arad-d/ember/security/advisories/new)**. Include affected files or behavior, reproduction steps using fictional data, impact, and the commit or version. Never include active credentials or other people's records. There is no guaranteed response time; please allow the maintainer to investigate before disclosure.

## Third-party assets

The bundled Roboto font retains its license at `assets/fonts/LICENSE.txt`. Flutter and dependencies retain their respective upstream licenses. Review asset and dependency licenses before redistributing an application.
