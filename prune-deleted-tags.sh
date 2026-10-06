#!/bin/sh
# Delete git tags whose SVN tag no longer exists at HEAD: each was removed
# in SVN on purpose ("created in error", renamed, ...). attic/ tags are kept.
#   usage: prune-deleted-tags.sh <svn-project-path> <git-repo-name>
set -eu
PATH=/opt/homebrew/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
PROJ=$1 NAME=$2
svntags=$(svn ls "file://$HOME/src/freshports/freshports-1/$PROJ/tags" 2>/dev/null | sed 's|/$||') || true
git -C "$HERE/repos/$NAME" for-each-ref --format='%(refname)' refs/tags | sed 's|^refs/tags/||' | grep -v '^attic/' |
while read -r t; do
	case $t in *@*) continue ;; esac	# name@rev refs are handled by convert.sh
	t2=${t#svn-tag-}; [ "$t2" = cvs-head ] && t2=head
	echo "$svntags" | grep -qxF "$t2" && continue
	git -C "$HERE/repos/$NAME" update-ref -d "refs/tags/$t" >/dev/null
	echo "$NAME: pruned tag $t (deleted in SVN)" | tee -a "$HERE/logs/$NAME.tags.log"
done
