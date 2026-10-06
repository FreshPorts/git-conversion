#!/bin/sh
# Commit readmes/<repo>/README.md into repos/<repo>, describing each
# conversion. Run after verify.sh (which compares trees with SVN, so must not
# see the README) and before split-daemontools.sh (so daemontools keeps its
# README.md through the split). freshports-archive gets its README from
# combine-archive.sh; the split repositories get theirs from
# split-daemontools.sh.
set -eu
PATH=/opt/homebrew/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
export GIT_AUTHOR_NAME="Dan Langille" GIT_AUTHOR_EMAIL=dan@langille.org
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

for readme in "$HERE"/readmes/*/README.md; do
	name=$(basename "$(dirname "$readme")")
	repo=$HERE/repos/$name
	cp "$readme" "$repo/README.md"
	git -C "$repo" add README.md
	git -C "$repo" commit -q -m "Add README describing the conversion from Subversion" \
		-m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
	echo "$name: README.md committed"
done
