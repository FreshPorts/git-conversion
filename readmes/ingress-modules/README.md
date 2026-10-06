# ingress-modules

The FreshPorts ingress Perl modules. See `README.txt` for installation notes.

## Conversion from Subversion

This repository was converted from `ingress/modules` in the `freshports-1`
Subversion repository (`svn+ssh://svn.int.unixathome.org/freshports-1`) in
October 2026, with git-svn. The conversion scripts and logs are in
`~/src/freshports/git-conversion/` (`run-all.sh` rebuilds everything).

### Layout

| git | Subversion |
|---|---|
| `main` | `ingress/modules/branches/git`, where development happened |
| `trunk` | `ingress/modules/trunk` |
| tags (64) | `ingress/modules/tags/*` |
| `svn-tag-trunk` | `ingress/modules/tags/trunk`, renamed so it does not clash with the `trunk` branch |
| `pre-split/*` tags (52) and branches `pre-split/FreshPorts1`, `pre-split/FreshPorts2` | `scripts/tags/*` and `scripts/branches/*`, from before the 2018 split (see below) |

Every converted commit keeps a `git-svn-id:` trailer giving its Subversion
path and revision, so `r1234` references still resolve. SVN usernames are
mapped to names and email addresses (`dan`/`dvl` → Dan Langille); commits
made by cvs2svn appear as `cvs2svn`.

### History before 2018

Until May 2018 this code lived in `/scripts`. Between r5065 and r5073 it
was split into `ingress/scripts` and `ingress/modules` by copying files one at a
time, which git-svn cannot follow, and `/scripts` was renamed
`scripts.ARCHIVE`. The converted history therefore began on 2018-05-06.

That earlier history has been grafted back on: the first post-split commit
("Move scripts into a new scipts directory…") now has as its parent
`scripts/trunk@5061` ("Do a better logging attempt", 2018-05-05), the last
`/scripts` commit before the split. History now runs from 2000-05-12, and
`git log --follow` and `git blame` reach back past 2018. `ingress-scripts`
carries the same pre-split history.

The pre-split tags are prefixed `pre-split/` because their version numbers
overlap with the scripts' own: `scripts` 1.1.4–1.1.7 (April 2018) are
different releases from `ingress/scripts` 1.1.4–1.1.7 (August–October 2018).

### Tags

SVN tags are annotated git tags, carrying the tagger, date and message of the
SVN revision that created them. Each tag points at the commit it was copied
from.

Corrections made during conversion:

- **Tags deleted in SVN are not carried over.** `2.0.37` ("I should have done
  this for scripts, not modules") and `2.1.15` ("Should be 2.0.15") were
  deleted in SVN; git-svn had kept them.
- **Accidental nested copies are removed.** Running `svn cp` onto a tag that
  already exists nests the copy inside it (`tags/X/trunk/`) rather than
  replacing it. These tags point at their creating commit, without the nested
  directory:
  - `1.42`: created r5488 (2020-11-03); `trunk/` nested in r5586 (2021-01-28)
  - `pre-split/1.0.8`, `1.0.19`, `1.0.25`, `1.0.27`, `1.0.28`, `1.0.33`,
    `1.0.34` and `1.1.4`: each had a `trunk/` nested after creation

  As a result, these tags no longer match the current contents of their SVN
  tag directories, which still hold the nested copy. They match the tags as
  they were when created.
- **Pre-split tag dates are restored.** The 2018 rename of `/scripts` to
  `/scripts.ARCHIVE` (r5068, "This code no longer used") had become the date
  and message of every pre-split tag. Each now has its original date.

### Verification

Every branch was compared file by file with an `svn export` of its SVN path at
HEAD, and every tag with its SVN path at the revision that created it. All 120
matched. Empty directories, which git cannot store, were ignored.

### Not converted

- `svn:ignore` properties; there is no `.gitignore`.
- `$Id$` keywords, which remain unexpanded as stored in SVN.
