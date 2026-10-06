# daemontools

The FreshPorts services and their configuration: `fp-listen`, `freshports`,
`ingress`, `ingress_svn` and `fp-daemon`.

## Conversion from Subversion

This repository was converted from `daemontools` in the `freshports-1`
Subversion repository (`svn+ssh://svn.int.unixathome.org/freshports-1`) in
October 2026, with git-svn. The conversion scripts and logs are in
`~/src/freshports/git-conversion/` (`run-all.sh` rebuilds everything).

### Layout

| git | Subversion |
|---|---|
| `main` | `daemontools/branches/git`, where development happened |
| `trunk` | `daemontools/trunk` (last change 2021-09-10) |
| `FreshPorts2` | `daemontools/branches/FreshPorts2` |
| tags (78) | `daemontools/tags/*` |

Most tags were copied from one service's subdirectory, not from the whole
branch. `fp-listen-1.0.1`, for example, was copied from `trunk/fp-listen`, so
its tree is the contents of `fp-listen/` alone. The tag name says which
service it is: `fp-listen-*`, `freshports-*` and `fp-freshports-*`,
`ingress-*` and `fp-ingress-*`, `ingress_svn-*`, `fp-daemon-*`.

History starts on 2002-02-09. Every converted commit keeps a `git-svn-id:`
trailer giving its Subversion path and revision, so `r1234` references still
resolve. SVN usernames are mapped to names and email addresses (`dan`/`dvl` →
Dan Langille); commits made by cvs2svn appear as `cvs2svn`.

### Tags

SVN tags are annotated git tags, carrying the tagger, date and message of the
SVN revision that created them. Each tag points at the commit it was copied
from.

Corrections made during conversion:

- **Tags deleted in SVN are not carried over.** git-svn had kept them:
  - `fp-listen-git1.0.0` ("Properly name this tag")
  - `freshports-services-1.1.4` ("Created in error")
  - `ingress-2.0.16` ("Create in error - wanted to be working on
    freshports-freshports")
- **Accidental nested copies are removed.** Running `svn cp` onto a tag that
  already exists nests the copy inside it rather than replacing it. These tags
  point at their creating commit, without the nested directory:
  - `fp-freshports-2.0.0`: created r5392; `fp-freshports/` nested in r5394
  - `fp-ingress-2.0.1`: created r5402; `fp-ingress/` nested in r5408
  - `fp-listen-1.0.1`: created r4863 (2017-10-11); `fp-listen/` nested in r4895
    (2017-10-18)
  - `ingress-2.0.4`: created r5427; `ingress/` nested in r5428

  As a result, these four tags no longer match the current contents of their
  SVN tag directories, which still hold the nested copy. They match the tags as
  they were when created.

### Verification

Every branch was compared file by file with an `svn export` of its SVN path at
HEAD, and every tag with its SVN path at the revision that created it. All 81
matched. Empty directories, which git cannot store, were ignored.

### Not converted

- `svn:ignore` properties; there is no `.gitignore`.
- `$Id$` keywords, which remain unexpanded as stored in SVN.
