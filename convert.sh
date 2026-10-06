#!/bin/sh
# Convert one project of the freshports-1 SVN repository into a git repo.
#   usage: convert.sh <svn-project-path> <git-repo-name>
# Runs from the directory holding authors.txt; output goes to repos/<name>.
set -eu
GIT=/opt/homebrew/bin/git
SVN=/opt/homebrew/bin/svn
SVNREPO=${SVNREPO:-file://$HOME/src/freshports/freshports-1}
REWRITE_ROOT=svn+ssh://svnusers@svn.int.unixathome.org/freshports-1
HERE=$(cd "$(dirname "$0")" && pwd)
PROJ=$1
NAME=$2
DEST=$HERE/repos/$NAME

# RESUME=1 continues an interrupted fetch instead of starting over.
RESUME=${RESUME:-0}
if [ "$RESUME" = 0 ]; then
	rm -rf "$DEST"
fi
mkdir -p "$DEST" "$HERE/logs"
: > "$HERE/logs/$NAME.tags.log"
cd "$DEST"

top=$($SVN ls "$SVNREPO/$PROJ")
layout=
echo "$top" | grep -qx 'trunk/'    && layout="$layout -T trunk"
echo "$top" | grep -qx 'tags/'     && layout="$layout -t tags"
echo "$top" | grep -qx 'branches/' && layout="$layout -b branches"
[ -z "$layout" ] && layout="-T ."	# no standard layout: the directory is the trunk

if [ "$RESUME" = 0 ]; then
	$GIT init -q -b main
	$GIT svn init --prefix=svn/ --rewrite-root="$REWRITE_ROOT" $layout "$SVNREPO/$PROJ" >/dev/null
	$GIT config svn.authorsfile "$HERE/authors.txt"
fi
$GIT svn fetch -q --log-window-size=1000 >> "$HERE/logs/$NAME.fetch.log" 2>&1

# Stop here if the fetch was interrupted (no checkout means it never finished).
$GIT show-ref -q --verify refs/remotes/svn/trunk || $GIT show-ref -q --verify refs/remotes/svn/git || { echo "$NAME: fetch incomplete" >&2; exit 1; }

# Branches. branches/git is where development happens, so it becomes main.
if $GIT show-ref -q --verify refs/remotes/svn/git; then
	mainref=refs/remotes/svn/git
else
	mainref=refs/remotes/svn/trunk
fi
$GIT update-ref refs/heads/main "$mainref"
$GIT for-each-ref --format='%(refname)' refs/remotes/svn | grep -v '^refs/remotes/svn/tags/' |
while read -r ref; do
	b=${ref#refs/remotes/svn/}
	[ "$ref" = "$mainref" ] && continue
	$GIT update-ref "refs/heads/$b" "$ref"
done

# Tags. git-svn records an SVN tag as a commit on its own line; turn each into
# an annotated tag carrying the original author, date and message. A tag made
# by a pure copy has the same tree as its parent, so tag the parent instead.
$GIT for-each-ref --format='%(refname)' refs/remotes/svn/tags |
while read -r ref; do
	t=${ref#refs/remotes/svn/tags/}
	c=$($GIT rev-parse "$ref")
	target=$c
	if p=$($GIT rev-parse -q --verify "$c^" 2>/dev/null) &&
	   [ "$($GIT rev-parse "$c^{tree}")" = "$($GIT rev-parse "$p^{tree}")" ]; then
		target=$p
	fi
	name=$t
	# A tag literally named "trunk" (or any name clashing with a branch)
	# would make the ref ambiguous.
	$GIT show-ref -q --verify "refs/heads/$name" && name="svn-tag-$name"
	# cvs2svn made tags named "head"; on a case-insensitive filesystem git
	# resolves that to HEAD.
	[ "$name" = head ] && name=cvs-head
	GIT_COMMITTER_NAME=$($GIT log -1 --format=%an "$c") \
	GIT_COMMITTER_EMAIL=$($GIT log -1 --format=%ae "$c") \
	GIT_COMMITTER_DATE=$($GIT log -1 --format=%aI "$c") \
		$GIT tag -a -F - "$name" "$target" <<MSG
$($GIT log -1 --format=%B "$c")
MSG
	echo "$NAME: tag $t -> $name" >> "$HERE/logs/$NAME.tags.log"
done

# git-svn keeps a deleted-then-recreated SVN path as name@rev. Drop those whose
# history is already reachable from a real branch or tag; keep the rest, under
# attic/, so nothing is lost.
$GIT for-each-ref --format='%(refname)' refs/heads refs/tags | grep '@[0-9]*$' |
while read -r ref; do
	others=$($GIT for-each-ref --format='%(refname)' refs/heads refs/tags | grep -v '@[0-9]*$')
	if [ -n "$others" ] && [ -z "$($GIT rev-list -n1 "$ref" --not $others)" ]; then
		$GIT update-ref -d "$ref"
		echo "$NAME: dropped $ref (already reachable)" >> "$HERE/logs/$NAME.tags.log"
	else
		kind=${ref#refs/}; kind=${kind%%/*}; short=${ref#refs/$kind/}
		$GIT update-ref "refs/$kind/attic/$short" "$ref"
		$GIT update-ref -d "$ref"
		echo "$NAME: kept $ref as refs/$kind/attic/$short" >> "$HERE/logs/$NAME.tags.log"
	fi
done

"$HERE/prune-deleted-tags.sh" "$PROJ" "$NAME"

# Drop the git-svn scaffolding; the git-svn-id trailers in each message keep
# the SVN revision numbers.
$GIT for-each-ref --format='%(refname)' refs/remotes | xargs -n1 $GIT update-ref -d
rm -rf .git/svn
$GIT config --remove-section svn-remote.svn
$GIT config --unset svn.authorsfile
$GIT reflog expire --expire=now --all
$GIT gc -q --prune=now
# git-svn left trunk checked out; make the work tree match main
$GIT reset -q --hard main
echo "$NAME: done"
