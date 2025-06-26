### `diff-search-patched.pl` User Guide

*(save this file as **diff-search-patched.md** in the same repository as the script)*

---

## 1  Purpose

When upgrading a Zimbra system you often receive several new RPMs that contain feature changes **and** security fixes.
A common workflow to isolate the security–relevant pieces is:

```bash
# 1. unpack the currently-installed RPMs
mkdir old
rpm2cpio current.rpm | cpio -idmv -D old

# 2. unpack the incoming RPMs
mkdir new
rpm2cpio incoming.rpm | cpio -idmv -D new

# 3. produce a unified diff between the two trees
diff -ruN old new > files.diff
```

`diff-search-patched.pl` lets you extract **only** the hunks that match one or more search terms (e.g. `htmlEncode`, `escapeHtml`) and—optionally—apply those filtered changes back to the **old/** tree without bringing in unrelated feature code.

---

## 2  Key Features

* Filters any unified diff for supplied search term(s)
* Handles text files and bundle files (`.js`, `.jsp`, `.xml`)
* Optional in-place application of the filtered patch
* Automatic CRLF→LF conversion to prevent patch failures
* Optional re-compression of touched bundle files (`*.zgz`, `*.gz`)
* Auxiliary actions for audit and deployment

  * log list of patched files
  * copy patched files to a staging directory
  * produce a tarball of the patched files
  * generate a commit-ready patch containing only the applied changes

---

## 3  Command-line Syntax

```text
diff-search-patched.pl --search PATTERN --file FILE.diff [options]
```

### Required arguments

| Option                 | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `-s, --search PATTERN` | Keyword to filter diff hunks (may be given more than once).        |
| `-f, --file FILE`      | Full unified diff generated with `diff -ruN old new > files.diff`. |

### Patch actions

| Option        | Description                                                                                                              |
| ------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `-a, --apply` | Apply the filtered patch to the **old/** tree and (unless `--no-gzip`) regenerate any matching `*.zgz` / `*.gz` bundles. |
| `--no-gzip`   | Skip bundle re-compression even when `--apply` is given.                                                                 |

### Output / packaging options

| Option                       | Description                                                                       |
| ---------------------------- | --------------------------------------------------------------------------------- |
| `-o, --output FILE`          | Write the filtered diff to a file instead of *stdout*.                            |
| `--log-patched FILE`         | Write a plain-text list of patched files.                                         |
| `--copy-patched-to DIR`      | Copy each patched file into the target directory, preserving relative paths.      |
| `--tarball FILE`             | Create a `tar.gz` archive containing every patched file.                          |
| `--create-commit-patch FILE` | Generate a commit-style unified diff of the changes actually applied to **old/**. |

### Behaviour / diagnostics

| Option              | Description                                      |
| ------------------- | ------------------------------------------------ |
| `-i, --ignore-case` | Case-insensitive search.                         |
| `-S, --stats`       | Print statistics about files, hunks and matches. |
| `-n, --dry-run`     | Show what would happen without writing files.    |
| `-v, --verbose`     | Extra informational output.                      |
| `-h, --help`        | Full help text.                                  |

---

## 4  Workflow Examples

| Goal                                            | Command                                                                                                                                     |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Show statistics (no patching)                   | `diff-search-patched.pl --search htmlEncode --stats --file files.diff`                                                                      |
| Create a slim patch file for review             | `diff-search-patched.pl --search htmlEncode --file files.diff -o htmlEncode.patch`                                                          |
| Apply filtered patch and regenerate bundles     | `diff-search-patched.pl --search htmlEncode --apply --file files.diff`                                                                      |
| Apply but **skip** gzip regeneration            | `diff-search-patched.pl --search htmlEncode --apply --file files.diff --no-gzip`                                                            |
| Log patched files and copy them to `/tmp/stage` | `diff-search-patched.pl --search htmlEncode --apply --file files.diff --log-patched patched.log --copy-patched-to /tmp/stage`               |
| Full deployment bundle (tarball + commit diff)  | `diff-search-patched.pl --search htmlEncode --apply --file files.diff --tarball htmlEncode_fixes.tar.gz --create-commit-patch commit.patch` |

---

## 5  File Handling Rules

* Only files ending in **`.js`  `.jsp`  `.xml`** are eligible for CRLF normalisation and gzip regeneration.
* Bundle files are recognised by existing companions `*.zgz` or `*.gz` in **old/**.
* Timestamps on the `+++ new/...` diff lines are stripped automatically; leading `./` segments are removed.

---

## 6  Prerequisites

* Perl 5.10+ (core modules only)
* External programs: `patch`, `dos2unix`, `gzip`, `diff`, `tar`

Ensure they are on the system `PATH` before running.

---

## 7  Best Practices

1. Always run with `--stats` or `--dry-run` first during triage.
2. Keep a clean backup of **old/** before the first `--apply`.
3. Use `--log-patched` and/or `--tarball` for an auditable artefact of exactly what changed.
4. Review the commit-patch (`--create-commit-patch`) in Git or a code-review tool before promoting to production.

---

*Maintainer: your-name • Last updated: 2025-06-26*

