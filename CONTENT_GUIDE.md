# Content guide

This repository uses Astro content collections for public content and treats `src/content` as an Obsidian vault. The workflow is deliberately file-first: content remains readable Markdown with small, predictable YAML frontmatter blocks.

## 1. Vault setup

Open `src/content` as the Obsidian vault, not the repository root.

The committed vault settings already configure:

- relative links;
- standard Markdown links instead of `[[Wikilinks]]`;
- automatic link updates after renames;
- `_drafts` as the default new-note folder;
- an `images` subfolder for attachments; and
- `_templates` as the template directory.

Enable Obsidian's built-in **Templates** plugin once after opening the vault. No community plugin is required.

## 2. Directory map

```text
src/content/
  .obsidian/      Minimal portable vault settings
  _drafts/        Private working area once Git ignores it
  _templates/     Obsidian templates; not an Astro collection
  writing/        Essays, blog posts, tutorials, and project notes
  projects/       Stable project and case-study pages
  books/          Book notes
  prints/         3D print entries, optionally with a viewable STL model
  quotes/         Individual favorite quotations
  pages/          About copy plus Home and Résumé writing worksheets
```

The live site-wide identity fields are in `src/data/site.ts`, and the structured résumé displayed by the site is in `src/data/resume.ts`. The Home and Résumé Markdown files are safe worksheets for developing that copy; `pages/about.md` is rendered directly as the `/` homepage, with `/about/` redirecting there.

Use lowercase kebab-case filenames, such as `measuring-oscillator-drift.md`. The filename becomes the stable content ID and usually the URL slug. Do not rename a published file without also arranging a redirect.

## 3. Frontmatter schemas

[`src/content.config.ts`](src/content.config.ts) is the authoritative definition of
every schema. This section describes it; where the two disagree, the code wins and
this section needs fixing.

Only use the fields listed for each collection. Unlisted fields are rejected rather
than ignored — add the field to the schema first. Optional fields can be omitted.

Three rules apply to every collection and cause most validation failures:

- **`draft` defaults to `true`.** Omitting the field hides the entry instead of
  publishing it. Publication always requires an explicit `draft: false`.
- **Tags must be lowercase kebab-case**, matching `^[a-z0-9]+(?:-[a-z0-9]+)*$`.
  Capitals, spaces, and underscores fail the build.
- **String fields are length-capped.** Titles allow 120 characters; descriptions,
  summaries, and alt text allow 240; `material` allows 60. Copy that reads well on
  the page can still fail validation, so check length before committing.

### Writing

```yaml
title: string
description: string
publishedAt: date
updatedAt: optional date
tags: string[]
featured: optional boolean
draft: optional boolean
placeholder: optional boolean
```

### Projects

```yaml
title: string
summary: string
status: active | complete | archived
year: number
technologies: string[]
tags: string[]
featured: optional boolean
cover: optional object containing image and alt text
gallery: optional array of image and alt objects, at most 16
links: optional record of label to URL
order: optional number
draft: optional boolean
placeholder: optional boolean
```

The projects index is a year timeline of equal text cards. A `cover` image is the
representative (higher-priority) photo on the opposite side of the spine. Extra shots go in
`gallery` and share that same bordered box, sized to about two-thirds of the facing card,
which scrolls horizontally when the set is wider than the box. Omit both to keep the opposite side empty. Project pages do not repeat the
frontmatter gallery; keep photos in the writeup where they belong.

```yaml
cover:
  image: ../../assets/images/project-name/cover.webp
  alt: 'Describe the project image and the useful visual context it provides.'
gallery:
  - image: ../../assets/images/project-name/detail.webp
    alt: 'Describe the extra shot.'
```

Image paths are relative to the project Markdown file. Astro validates and optimizes them at
build time. Projects without images continue to use the standard text-card layout.

A `links` URL on github.com is labeled GitHub and shown first. All project
`links` render as prominent buttons in the project-page header. The timeline
does not repeat them. Omit GitHub when no public repository exists.

Example links when real URLs exist:

```yaml
links:
  GitHub: 'https://github.com/owner/repository'
  Demo: 'https://example.com'
```

### Books

```yaml
title: string
author: string
summary: string
rating: optional integer from 1 through 5
finishedAt: optional date
tags: string[]
draft: optional boolean
placeholder: optional boolean
```

### Quotes

```yaml
quote: string
author: string
source: optional string
url: optional URL
category: optional string
order: optional number
draft: optional boolean
placeholder: optional boolean
```

`category` drives the quotation category navigation. Reuse an existing category
string exactly rather than introducing a near-duplicate spelling.

### Prints

```yaml
title: string
summary: string
material: string
printedAt: optional date
tags: string[]
featured: optional boolean
order: optional number
model: optional object containing file and sizeBytes
links: optional record of label to URL
draft: optional boolean
placeholder: optional boolean
```

A print entry may attach an STL model, which the site renders in an interactive
3D viewer:

```yaml
model:
  file: /files/prints/sample-icosahedron.stl
  sizeBytes: 68284
```

The `file` path is site-absolute and resolves inside `public/`, unlike project
cover images, which are repository-relative and processed by Astro. `sizeBytes`
must match the real file size; it is displayed before download so a visitor on a
metered connection can decide.

Keep STL files at or below 5 MiB. The viewer is a three.js bundle held to a
documented 768 KB budget exception on the strict condition that it stays
code-split and loads only on print pages — do not import it into a shared layout
or any other route.

### Pages

```yaml
title: string
description: string
draft: optional boolean
placeholder: optional boolean
```

Use ISO dates (`YYYY-MM-DD`). Quote YAML strings that contain punctuation such as colons. Begin the Markdown body at `##`; the page layout supplies the single `h1` from the title.

## 4. Placeholder policy

Scaffold content is intentionally marked with both visible `[PLACEHOLDER]` text and `placeholder: true` frontmatter. This prevents a polished layout from turning sample prose into an accidental personal claim.

Before publishing real content:

1. Search the file for `[PLACEHOLDER]` and replace every occurrence.
2. Remove the `placeholder` tag if present.
3. Set `placeholder: false` or remove the field.
4. Set `draft: false`.
5. Preview the rendered page and review the Git diff.

Placeholder entries remain visible only while `site.preview` is enabled. Public builds exclude them from lists, detail routes, tags, RSS, and the sitemap until replaced.

## 5. Create and write

### Authoring tools (recommended)

Write and publish from the sibling `personal-website-authoring-tools` checkout, not from a second
PowerShell batch in this repository.

1. Double-click `Write Website Content.cmd` in `personal-website-authoring-tools`.
2. Create or open content in Authoring Home. Creating a draft, adding files, opening Site essentials,
   or choosing **Include in next publish** records those paths in the tools `.runtime/` publish set.
3. Write in Obsidian. Reload Authoring Home after saving to refresh readiness.
4. Double-click `Review and Publish Website.cmd`. Select ready drafts, review the session files, type
   `INCLUDE` only if leftover Git-visible files should join this run, then type `PUBLISH`.
5. Wait until the publisher reports that GitHub Pages deployed. A successful push is not a successful
   deployment.

From this website checkout, the same workflow is:

```powershell
npm run content:workflow
```

`Start Website Content Workflow.cmd` and `Publish Website Changes.cmd` are shims into that tools
workflow. Dry-run a publication with `npm run publish:content -- --dry-run` from the tools directory.
Diagnostics are `npm run author:status` and `npm run content:status` there.

### Manual workflow

1. In Obsidian, create a note in `_drafts`.
2. Insert the matching template: Writing, Project, Book, Print, Quote, or Page.
3. Rename the file with a concise kebab-case slug.
4. Write in standard Markdown. Avoid Obsidian-only embeds, block references, and callouts.
5. Use descriptive link text and fenced code blocks with a language label.
6. Save images only after web preparation; see the media rules below.

For a quick correction to an already published entry, edit the public file directly. Add `updatedAt` to writing only when the revision materially changes the article.

## 6. Publish

There is no content database and no required CMS action. Prefer Review and Publish from
`personal-website-authoring-tools` so Markdown lint, Prettier, and `astro check` run before GitHub
sees the commit.

If you ever commit by hand:

1. Finish the private draft and complete its metadata.
2. Move it from `_drafts` into the matching collection.
3. Remove all placeholder material.
4. Confirm `draft: false` and `placeholder: false`.
5. Preview the page locally.
6. Run `npm run verify`.
7. Commit and sync only after the rendered page, diff, and verification gate are correct.

A file committed with `draft: true` is not private: its source remains readable in a public GitHub
repository even if Astro omits it from the website.

## 7. Images and other media

Obsidian places attachments in an `images` folder beneath the current note's directory. Before adding an image:

- keep the raw camera original outside this repository;
- remove EXIF and GPS metadata;
- resize photographs to no more than 2400 pixels on the long edge;
- prefer WebP for photographs and optimized PNG or SVG for diagrams;
- keep an individual content image below 2 MB, preferably below 500 KB; and
- write useful alt text in standard syntax: `![Description](images/example.webp)`.

To present two related images as an evidence gallery, place their Markdown image lines directly
next to each other with no blank line between them. Leave a blank line before and after the pair:

```md
![Front view](images/device-front.webp)
![Back view](images/device-back.webp)
```

The site displays the pair side by side on wider screens and stacks it on mobile. A single image,
or images separated by a blank line, keeps the normal full-width reading flow.

Do not commit camera RAW files, PSDs, TIFFs, large GIFs, audio, or video. Use the **Media: import image** VS Code task, or `npm run media:import`, to make a web-safe copy before an image enters Git history; it preserves the original outside the repository.

These types are refused outright by `scripts/check-assets.mjs`, not merely discouraged: camera RAW and editing sources, every video and audio format, and every archive or disk image. The full list is in [`config/size-budgets.json`](config/size-budgets.json). Base64 media pasted into a source file is caught by a separate inline `data:` URI check, so encoding a file is not a way around the rule.

**An oversized file is permanent once committed.** The repository enforces a budget on every blob reachable from Git history, alongside the working tree and the generated site. Deleting a large file in a later commit does not reclaim its history cost; only a history rewrite does. Check a binary's size before it enters a commit, not after.

## 8. Privacy and backup

The root `.gitignore` excludes everything inside `src/content/_drafts/` except its README. A test draft should therefore remain absent from VS Code Source Control. This prevents accidental Git publication, but the folder is not encrypted.

Git-ignored drafts are not backed up by GitHub, so back them up separately with Windows File History, an encrypted cloud backup, or a sibling private repository.

Also keep these out of public content:

- private addresses and phone numbers;
- credentials, API keys, and `.env` values;
- private notes hidden in HTML comments;
- local absolute file paths; and
- unstripped photograph metadata.

## 9. Identity data and remaining launch placeholders

Site-wide identity is no longer placeholder material. [`src/data/site.ts`](src/data/site.ts) holds the real name, title, tagline, short and long biography, public email, and the GitHub, LinkedIn, and Instagram profiles. [`src/data/resume.ts`](src/data/resume.ts) holds the real résumé. Treat both as live personal information: correct them from material the site's owner supplies, and never invent employment, institutions, dates, credentials, or skills to fill a gap.

`pages/home.md` and `pages/resume.md` are writing worksheets that render nowhere. Editing them does not change the site — approved copy must be transferred into `src/data/site.ts` or `src/data/resume.ts`. `pages/about.md` is the exception and renders directly as the `/` homepage; `/about/` is retained as a redirect.

To find what still carries scaffold material, search rather than trusting a list in this document:

```powershell
npm run content:list
Select-String -Path src/content -Pattern "\[PLACEHOLDER\]" -Recurse
```

Entries under `_templates/` are supposed to match; they are Obsidian templates, not an Astro collection.

`site.preview` in `src/data/site.ts` is `false`. Placeholder entries are hidden from lists, detail routes, tags, RSS, and the sitemap, and pages are eligible for indexing unless an individual entry is still marked placeholder. Re-enable preview only if scaffold content needs to be reviewed on the live site again.

Replace remaining placeholders deliberately rather than deleting them all at once; they collectively exercise the site's major content layouts, and an emptied collection can hide a broken listing page.

`bellsworth.dev` is the configured canonical domain, set in `astro.config.mjs` and `public/CNAME`.
