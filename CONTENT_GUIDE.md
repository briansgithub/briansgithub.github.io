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
  quotes/         Individual favorite quotations
  pages/          About copy plus Home and Résumé writing worksheets
```

The live site-wide identity fields are in `src/data/site.ts`, and the structured résumé displayed by the site is in `src/data/resume.ts`. The Home and Résumé Markdown files are safe worksheets for developing that copy; `pages/about.md` is rendered directly.

Use lowercase kebab-case filenames, such as `measuring-oscillator-drift.md`. The filename becomes the stable content ID and usually the URL slug. Do not rename a published file without also arranging a redirect.

## 3. Frontmatter schemas

Only use the fields listed for each collection. Optional fields can be omitted.

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
featured: optional boolean
cover: optional object containing image and alt text
links: optional record of label to URL
order: optional number
draft: optional boolean
placeholder: optional boolean
```

Use a project cover only when an existing image adds useful context in project listings. Keep the
image and its alternative text together in the nested `cover` field:

```yaml
cover:
  image: ../../assets/images/project-name/cover.webp
  alt: 'Describe the project image and the useful visual context it provides.'
```

The image path is relative to the project Markdown file. Astro validates and optimizes local cover
images at build time. Projects without a cover continue to use the standard text-card layout.

Example links when real URLs exist:

```yaml
links:
  Source: 'https://github.com/owner/repository'
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
order: optional number
draft: optional boolean
placeholder: optional boolean
```

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

1. In Obsidian, create a note in `_drafts`.
2. Insert the matching template: Writing, Project, Book, Quote, or Page.
3. Rename the file with a concise kebab-case slug.
4. Write in standard Markdown. Avoid Obsidian-only embeds, block references, and callouts.
5. Use descriptive link text and fenced code blocks with a language label.
6. Save images only after web preparation; see the media rules below.

For a quick correction to an already published entry, edit the public file directly. Add `updatedAt` to writing only when the revision materially changes the article.

## 6. Publish

There is no content database and no required CMS action.

1. Finish the private draft and complete its metadata.
2. Move it from `_drafts` into the matching collection.
3. Remove all placeholder material.
4. Confirm `draft: false` and `placeholder: false`.
5. Preview the page locally.
6. Review changed files in VS Code Source Control.
7. Commit and sync only after the rendered page and diff are correct.

A file committed with `draft: true` is not private: its source remains readable in a public GitHub repository even if Astro omits it from the website.

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

Do not commit camera RAW files, PSDs, TIFFs, large GIFs, audio, or video. Use the **Media: import image** VS Code task to make a web-safe copy before an image enters Git history; it preserves the original outside the repository.

## 8. Privacy and backup

The root `.gitignore` excludes everything inside `src/content/_drafts/` except its README. A test draft should therefore remain absent from VS Code Source Control. This prevents accidental Git publication, but the folder is not encrypted.

Git-ignored drafts are not backed up by GitHub, so back them up separately with Windows File History, an encrypted cloud backup, or a sibling private repository.

Also keep these out of public content:

- private addresses and phone numbers;
- credentials, API keys, and `.env` values;
- private notes hidden in HTML comments;
- local absolute file paths; and
- unstripped photograph metadata.

## 9. Launch-content placeholders

The initial content set covers every decision needed before launch:

- **Name:** `pages/home.md` contains the writing placeholder; transfer the approved version to `src/data/site.ts`.
- **Tagline:** `pages/home.md` contains the writing placeholder; transfer the approved version to `src/data/site.ts`.
- **Short bio:** `pages/home.md` contains the worksheet; `src/data/site.ts` drives the live home page.
- **Long bio:** `pages/about.md` contains the longer biography structure.
- **Contact:** Home, About, and Résumé include a public-email placeholder.
- **Social links:** The supplied GitHub profile is real; all other social profiles remain labeled placeholders.
- **Résumé:** `pages/resume.md` is the writing worksheet; `src/data/resume.ts` drives the structured live page without inventing employment, institutions, dates, or skills.
- **Projects:** `projects/project-one.md` and `project-two.md` exercise featured, active, and complete project layouts without claiming real work.
- **Portrait:** `pages/home.md` specifies the desired crop, format, size, metadata treatment, and alt-text requirement. No fake portrait is included.
- **First writing:** `writing/first-writing.md` provides a readable article structure without presenting sample prose as the author's work.
- **Quotes:** Two ordered quote entries are ready for genuine selections.
- **Book note:** `books/first-book-note.md` provides the note structure without claiming the book was read.
- **Domain:** `bellsworth.dev` is the configured canonical domain. Keep `site.preview` enabled until the launch checklist is complete.

Replace these items deliberately rather than deleting all placeholder content at once; they collectively exercise the site's major content layouts.
