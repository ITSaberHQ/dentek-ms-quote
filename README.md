# dentek_ms_quote

Dentek quote builder built with Flutter for Windows, Android, and Web.

[![Deploy Flutter Web to GitHub Pages](https://github.com/ITSaberHQ/dentek-ms-quote/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/ITSaberHQ/dentek-ms-quote/actions/workflows/deploy-pages.yml)

## GitHub Pages Deployment

This repo includes an automated Pages workflow at `.github/workflows/deploy-pages.yml`.

Deployment behavior:

- Every push to `main` builds Flutter web with `--base-href /dentek-ms-quote/`.
- The built site artifact from `build/web` is deployed to GitHub Pages.

Expected Pages URL:

- `https://itsaberhq.github.io/dentek-ms-quote/`

If this is the first deployment for the repository, ensure Pages is enabled in repository settings and set to use GitHub Actions.
