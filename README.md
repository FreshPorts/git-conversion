# git-conversion

The scripts that converted the FreshPorts Subversion repository, `freshports-1`,
to git in October 2026: one git repository per project, with full history,
branches and tags. The SVN server was shut down afterwards, at r6278.

## What it produces

| Repository | From Subversion | Notes |
|---|---|---|
| `daemon-freshports` | `daemontools` (`freshports/`) | split out by `split-daemontools.sh` |
| `daemon-ingress` | `daemontools` (`ingress/`) | split out by `split-daemontools.sh` |
| `fp-listen` | `daemontools` (`fp-listen/`) | split out by `split-daemontools.sh` |
| `daemontools` | `daemontools` | keeps `fp-daemon/` and `ingress_svn/` |
| `database-schema` | `database-schema` | |
| `ingress-modules` | `ingress/modules` | pre-2018 `/scripts` history grafted on |
| `ingress-scripts` | `ingress/scripts` | pre-2018 `/scripts` history grafted on |
| `ingress-verify` | `ingress/Verify` | |
| `packaging-for-svn` | `packaging` | |
| `freshports-archive` | ten dormant projects | one directory per project |

Also built, but not published: `periodics` (FreshPorts/periodics had already
moved on), `scripts.ARCHIVE` (its history is inside both ingress repositories),
and `classes`, `configuration`, `docs`, `fwatch` and `include` (already in
FreshPorts/freshports), plus the ten dormant projects before they are combined.

Each converted repository has its own README describing its conversion; the
sources are in `readmes/`.

## Requirements

- The Subversion repository itself (not a working copy) at
  `~/src/freshports/freshports-1`. Make one with `svnadmin hotcopy`, or
  restore an `svnadmin dump` into a new repository with `svnadmin load`.
- git, git-svn, git-filter-repo, Subversion, Python 3 and gh. The scripts
  expect them in `/opt/homebrew/bin` (Homebrew on Apple silicon); on other
  systems, change the `PATH=`, `GIT=` and `SVN=` lines.
- About 100 MB of disk for `repos/`, and two hours: `scripts.ARCHIVE` alone
  takes more than one, because git-svn replays every deleted and recreated
  tag.

## Running it

```sh
./run-all.sh
```

Output goes to `repos/`, logs to `logs/`; neither is kept in git. The steps, in
order:

| Script | What it does |
|---|---|
| `convert.sh` | git-svn conversion of each project in `projects.txt`, with `authors.txt`; `branches/git` becomes `main` |
| `prune-deleted-tags.sh` | (called by `convert.sh`) drops tags deleted in SVN |
| `fix-tag-annotations.py` | gives the `scripts.ARCHIVE` tags the date and message of the revision that created them |
| `retarget-tags.py` | points tags hit by an accidental second `svn cp` (which nests a copy inside the tag) back at their creating commit |
| `combine-archive.sh` | merges the dormant projects into `freshports-archive` |
| `graft-ingress.sh` | grafts `/scripts` history (2000-2018) under `ingress-modules` and `ingress-scripts` |
| `verify.sh` | compares every branch with an `svn export` at HEAD, and every tag at the revision that created it |
| `add-readmes.sh` | commits `readmes/<repo>/README.md` |
| `split-daemontools.sh` | splits `daemontools` into `daemon-freshports`, `daemon-ingress` and `fp-listen` |
| `verify-split.py` | compares every commit and tag of the split repositories with SVN |

`run-all.sh` stops if verification finds any difference. `verify-deleted.sh`
is a one-off check used while investigating tags deleted in SVN.

## Publishing

```sh
./push-to-github.sh            # all of them
./push-to-github.sh fp-listen  # or only some, by local name
```

It creates each repository in the FreshPorts organization as private, and
pushes every branch and tag. It skips any repository whose name already exists
on GitHub, or which already has an `origin`.
