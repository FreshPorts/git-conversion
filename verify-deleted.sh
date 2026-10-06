#!/bin/sh
# Check git tags whose SVN tag was later deleted against the SVN path at the
# revision recorded in the tagged commit's git-svn-id.
PATH=/opt/homebrew/bin:$PATH
R=file://$HOME/src/freshports/freshports-1
W=${TMPDIR:-/tmp}/fp-verify/deleted
while read -r name ref; do
	repo=repos/$name
	id=$(git -C $repo log -1 --format=%B "$ref" | grep git-svn-id | sed 's/.*freshports-1\///; s/ .*//')
	p=${id%@*}; rev=${id#*@}
	chmod -R u+w $W 2>/dev/null; rm -rf $W; mkdir -p $W/g
	svn export -q --ignore-keywords "$R/$p@$rev" $W/s && find $W/s -type d -empty -delete; mkdir -p $W/s
	git -C $repo archive "$ref" | tar -x -C $W/g
	if diff -rq $W/s $W/g >/dev/null; then r=OK; else r=DIFFERS; fi
	echo "$name $ref: $r vs $p@$rev"
done
