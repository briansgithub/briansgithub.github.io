# Personal website

A static personal site for writing, projects, book notes, quotations, and a CV. It is built with Astro, authored primarily in Markdown, and deployed to `bellsworth.dev` with GitHub Pages.

The site is currently in **content preview mode**. Placeholder material is visibly labeled and every page includes `noindex` metadata until the identity and launch content are ready.

## Start locally

Node `24.11.1` is recorded in `.node-version`.

```powershell
npm ci
npm run dev -- --background
```

Open `http://localhost:4321`. Use `npm run dev:status`, `npm run dev:logs`, and `npm run dev:stop` to manage the server.

## Write content

Open `src/content` as an Obsidian vault. The committed settings use ordinary Markdown links, keep new notes in the Git-ignored `_drafts` folder, and provide templates for each content type.

The full workflow is in [CONTENT_GUIDE.md](CONTENT_GUIDE.md). Create a draft, write and preview it, check it for publication, then publish it only when complete. The helper scripts never commit or push.

Live identity and CV fields are in `src/data/site.ts` and `src/data/resume.ts`. The Home and CV Markdown files are writing worksheets; `pages/about.md` supplies the rendered About copy.

## Import an image

Keep camera originals outside this repository. Use:

```powershell
npm run media:import -- "C:\path\to\original.jpg" --name lab-bench --alt "Oscilloscope and prototype board on a workbench"
```

The importer preserves the original, strips metadata, limits the long edge to 2400 pixels, exports WebP at quality 82, and refuses output above 2 MiB.

## Verify a change

```powershell
npm run verify
```

This validates schemas, Markdown, formatting, local links, source and history assets, the production build, and generated-site budgets.

## Repository safety

- Raw media, private drafts, dependencies, and generated output are ignored.
- Source images are capped at 2 MiB; the CV PDF at 3 MiB; ordinary files at 5 MiB.
- Source, generated-site, and reachable-history budgets each hard-fail at 250 MiB, well below GitHub Pages' 1 GB limit.
- Git LFS is intentionally not used because GitHub Pages does not support it for published assets.

The repository uses `main` with versioned hooks enabled and is configured for GitHub Pages deployment.
