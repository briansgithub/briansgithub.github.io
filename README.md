# Personal website

A static personal site for writing, projects, book notes, quotations, and a résumé. It is built with Astro, authored primarily in Markdown, and prepared for free deployment to `briansgithub.github.io` with GitHub Pages.

The site is currently in **content preview mode**. Placeholder material is visibly labeled and every page includes `noindex` metadata until the identity and launch content are ready.

## Start locally

Node `24.11.1` is recorded in `.node-version`. The existing NVM-managed Node installation on this computer is the intended runtime; no global Astro installation is needed.

```powershell
npm ci
npm run dev -- --background
```

Open `http://localhost:4321`. Useful server commands:

```powershell
npm run dev:status
npm run dev:logs
npm run dev:stop
```

VS Code also exposes these as friendly tasks through **Terminal → Run Task**.

## Write content

Open `src/content` as an Obsidian vault. The committed settings use ordinary Markdown links, keep new notes in the Git-ignored `_drafts` folder, and provide templates for each content type.

The full workflow is in [CONTENT_GUIDE.md](CONTENT_GUIDE.md). The shortest path is:

1. Run the VS Code task **Content: create draft**, or use an Obsidian template.
2. Write and preview the Markdown note.
3. Run **Content: check current file for publication**.
4. Run **Content: publish current file** when it is complete.
5. Review the diff, then commit it yourself. No helper script commits or pushes.

Recurring public content lives in:

- `src/content/writing`
- `src/content/projects`
- `src/content/books`
- `src/content/quotes`

The live identity and résumé fields are in `src/data/site.ts` and `src/data/resume.ts`. The placeholder `pages/home.md` and `pages/resume.md` files are writing worksheets; `pages/about.md` supplies the rendered About copy.

## Import an image

Keep camera originals outside this repository. Use the VS Code task **Media: import image**, or:

```powershell
npm run media:import -- "C:\path\to\original.jpg" --name lab-bench --alt "Oscilloscope and prototype board on a workbench"
```

The importer preserves the original, strips metadata, limits the long edge to 2400 pixels, exports WebP at quality 82, and refuses output above 2 MiB.

## Verify a change

```powershell
npm run verify
```

This validates content schemas, Markdown, formatting, local links, source assets, the production build, and generated-site budgets. Git hooks repeat fast checks before commits and pushes; GitHub Actions repeats the complete verification before deployment.

## Repository safety

- Raw media, private drafts, dependencies, and generated output are ignored.
- Source images are capped at 2 MiB; the résumé PDF at 3 MiB; ordinary files at 5 MiB.
- The full tracked asset budget and generated-site budget are each 250 MiB—well below GitHub Pages' 1 GB limits.
- Git LFS is intentionally not used because GitHub Pages does not support it for published assets.

The repository is initialized locally on `main` with versioned hooks enabled. It has not been connected to, pushed to, or published on GitHub yet.
