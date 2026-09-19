# Legal pages (App Store URLs)

Same pattern as Void Runner (`ApolloX_IOS`). Host these HTML files over HTTPS and paste the URLs into App Store Connect.

## Recommended: GitHub Pages

The Pages workflow deploys only the public legal HTML from `docs/` (internal markdown stays out of the site).

1. Repo **Settings → Pages** → **Build and deployment → Source: GitHub Actions**
2. Run **Actions → GitHub Pages → Run workflow** on `main`
3. After it publishes, use:

| App Store Connect field | URL |
|---|---|
| Privacy Policy | `https://mayooranthava.github.io/penny/privacy-policy.html` |
| Support URL | `https://mayooranthava.github.io/penny/support.html` |
| Marketing URL (optional) | `https://mayooranthava.github.io/penny/` |

Those match `PennyAppInfo.privacyPolicyURL` / `supportURL` in the app.

> **Private repo note:** GitHub Pages for private repositories requires GitHub Pro/Team (Void Runner works because `ApolloX_IOS` is public). If Pages won’t enable, either upgrade, make the repo public, or host these three HTML files elsewhere and update the URLs above + `PennyAppInfo`.
