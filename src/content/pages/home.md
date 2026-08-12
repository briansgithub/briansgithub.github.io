---
title: 'Home'
description: 'Identity, introduction, contact links, portrait direction, and domain decision for the home page.'
draft: false
placeholder: false
---

## Identity

- **Name:** Brian Ellsworth — transferred to `src/data/site.ts`.
- **Tagline:** Transferred to `src/data/site.ts`.

## Short bio

Transferred to `src/data/site.ts` (`shortBio`).

## Contact and social links

- **GitHub:** [briansgithub](https://github.com/briansgithub) — live in `site.ts` and the site footer.
- **Email:** <bellsworth137@gmail.com> — live in `site.ts`, shown on the About page.
- **Professional profile:** LinkedIn — live in `site.ts` and the site footer.
- **Other social links:** Instagram — live in `site.ts` and the site footer.

## Portrait instruction

Resolved: `brian1.jpg` (a close-up portrait), imported via `npm run media:import` and wired into both the homepage hero and the About page as `src/assets/images/portrait/brian-ellsworth-portrait.webp`.

## Domain decision

Resolved: the site uses the custom domain [`bellsworth.dev`](https://bellsworth.dev). It remains in `site.preview = true` mode in `src/data/site.ts`, which keeps every page `noindex`. Flip `preview` to `false` only once the site is ready to be publicly indexed and all placeholder entries have been replaced or intentionally excluded.
