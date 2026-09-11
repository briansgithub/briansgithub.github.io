# Personal website

A static personal site for writing, projects, book notes, quotations, and a CV. It is built with Astro, authored primarily in Markdown, and deployed to `bellsworth.dev` with GitHub Pages.

`site.preview` is off in `src/data/site.ts`, so placeholder entries stay hidden and pages are eligible for search indexing. See [CONTENT_GUIDE.md](CONTENT_GUIDE.md) for remaining scaffold content that still lives at unused collection URLs.

Working on this repository with an AI agent? Start from [AGENTS.md](AGENTS.md).

## Start locally

Node `24.11.1` is recorded in `.node-version`.

```powershell
npm ci
npm run dev -- --background
```

Open `http://localhost:4321`. Use `npm run dev:status`, `npm run dev:logs`, and `npm run dev:stop` to manage the server.

## Write content

Open `src/content` as an Obsidian vault. The committed settings use ordinary Markdown links, keep new notes in the Git-ignored `_drafts` folder, and provide templates for each content type.

The recommended workflow lives in the sibling `personal-website-authoring-tools` directory:

- Double-click `Write Website Content.cmd` to open Authoring Home.
- Double-click `Review and Publish Website.cmd` to verify, type `PUBLISH`, push, and watch GitHub Pages.

From this website checkout, the same tools are also reachable as shims:

```powershell
npm run content:workflow
```

That command asks whether to write or publish. `Publish Website Changes.cmd` and
`Start Website Content Workflow.cmd` are the File Explorer equivalents. The publisher records a
publish set in the tools `.runtime/` directory, stages only those files, and treats leftover
Git-visible edits as requiring an explicit `INCLUDE`.

Nothing is live during editing, promotion, or local preview. GitHub Pages publishes only after the
push and the deployment checks succeed.

The full creator workflow is in `personal-website-authoring-tools/docs/CONTENT_GUIDE.md`
(local sibling checkout) and this repository's [CONTENT_GUIDE.md](CONTENT_GUIDE.md). The low-level
`content:*` and `media:import` helpers never use Git; only Review and Publish may stage, commit, and
push after its review and confirmation gates.

Live identity and CV fields are in `src/data/site.ts` and `src/data/resume.ts`. The Home and CV Markdown files are writing worksheets; `pages/about.md` supplies the About copy rendered on the homepage.

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

GitHub Pages refuses to publish a site larger than **1 GB**. Three independent budgets in `config/size-budgets.json` keep the project far below that ceiling, each warning at 100 MiB and hard-failing at 250 MiB:

| Budget    | Covers                        | Recoverable?                        |
| --------- | ----------------------------- | ----------------------------------- |
| `source`  | the working tree              | yes — delete the file               |
| `dist`    | the generated site            | yes — rebuild                       |
| `history` | every blob reachable from Git | **no — requires a history rewrite** |

The history budget is the one to respect. A large file committed once counts against it permanently; deleting it in a later commit reclaims nothing. Check a binary's size before committing it.

- Raw media, private drafts, dependencies, and generated output are ignored.
- Source images are capped at 2 MiB, generated images at 1 MiB, the CV PDF at 3 MiB, STL models at 5 MiB, generated HTML at 250 KB, CSS and JS at 300 KB, and ordinary files at 5 MiB.
- Camera RAW and editing sources, all video and audio, and all archives are refused outright, including when smuggled in as base64 `data:` URIs.
- Git LFS is intentionally not used because GitHub Pages does not support it for published assets.

Enable the versioned hooks once per clone with `npm run setup:hooks`. They are a fast local safety net and are bypassable, so GitHub Actions repeats every check on pull requests and on `main`, then smoke-tests the deployed `/`, `/robots.txt`, `/rss.xml`, and `/sitemap-index.xml`.

The repository uses `main` and is configured for GitHub Pages deployment.
