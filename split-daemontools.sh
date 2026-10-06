#!/bin/sh
# Split freshports/, ingress/ and fp-listen/ out of repos/daemontools into
# repos/daemon-freshports, repos/daemon-ingress and repos/fp-listen.
# Each is built and distributed as a separate FreeBSD package.
#
# Each new repository follows its directory through its earlier names, by SVN
# revision (from each commit's git-svn-id), and has its own tags. daemontools
# keeps fp-daemon/ and ingress_svn/; its history is not rewritten, because
# both descend from the same trunk/freshports -> trunk/fp-daemon line. One
# commit removes the moved directories, and their tags are deleted there.
# The READMEs come from readmes/<repo>/README.
#
# Run after graft-ingress.sh. The unsplit daemontools is kept in
# repos/.pre-split/daemontools; a rerun starts again from that copy.
set -eu
PATH=/opt/homebrew/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
REPOS=$HERE/repos
SRC=$REPOS/.pre-split/daemontools

if [ ! -d "$SRC" ]; then
	mkdir -p "$REPOS/.pre-split"
	cp -Rp "$REPOS/daemontools" "$SRC"
fi
rm -rf "$REPOS/daemontools"
cp -Rp "$SRC" "$REPOS/daemontools"

python3 - "$HERE" <<'PY'
import os, re, subprocess, sys, xml.etree.ElementTree as ET

HERE = sys.argv[1]
REPOS = os.path.join(HERE, 'repos')
SRC = os.path.join(REPOS, '.pre-split', 'daemontools')
SVNREPO = 'file://' + os.path.expanduser('~/src/freshports/freshports-1')
AUTHOR = {'GIT_AUTHOR_NAME': 'Dan Langille', 'GIT_AUTHOR_EMAIL': 'dan@langille.org',
          'GIT_COMMITTER_NAME': 'Dan Langille', 'GIT_COMMITTER_EMAIL': 'dan@langille.org'}
TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
INF = 10**9

# Which directory holds the package at a given SVN revision.
def freshports_dir(rev):
    if rev < 5050: return 'freshports'		# trunk/freshports
    if rev < 5388: return 'fp-daemon'		# trunk, then branches/git (r5376)
    if rev < 5416: return 'fp-freshports'
    return 'freshports'

def ingress_dir(rev):
    if rev < 5050: return 'freshports'
    if rev < 5386: return 'fp-daemon'
    if rev < 5417: return 'fp-ingress'
    return 'ingress'

def tag_freshports(t):
    m = re.fullmatch(r'(?:fp-freshports|freshports)-(2\.0\.\d+)', t)
    return m and m.group(1)

def tag_ingress(t):
    m = re.fullmatch(r'(?:fp-ingress|ingress)-(2\.0\.\d+)', t)
    return m and m.group(1)

def tag_fp_listen(t):
    m = re.fullmatch(r'fp-listen-(2\.\d+\.\d+)', t)
    if m:
        return m.group(1)				# current line: plain version
    if re.fullmatch(r'fp-listen-(git-)?1\.\d+\.\d+', t):
        return t					# older lines keep their names
    return None

PACKAGES = [
    # name, dir for rev, branches (new: old), tag mapping, expected tag count
    ('daemon-freshports', freshports_dir,
     {'main': 'main', 'FreshPorts2': 'FreshPorts2'}, tag_freshports, 17),
    ('daemon-ingress', ingress_dir,
     {'main': 'main'}, tag_ingress, 5),
    ('fp-listen', lambda rev: 'fp-listen',
     {'main': 'main', 'trunk': 'trunk'}, tag_fp_listen, 34),
]
# Where each SVN source path's commits are: branches/git -> main, trunk -> trunk
SVN_BRANCH = [('daemontools/branches/git/', 'main'), ('daemontools/trunk/', 'trunk')]


def git(repo, *args, input=None, env=None):
    e = dict(os.environ, **(env or {}))
    # surrogateescape passes any non-UTF-8 bytes (old CVS messages) through
    r = subprocess.run(['git', '-C', repo, *args], capture_output=True, input=input, env=e,
                       encoding='utf-8', errors='surrogateescape')
    if r.returncode:
        sys.exit(f'git {" ".join(args)} failed in {repo}:\n{r.stderr}')
    return r.stdout.rstrip('\n')

def svn_rev(repo, commit):
    m = re.search(r'^git-svn-id: \S+@(\d+) ', git(repo, 'log', '-1', '--format=%B', commit), re.M)
    return int(m.group(1)) if m else INF

def tree_of(repo, ref, path=None):
    spec = f'{ref}:{path}' if path else f'{ref}^{{tree}}'
    r = subprocess.run(['git', '-C', repo, 'rev-parse', '-q', '--verify', spec],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None

def svn_copyfrom(path, rev):
    """(path, rev) the SVN directory path was copied from when created at rev,
    following copies of copies (a tag renamed from another tag)."""
    xml = subprocess.run(['svn', 'log', '--xml', '-v', '-r', str(rev), SVNREPO],
                         check=True, capture_output=True, text=True).stdout
    for p in ET.fromstring(xml).iter('path'):
        if p.text == '/' + path and p.get('copyfrom-path'):
            src, srev = p.get('copyfrom-path').lstrip('/'), int(p.get('copyfrom-rev'))
            if src.startswith('daemontools/tags/'):
                # find when that tag was created, and where it came from
                xml = subprocess.run(['svn', 'log', '--xml', '-v', '--stop-on-copy',
                                      '-r', f'1:{srev}', f'{SVNREPO}/{src}@{srev}'],
                                     check=True, capture_output=True, text=True).stdout
                first = next(ET.fromstring(xml).iter('logentry'))
                return svn_copyfrom(src, int(first.get('revision')))
            return src, srev
    sys.exit(f'no copy source found for {path}@{rev}')


tagmap_all = {}		# old daemontools tag -> (package, new tag)
for name, dir_for, branches, tagname, expected in PACKAGES:
    print(f'== {name}')
    dest = os.path.join(REPOS, name)
    subprocess.run(['rm', '-rf', dest], check=True)
    subprocess.run(['git', 'clone', '-q', '--no-local', '--no-checkout', SRC, dest], check=True)

    # Rebuild each commit with the package directory as its tree. Commits
    # that do not change it are dropped (mapped to their new parent).
    new_of = {}		# old commit -> new commit (or None before the dir exists)
    rev_of = {}		# new commit -> SVN revision
    heads = {}
    for newb, oldb in branches.items():
        lines = git(dest, 'rev-list', '--reverse', '--topo-order', '--parents',
                    f'refs/remotes/origin/{oldb}').splitlines()
        for line in lines:
            c, *parents = line.split()
            if c in new_of:
                continue
            nparents = []
            for p in parents:
                if new_of.get(p) and new_of[p] not in nparents:
                    nparents.append(new_of[p])
            rev = svn_rev(dest, c)
            t = tree_of(dest, c, dir_for(rev))
            if t is None or (nparents and t == tree_of(dest, nparents[0])):
                new_of[c] = nparents[0] if nparents else None
                continue
            raw = git(dest, 'cat-file', 'commit', c)
            header, _, message = raw.partition('\n\n')
            kept = [l for l in header.split('\n') if not l.startswith(('tree ', 'parent '))]
            obj = '\n'.join([f'tree {t}'] + [f'parent {p}' for p in nparents] + kept) \
                  + '\n\n' + message + '\n'
            n = git(dest, 'hash-object', '-t', 'commit', '-w', '--stdin', input=obj)
            new_of[c] = n
            rev_of[n] = rev
        heads[newb] = new_of[lines[-1].split()[0]]

    # Tags: the package's own, on the commit for the revision each was
    # copied from; tagger, date and message are kept as they were.
    old_tags = git(dest, 'for-each-ref', '--format=%(refname:short)', 'refs/tags').split()
    made = 0
    for old in old_tags:
        new = tagname(old)
        if not new:
            continue
        msg = git(dest, 'for-each-ref', '--format=%(contents)', f'refs/tags/{old}')
        m = re.search(r'git-svn-id: \S+/freshports-1/(\S+)@(\d+) ', msg)
        src, srev = svn_copyfrom(m.group(1), int(m.group(2)))
        branch = next(b for prefix, b in SVN_BRANCH if src.startswith(prefix))
        if branch not in heads:
            sys.exit(f'{name}: tag {old} comes from {src}, which is not converted')
        candidates = git(dest, 'rev-list', heads[branch]).split()
        target = next(c for c in candidates if rev_of.get(c, INF) <= srev)
        want = tree_of(dest, f'{old}^{{}}')
        if tree_of(dest, target) != want:
            sys.exit(f'{name}: tag {old} -> {new}: tree of {target} (r{rev_of[target]}) '
                     f'differs from the daemontools tag; stopping')
        raw = git(dest, 'cat-file', 'tag', old)
        body = raw.partition('\n\n')[2]
        tagger = re.search(r'^tagger .*$', raw, re.M).group(0)
        obj = f'object {target}\ntype commit\ntag {new}\n{tagger}\n\n{body}\n'
        t = git(dest, 'mktag', input=obj)
        git(dest, 'update-ref', f'refs/new-tags/{new}', t)
        tagmap_all[old] = (name, new)
        made += 1
        print(f'   tag {old:28} -> {new:22} r{rev_of[target]} from {src}@{srev}')
    if made != expected:
        sys.exit(f'{name}: made {made} tags, expected {expected}')

    # Replace every ref with the new branches and tags. Removing the remote
    # first also removes its HEAD, which would otherwise be left dangling.
    git(dest, 'remote', 'remove', 'origin')
    for ref in git(dest, 'for-each-ref', '--format=%(refname)').split():
        if not ref.startswith('refs/new-tags/'):
            git(dest, 'update-ref', '--no-deref', '-d', ref)
    for b, c in heads.items():
        git(dest, 'update-ref', f'refs/heads/{b}', c)
    for ref in git(dest, 'for-each-ref', '--format=%(refname)', 'refs/new-tags').split():
        git(dest, 'update-ref', 'refs/tags/' + ref[len('refs/new-tags/'):], ref)
        git(dest, 'update-ref', '-d', ref)
    git(dest, 'symbolic-ref', 'HEAD', 'refs/heads/main')

    # Each branch must end with the same contents as daemontools' branch did.
    for newb, oldb in branches.items():
        last_rev = svn_rev(SRC, oldb)
        if tree_of(dest, heads[newb]) != tree_of(SRC, oldb, dir_for(last_rev)):
            sys.exit(f'{name}: {newb} does not match daemontools {oldb}:{dir_for(last_rev)}')

    # README
    readme = os.path.join(HERE, 'readmes', name, 'README')
    git(dest, 'read-tree', 'main')
    blob = git(dest, 'hash-object', '-w', readme)
    git(dest, 'update-index', '--add', '--cacheinfo', f'100644,{blob},README')
    tree = git(dest, 'write-tree')
    c = git(dest, 'commit-tree', tree, '-p', 'main', '-m',
            'Add README describing the split from daemontools', '-m', TRAILER, env=AUTHOR)
    git(dest, 'update-ref', 'refs/heads/main', c)
    git(dest, 'reset', '-q', '--hard', 'main')
    git(dest, 'reflog', 'expire', '--expire=now', '--all')
    git(dest, 'gc', '-q', '--prune=now')
    print(f'   {name}: ' + ', '.join(f'{b} {git(dest, "rev-list", "--count", b)} commits'
                                     for b in branches) + f', {made} tags')

# daemontools: delete the moved tags, remove the moved directories, add README.
dt = os.path.join(REPOS, 'daemontools')
print('== daemontools')
for old in tagmap_all:
    git(dt, 'tag', '-d', old)
git(dt, 'checkout', '-q', 'main')
git(dt, 'rm', '-r', '-q', 'freshports', 'ingress', 'fp-listen')
subprocess.run(['cp', os.path.join(HERE, 'readmes', 'daemontools', 'README'), dt], check=True)
git(dt, 'add', 'README')
git(dt, 'commit', '-q', '-m', 'Move freshports, ingress and fp-listen to their own repositories',
    '-m', 'They are now FreshPorts/daemon-freshports, daemon-ingress and fp-listen;\n'
          'see README.', '-m', TRAILER, env=AUTHOR)
left = git(dt, 'tag').split()
if len(tagmap_all) != 56 or len(left) != 22:
    sys.exit(f'daemontools: {len(tagmap_all)} tags moved, {len(left)} left; expected 56 and 22')
git(dt, 'gc', '-q', '--prune=now')
print(f'   daemontools: {len(tagmap_all)} tags moved, {len(left)} kept; main now has '
      + ' '.join(sorted(os.listdir(dt))))
PY
