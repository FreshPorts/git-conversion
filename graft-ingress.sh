#!/bin/sh
# Give ingress-modules and ingress-scripts their pre-2018 history. In May 2018
# (r5065-r5073) /scripts was split into ingress/scripts and ingress/modules by
# copying files one at a time, which git-svn cannot follow, so both repos
# started at r5066. This grafts their root commit onto the last /scripts/trunk
# commit before the split, and brings the old tags and branches in under
# pre-split/ (scripts.ARCHIVE 1.1.4-1.1.7 are different releases from
# ingress/scripts 1.1.4-1.1.7).
# Run after convert.sh; the ungrafted repos are kept in repos/.pre-graft/.
set -eu
PATH=/opt/homebrew/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
ARCHIVE=$HERE/repos/scripts.ARCHIVE
# scripts/trunk@5061, the last /scripts trunk commit before the split
PARENT_SVN='scripts/trunk@5061 '

for NAME in ingress-modules ingress-scripts; do
	R=$HERE/repos/$NAME
	mkdir -p "$HERE/repos/.pre-graft"
	rm -rf "$HERE/repos/.pre-graft/$NAME"
	cp -Rp "$R" "$HERE/repos/.pre-graft/$NAME"

	git -C "$R" fetch -q --no-tags "$ARCHIVE" \
		"+refs/heads/main:refs/pre-graft/main" \
		"+refs/heads/FreshPorts1:refs/heads/pre-split/FreshPorts1" \
		"+refs/heads/FreshPorts2:refs/heads/pre-split/FreshPorts2" \
		"+refs/tags/*:refs/tags/pre-split/*"
	parent=$(git -C "$R" log --format=%H --grep="freshports-1/$PARENT_SVN" -F refs/pre-graft/main | head -1)
	[ -n "$parent" ] || { echo "$NAME: graft parent not found" >&2; exit 1; }
	roots=$(git -C "$R" rev-list --max-parents=0 main)
	[ "$(echo "$roots" | wc -l)" -eq 1 ] || { echo "$NAME: expected one root, got: $roots" >&2; exit 1; }
	git -C "$R" replace --graft "$roots" "$parent"
	git -C "$R" update-ref -d refs/pre-graft/main
	# filter-repo writes the replacement into real history and drops the
	# replace ref; every commit after the split gets a new hash.
	git -C "$R" filter-repo --quiet --force --replace-refs delete-no-add
	git -C "$R" reflog expire --expire=now --all
	git -C "$R" gc -q --prune=now
	echo "$NAME: root now has parent $(git -C "$R" log -1 --format='%h %ad %s' --date=short --grep="freshports-1/$PARENT_SVN" -F main)"
done
