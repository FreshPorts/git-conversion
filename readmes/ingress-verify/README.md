# ingress-verify

FreshPorts scripts that verify and repair the database. See `README.txt`.

## Conversion from Subversion

This repository was converted from `ingress/Verify` in the `freshports-1`
Subversion repository (`svn+ssh://svn.int.unixathome.org/freshports-1`) in
October 2026, with git-svn. The conversion scripts and logs are in
`~/src/freshports/git-conversion/` (`run-all.sh` rebuilds everything).

### Layout

| git | Subversion |
|---|---|
| `main` | `ingress/Verify/trunk` |
| tags (12) | `ingress/Verify/tags/*` |

This project has no `branches/git`; `main` is its trunk.

### History

These scripts began as `scripts/trunk/Verify`. In September 2018 (r5120) that
directory was copied to `ingress/Verify/trunk`, and git-svn follows whole
directory copies, so history runs from 2006-12-17.

Every converted commit keeps a `git-svn-id:` trailer giving its Subversion
path and revision, so `r1234` references still resolve. SVN usernames are
mapped to names and email addresses (`dan`/`dvl` → Dan Langille).

### Tags

SVN tags are annotated git tags, carrying the tagger, date and message of the
SVN revision that created them. Each tag points at the commit it was copied
from.

Two tags had trunk accidentally copied inside them, which was then moved out
in SVN to make the next tag. Their contents are unchanged, but their date and
message had come from that later move, and now come from their creation:

- `2.0.0`: created r5689 ("Create first tag"); `trunk/` nested and moved out
  twice, in r5692–r5693 (becoming `2.0.1`) and r5695–r5696 (becoming `2.0.2`)
- `2.0.2`: created r5696; `trunk/` nested in r5698 and removed in r5699
  ("Remove erronously placed tag")

### Verification

Every branch was compared file by file with an `svn export` of its SVN path at
HEAD, and every tag with its SVN path at the revision that created it. All 13
matched. Empty directories, which git cannot store, were ignored.

### Not converted

- `svn:ignore` properties; there is no `.gitignore`.
- `$Id$` keywords, which remain unexpanded as stored in SVN.
