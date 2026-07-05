---
name: new-release
description: Creates a GitHub pre-release for Oinkoin with a tag, release name, and a one-line changelog summary. Use when the user wants to ship a new version.
argument-hint: "<version>"
---

# Skill: new-release

Create a pre-release on GitHub for the given version.

## Usage
```
/new-release 1.9.0
```

---

## Steps

### Step 1 — Confirm the version

The version comes from the skill argument (e.g. `1.9.0`). If the user didn't provide one, ask for it before continuing.

### Step 2 — Find the previous release tag

```bash
gh release list --limit 10
```

Identify the most recent non-draft, non-pre-release tag to use as the comparison base.

### Step 3 — Collect commits since the previous tag

```bash
git log <previous-tag>..HEAD --oneline
```

### Step 4 — Draft the changelog with the user

From the commit list, propose a single-line summary of the user-facing changes. Rules:
- The whole changelog is **one line, under 100 characters total** — not a bullet list, not per-bullet
- Do not reference issue/PR numbers (e.g. no `(#123)`)
- Skip internal/chore commits (version bumps, CI, typos) unless they matter to users
- Condense multiple changes into a single concise sentence rather than listing them separately
- Write in plain English, present tense ("Add X", "Fix Y", "Improve Z")
- Show the draft to the user and **ask for approval or edits** before creating the release

### Step 5 — Create the tag and pre-release

Once the user approves the changelog:

```bash
# Create and push the tag
git tag <version>
git push origin <version>

# Create the pre-release
gh release create <version> \
  --title "<version>" \
  --notes "<approved bullet points>" \
  --prerelease
```

### Step 6 — Confirm

Print the release URL returned by `gh release create` so the user can review it on GitHub.
