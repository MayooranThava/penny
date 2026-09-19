# Legal pages (App Store URLs)

Same pattern as Void Runner (`ApolloX_IOS`). Host these HTML files over HTTPS and paste the URLs into App Store Connect.

## Enable GitHub Pages (required once)

The Actions token **cannot** create a Pages site. That is why the first run failed on `configure-pages` with `Resource not accessible by integration`.

Do this in a browser (on phone: request **Desktop site**):

1. **Visibility:** Penny is currently **private**. GitHub Pages on a free plan only works for **public** repos (or any visibility with GitHub Pro).  
   → **Settings → General → Danger Zone → Change visibility → Public**  
   *(or upgrade to Pro and leave it private)*
2. **Pages source:** **Settings → Pages → Build and deployment → Source: GitHub Actions**
3. Re-run **Actions → GitHub Pages → Run workflow** on `main`

After it goes green, use:

| App Store Connect field | URL |
|---|---|
| Privacy Policy | `https://mayooranthava.github.io/penny/privacy-policy.html` |
| Support URL | `https://mayooranthava.github.io/penny/support.html` |
| Marketing URL (optional) | `https://mayooranthava.github.io/penny/` |

Those match `PennyAppInfo.privacyPolicyURL` / `supportURL` in the app.

## Files

- `docs/index.html`, `docs/privacy-policy.html`, `docs/support.html`, `docs/.nojekyll`
- Workflow: `.github/workflows/pages.yml` (publishes only those HTML files)
