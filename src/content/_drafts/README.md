# Private drafts

This folder is the default location for new Obsidian notes.

The repository `.gitignore` excludes draft files in this folder from Git while retaining this README. This prevents accidental publication, but the folder is not encrypted and is not backed up by GitHub.

After the ignore rule exists, mirror the final collection structure inside this folder:

```text
_drafts/
  writing/
  projects/
  books/
  quotes/
  pages/
```

Move a completed entry into its matching collection, remove all `[PLACEHOLDER]` text, set `placeholder: false`, and set `draft: false` before publishing.
