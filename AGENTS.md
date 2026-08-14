# Agent guide

Authoritative defaults for AI agents working in this repository. `CLAUDE.md` is a
hard link to this file; edit `AGENTS.md` and the other entry point follows.

Read this file first. Route to [CONTENT_GUIDE.md](CONTENT_GUIDE.md) for authoring
rules and to [README.md](README.md) for the human-facing overview.

## What this project is

A static personal site — writing, projects, book notes, 3D prints, quotations,
and a résumé — built with Astro 7, authored in Markdown, and deployed to
`bellsworth.dev` through GitHub Pages. Output is `static`; there is no server,
no database, and no CMS.

The site carries **real personal information** about its owner: name, public
email, LinkedIn, Instagram, biography, and résumé history. Never invent
employment, institutions, dates, credentials, or skills, and never present
generated prose as the owner's own writing. When real material is missing, leave
a labeled placeholder rather than filling the gap.

## Non-negotiable constraints

### Size and Git history

GitHub Pages refuses to publish a site above **1 GB**. Three independent budgets
in [`config/size-budgets.json`](config/size-budgets.json) keep the project far
below it, each warning at 100 MiB and hard-failing at 250 MiB:

| Budget    | Covers                        | Recoverable?                     |
| --------- | ----------------------------- | -------------------------------- |
| `source`  | the working tree              | yes — delete the file            |
| `dist`    | the generated site            | yes — rebuild                    |
| `history` | every blob reachable from Git | **no — needs a history rewrite** |

The history budget is a one-way ratchet. A large file committed once counts
against it forever, even if the next commit deletes it. Treat every binary that
enters a commit as permanent. Git LFS is deliberately unused because GitHub Pages
does not serve LFS-backed assets.

Per-file limits: source images 2 MiB, dist images 1 MiB, PDFs 3 MiB, STL models
5 MiB, HTML 250 KB, CSS/JS 300 KB, any other file 5 MiB.

The three.js print viewer holds a **named exemption** (768 KB) recorded with its
rationale in the config. It is valid only while the bundle stays code-split and
loads on print pages alone. Importing three.js into a shared layout or a non-print
route breaks the budget and the exemption's premise at once.

### Forbidden file types

Camera RAW and editing sources (`.cr2`, `.nef`, `.dng`, `.psd`, `.tif`, `.heic`,
and similar), all video and audio, and all archives and disk images are rejected
outright — not merely discouraged. Base64 media smuggled into source files is
caught separately by an inline `data:` URI check. Add a new binary type to
`config/size-budgets.json` before committing it, never by working around the
checker.

### Privacy

Keep these out of committed content: private addresses and phone numbers;
credentials, API keys, and `.env` values; private notes hidden in HTML comments;
local absolute file paths; and unstripped photograph metadata. `src/content/_drafts/`
is Git-ignored but unencrypted, and is not backed up by GitHub.

Import every image through `npm run media:import`, which strips EXIF and GPS,
caps the long edge at 2400 px, and writes WebP at quality 82. Keep camera
originals outside the repository.

## Content model

Six collections are registered in [`src/content.config.ts`](src/content.config.ts):
`writing`, `projects`, `books`, `quotes`, `pages`, and `prints`. That file is the
single source of truth for every schema — read it before adding or changing
frontmatter, and prefer it over any prose description including this one.

Schema rules that are easy to violate:

- **`draft` defaults to `true`.** Omitting the field hides the entry. Publishing
  always requires an explicit `draft: false`.
- **Tags must match `^[a-z0-9]+(?:-[a-z0-9]+)*$`** — lowercase kebab-case only.
  Anything else fails the build.
- **Every string field is length-capped**: titles 120, descriptions and summaries
  240, alt text 240, `material` 60. Copy that reads well can still fail
  validation.
- **Unlisted fields are rejected.** Add the field to the schema first.

Visibility is decided by [`src/utils/visibility.ts`](src/utils/visibility.ts):
a draft is never visible, and a placeholder is visible only while `site.preview`
is `true`. `site.preview` also drives the `noindex` metadata that keeps the site
out of search results before launch. Leave it enabled until launch is agreed.

Live identity and résumé data are TypeScript, not Markdown:
[`src/data/site.ts`](src/data/site.ts) and
[`src/data/resume.ts`](src/data/resume.ts). The Markdown files
`src/content/pages/home.md` and `resume.md` are writing worksheets that render
nowhere; `about.md` renders directly as the `/` homepage, and `/about/` redirects
there. Editing a worksheet does not change the site.

Filenames are lowercase kebab-case and become stable content IDs and URL slugs.
Renaming a published file breaks its URL and needs a redirect arranged first.

Use plain Markdown. Obsidian wikilinks, embeds, block references, and callouts
are rejected by the link checker.

## Working in this repository

Start the dev server in background mode and manage it with the paired scripts:

```powershell
npm run dev -- --background
npm run dev:status
npm run dev:logs
npm run dev:stop
```

Node is pinned to `>=24 <25` (`.node-version` records `24.11.1`). Install with
`npm ci`, never `npm install`, so the lockfile is respected.

The low-level Node helpers never run Git, never commit, and never push:

| Command                   | Purpose                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| `npm run content:new`     | Scaffold a draft in `_drafts` (`writing`, `project`, `book`, `print`, `quotation`, `page`) |
| `npm run content:list`    | List files still marked `draft: true`                                                      |
| `npm run content:publish` | Validate one file and flip it to published                                                 |
| `npm run media:import`    | Convert one image into a safe web master                                                   |

Two PowerShell orchestrators are explicitly approved to commit and push. Both must show the
changes for human review and require the exact typed confirmation `PUBLISH` before any commit
or push. Neither may use `git add .`, force-push, bypass hooks, or automatically resolve branch
divergence.

| Launcher                             | Entry point                             | Use it for                                                            |
| ------------------------------------ | --------------------------------------- | --------------------------------------------------------------------- |
| `Publish Website Changes.cmd`        | `scripts/authoring/Publish-Changes.ps1` | Publishing whatever is already edited — the default for routine edits |
| `Start Website Content Workflow.cmd` | `npm run content:workflow`              | Scaffolding a new entry or importing media, as a resumable batch      |

`Publish-Changes.ps1` treats the working tree itself as the unit of work. It derives its file
list from `Get-WorkflowChangedPaths`, which honours `.gitignore`, so ignored paths cannot reach
a commit; it then stages those exact paths. It formats the changed files with Prettier before
verifying, because Obsidian reliably breaks the format check. It runs in one pass and keeps no
session state.

Its review step opens each staged change as a VS Code diff through `git difftool`, one file at
a time, and waits for each tab to close. Pass `-TerminalDiff` to print the diff in the console
instead; the console is also used automatically when VS Code is not on `PATH`. The difftool
settings travel as `GIT_CONFIG_*` environment variables, not `git -c` arguments, because
Windows PowerShell 5.1 does not escape the quotes around `$LOCAL` and `$REMOTE` when calling a
native executable. The user's own `diff.tool` configuration is never modified.

`npm run content:workflow` manages a resumable batch, calls the low-level helpers, previews,
verifies, stages exact recorded paths, commits, pushes `main`, and monitors GitHub Pages. It
refuses to publish changes that its batch does not record, so an edit made directly in Obsidian
outside a batch belongs to the one-shot launcher instead. Its session state, logs, backups, and
preferences belong only in the Git-ignored `.authoring-workflow/` directory.

Outside those two approved orchestrators, committing and pushing remain separate, deliberate,
human-reviewed steps.

## Verification

Run the full gate before reporting any change complete:

```powershell
npm run verify
```

That is `npm run check` — source and history asset budgets, local links,
markdownlint, content tests, Prettier, and `astro check` — followed by a
production build and the `dist` asset and link checks. `npm run check` alone
skips the build, so it cannot catch a build-time schema or image failure.

Formatting is enforced, not advisory: **tabs**, single quotes, 100-column width,
trailing commas. `.gitattributes` forces LF on scripts, hooks, and config because
CRLF breaks GitHub Actions and the Git hooks. `.obsidian/` is deliberately
excluded from Prettier — Obsidian rewrites it with two-space indentation and no
trailing newline whenever the app touches the vault.

Local hooks are versioned and enabled once per clone:

```powershell
npm run setup:hooks
```

`pre-commit` checks staged files; `pre-push` checks outgoing blobs, the history
budget, and source links. Hooks are a fast safety net and are bypassable, so
[`.github/workflows/pages.yml`](.github/workflows/pages.yml) repeats every check
on pull requests and on `main`. CI checks out with `fetch-depth: 0` because the
history budget needs full history, and a post-deploy smoke test requests `/`,
`/robots.txt`, `/rss.xml`, and `/sitemap-index.xml` — so breaking the feed or the
sitemap fails the pipeline after deployment.

## Keeping this file honest

`src/content.config.ts`, `config/size-budgets.json`, and `src/data/site.ts` are
the real contracts. When one of them changes, update this file and
[CONTENT_GUIDE.md](CONTENT_GUIDE.md) in the same change, or the next agent will
work from a stale description.
