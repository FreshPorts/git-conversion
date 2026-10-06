# packaging-for-svn

FreshPorts packaging files as they stand in Subversion, including the `cut-*`
scripts, which tag a release in SVN, export it, and copy the tarball to
pkg01. See `README.TXT`.

This is not [FreshPorts/packaging](https://github.com/FreshPorts/packaging).
That repository was converted from SVN up to r6036 and has since been
developed on GitHub, where the `cut-*` scripts were retired and the manifest
file origins moved. This repository follows SVN instead, through r6272
(2026-10-03, a change to the `cut-*` scripts). The two share history up to
r6036, though with different commit hashes.

## Conversion from Subversion

This repository was converted from `packaging` in the `freshports-1`
Subversion repository (`svn+ssh://svn.int.unixathome.org/freshports-1`) in
October 2026, with git-svn. The conversion scripts and logs are in
`~/src/freshports/git-conversion/` (`run-all.sh` rebuilds everything).

### Layout

| git | Subversion |
|---|---|
| `main` | `packaging/trunk` |

The project had no branches or tags. History starts on 2018-04-28.

Every converted commit keeps a `git-svn-id:` trailer giving its Subversion
path and revision, so `r1234` references still resolve. SVN usernames are
mapped to names and email addresses (`dan`/`dvl` → Dan Langille).

### Verification

`main` was compared file by file with an `svn export` of `packaging/trunk` at
HEAD, and matched. Empty directories, which git cannot store, were ignored.

### Not converted

- `svn:ignore` properties; there is no `.gitignore`.
- `$Id$` keywords, which remain unexpanded as stored in SVN.
