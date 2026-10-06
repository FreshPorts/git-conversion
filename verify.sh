#!/bin/sh
# Compare every branch and tag of repos/<name> with the matching SVN path.
#   usage: verify.sh <svn-project-path> <git-repo-name>
set -u
GIT=/opt/homebrew/bin/git
SVN=/opt/homebrew/bin/svn
SVNREPO=file://$HOME/src/freshports/freshports-1
HERE=$(cd "$(dirname "$0")" && pwd)
PROJ=$1 NAME=$2
REPO=$HERE/repos/$NAME
WORK=${TMPDIR:-/tmp}/fp-verify/$NAME
mkdir -p "$WORK"
top=$($SVN ls "$SVNREPO/$PROJ")
haslayout=$(echo "$top" | grep -cx 'trunk/')
ok=0 bad=0 skip=0
$GIT -C "$REPO" for-each-ref --format='%(refname)' refs/heads refs/tags |
{
while read -r ref; do
	short=${ref#refs/*/}
	case $ref in
	refs/*/attic/*)	skip=$((skip+1)); continue ;;
	refs/heads/main)
		if [ "$haslayout" = 0 ]; then p=$PROJ
		elif $SVN ls "$SVNREPO/$PROJ/branches/git" >/dev/null 2>&1; then p=$PROJ/branches/git
		else p=$PROJ/trunk; fi ;;
	refs/heads/trunk) p=$PROJ/trunk ;;
	refs/heads/pre-split/*) p=scripts.ARCHIVE/branches/${short#pre-split/} ;;
	refs/heads/*)	p=$PROJ/branches/$short ;;
	refs/tags/*)
		# A tag is checked against SVN as it was when the tag was created,
		# from the git-svn-id in its annotation (see retarget-tags.py).
		p=$($GIT -C "$REPO" for-each-ref --format='%(contents)' "$ref" |
			sed -n 's|^git-svn-id: [^ ]*/freshports-1/\([^ ]*\) .*|\1|p' | tail -1) ;;
	esac
	s=$WORK/svn g=$WORK/git
	chmod -R u+w "$s" "$g" 2>/dev/null; rm -rf "$s" "$g"; mkdir -p "$g"
	$SVN export -q --ignore-keywords --force "$SVNREPO/$p" "$s" || { echo "$NAME: $ref: svn export of $p failed"; bad=$((bad+1)); continue; }
	$GIT -C "$REPO" archive "$ref" | tar -x -C "$g"
	mkdir -p "$s"
	# git cannot store empty directories; ignore them.
	find "$s" -type d -empty -delete 2>/dev/null; mkdir -p "$s"
	if diff -rq "$s" "$g" >/dev/null 2>&1; then ok=$((ok+1))
	else bad=$((bad+1)); echo "$NAME: $ref differs from $p:"; diff -rq "$s" "$g" | head -5; fi
done
echo "$NAME: $ok ok, $bad differ, $skip attic skipped, $($GIT -C "$REPO" rev-list --count --all) commits"
}
