# Local Git hooks

Enable the versioned hooks once after initializing or cloning the repository:

```powershell
git config core.hooksPath .githooks
```

The pre-commit hook checks exactly what is staged. The pre-push hook checks every
new blob in the outgoing commit ranges, then checks local content links. Both are
fast safety nets; GitHub Actions repeats the checks because hooks can be bypassed.

These hooks never edit files, commit, or push on their own.
