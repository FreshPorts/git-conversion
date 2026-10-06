#!/bin/sh
# Create a private repository in the FreshPorts GitHub organization for each
# converted repository, and push every branch and tag to it.
#   usage: push-to-github.sh [local-name ...]	(default: all of them)
# Stops if a GitHub repository of that name already exists, or if the local
# repository already has an origin, rather than push into the wrong place.
set -eu
PATH=/opt/homebrew/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
ORG=FreshPorts

# local name | GitHub name | description
MAP='
daemon-freshports|daemon-freshports|The freshports daemon (freshports-freshports package), split from daemontools
daemon-ingress|daemon-ingress|The ingress daemon (freshports-ingress package), split from daemontools
fp-listen|fp-listen|fp-listen (py-freshports-fp-listen package), split from daemontools
daemontools|daemontools|FreshPorts services fp-daemon and ingress_svn, converted from Subversion
database-schema|database-schema|The FreshPorts database schema, converted from Subversion
ingress-modules|ingress-modules|FreshPorts ingress Perl modules, converted from Subversion
ingress-scripts|ingress-scripts|FreshPorts ingress scripts, converted from Subversion
ingress-verify|ingress-verify|FreshPorts database verification scripts, converted from Subversion
freshports-archive|freshports-archive|Dormant FreshPorts projects, converted from Subversion
packaging-for-svn|packaging-for-svn|FreshPorts packaging as in Subversion, with the cut-* scripts
'

want=${*:-}
echo "$MAP" | while IFS='|' read -r local name desc; do
	[ -n "$local" ] || continue
	if [ -n "$want" ]; then
		case " $want " in *" $local "*) ;; *) continue ;; esac
	fi
	repo=$HERE/repos/$local
	echo "== $local -> $ORG/$name"
	if gh api "repos/$ORG/$name" -q .full_name 2>/dev/null | grep -qx "$ORG/$name"; then
		echo "$ORG/$name already exists; skipping" >&2
		continue
	fi
	if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
		echo "$local already has an origin; skipping" >&2
		continue
	fi
	gh repo create "$ORG/$name" --private --description "$desc"
	git -C "$repo" remote add origin "git@github.com:$ORG/$name.git"
	git -C "$repo" push -q -u origin main		# first, so it becomes the default
	git -C "$repo" push -q origin --all
	git -C "$repo" push -q origin --tags
	gh repo edit "$ORG/$name" --default-branch main
	echo "   $(git -C "$repo" branch | wc -l | tr -d ' ') branches, $(git -C "$repo" tag | wc -l | tr -d ' ') tags pushed"
done
