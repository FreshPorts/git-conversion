#!/bin/sh
# Combine the dormant project repos into repos/freshports-archive, each in its
# own subdirectory, with branches and tags prefixed by the project name.
# The source repos in repos/ are left untouched.
set -eu
PATH=/opt/homebrew/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=$HERE/repos/freshports-archive
WORK=${TMPDIR:-/tmp}/fp-archive
# Oldest first, so main's first parent line starts with the oldest project.
PROJECTS="walkports scripts-fp2 convert db-conversion ports secure develop dataconversion backend api.freshports.org"

export GIT_AUTHOR_NAME="Dan Langille" GIT_AUTHOR_EMAIL=dan@langille.org
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

rm -rf "$DEST" "$WORK"
mkdir -p "$WORK"
git init -q -b main "$DEST"

for p in $PROJECTS; do
	git clone -q --no-local "$HERE/repos/$p" "$WORK/$p"
	# clone only makes main a local branch; recreate the others
	git -C "$WORK/$p" for-each-ref --format='%(refname:short)' refs/remotes/origin |
		grep -v -e '^origin$' -e '^origin/HEAD$' -e '^origin/main$' |
		while read -r b; do git -C "$WORK/$p" branch -q "${b#origin/}" "$b"; done
	git -C "$WORK/$p" remote remove origin
	git -C "$WORK/$p" filter-repo --quiet --force \
		--to-subdirectory-filter "$p" --tag-rename ":$p/"
	git -C "$DEST" fetch -q --no-tags "$WORK/$p" \
		"+refs/heads/*:refs/heads/$p/*" "+refs/tags/*:refs/tags/*"
	if ! git -C "$DEST" rev-parse -q --verify refs/heads/main >/dev/null; then
		git -C "$DEST" update-ref refs/heads/main "refs/heads/$p/main"
		git -C "$DEST" checkout -q main
	else
		git -C "$DEST" merge -q --no-edit --allow-unrelated-histories \
			-m "Import $p, converted from Subversion freshports-1/$p" "$p/main"
	fi
	git -C "$DEST" branch -q -D "$p/main"
done

cat > "$DEST/README.md" <<'MD'
# freshports-archive

Dormant FreshPorts projects, converted from the `freshports-1` Subversion
repository with their full history. Each project lives in its own directory;
its SVN branches and tags are prefixed with the project name (for example
`secure/FreshPorts2`, `walkports/release1_1`).

Every converted commit keeps its `git-svn-id:` trailer, giving the original
Subversion path and revision.

| Directory | Active |
|---|---|
MD
for p in $PROJECTS; do
	echo "| \`$p\` | $(git -C "$DEST" log --reverse --format=%as -- "$p" | head -1) – $(git -C "$DEST" log -1 --format=%as -- "$p") |" >> "$DEST/README.md"
done
git -C "$DEST" add README.md
git -C "$DEST" commit -q -m "Add README describing the archived projects"
git -C "$DEST" gc -q --prune=now
rm -rf "$WORK"
echo "freshports-archive: done"
