# database-schema

The FreshPorts database schema. See `README` for notes on the schema.

## Conversion from Subversion

This repository was converted from `database-schema` in the `freshports-1`
Subversion repository (`svn+ssh://svn.int.unixathome.org/freshports-1`) in
October 2026, with git-svn. The conversion scripts and logs are in
`~/src/freshports/git-conversion/` (`run-all.sh` rebuilds everything).

### Layout

| git | Subversion |
|---|---|
| `main` | `database-schema/branches/git`, where development happened |
| `trunk` | `database-schema/trunk` (last change 2021-03-14) |
| `FreshPorts2` | `database-schema/branches/FreshPorts2` |
| tags (5) | `database-schema/tags/*` |
| `cvs-head` | `database-schema/tags/head` (see below) |

History starts on 2001-01-04; it began in CVS and was moved to Subversion with
cvs2svn. Every converted commit keeps a `git-svn-id:` trailer giving its
Subversion path and revision, so `r1234` references still resolve. SVN
usernames are mapped to names and email addresses (`dan`/`dvl` → Dan
Langille); commits made by cvs2svn appear as `cvs2svn`.

### Tags

SVN tags are annotated git tags, carrying the tagger, date and message of the
SVN revision that created them. Each tag points at the commit it was copied
from.

The tag cvs2svn created as `head` is named `cvs-head` here. On a
case-insensitive filesystem, such as macOS's, git resolves a tag named `head`
to `HEAD`.

Much of this project's history before August 2015 also appears in
`FreshPorts/freshports`, which was converted from the root of the same
Subversion repository.

### Verification

Every branch was compared file by file with an `svn export` of its SVN path at
HEAD, and every tag with its SVN path at the revision that created it. All 8
matched. Empty directories, which git cannot store, were ignored.

### Not converted

- `svn:ignore` properties; there is no `.gitignore`.
- `$Id$` keywords, which remain unexpanded as stored in SVN.
