#!/bin/sh
# Rebuild every repo in repos/ from ~/src/freshports/freshports-1, in order.
# scripts.ARCHIVE alone takes well over an hour.
set -eu
cd "$(dirname "$0")"
mkdir -p logs
xargs -P 8 -n 2 ./convert.sh < projects.txt
# scripts.ARCHIVE tags carry the r5068 rename as their annotation; use the
# creating revision instead.
./fix-tag-annotations.py --apply scripts.ARCHIVE:scripts.ARCHIVE/tags:
# Point tags hit by an accidental second `svn cp trunk tags/X` back at the
# commit that created them.
specs="scripts.ARCHIVE:scripts.ARCHIVE/tags:"
while read -r p n; do specs="$specs $n:$p/tags:"; done < projects.txt
./retarget-tags.py --apply $specs
./combine-archive.sh
./graft-ingress.sh		# copies the fixed scripts.ARCHIVE tags in as pre-split/*
# Compare every branch and tag with SVN before anything adds commits of its own.
xargs -P 8 -n 2 ./verify.sh < verify-projects.txt > logs/verify.log 2>&1
if grep -v '^  ' logs/verify.log | grep -vE ': [0-9]+ ok, 0 differ'; then
	echo "verify: refs differ from SVN; see logs/verify.log" >&2
	exit 1
fi
echo "verify: all refs match SVN"
./add-readmes.sh		# README.md for each conversion
rm -rf repos/.pre-split	# split from the freshly converted daemontools
./split-daemontools.sh	# freshports, ingress, fp-listen -> daemon-*, fp-listen
./verify-split.py "$PWD" | tee logs/verify-split.log
