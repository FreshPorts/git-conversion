#!/usr/bin/env python3
"""Point tags at the commit that created them in SVN.

An SVN tag is a copy; git-svn records it as a commit on a line of its own, and
adds a further commit there each time the tag directory changes afterwards.
Mostly that change is an accidental second `svn cp trunk tags/X`, which nests a
copy (tags/X/trunk/) inside the tag. convert.sh tags the newest commit on that
line, so such tags contain the nested copy and carry the date and message of
the mistake.

For each tag this finds, from SVN, the revision that created the tag
directory, walks back from the tag to the commit at or before that revision,
and tags it, annotated from that SVN revision. Tags SVN never changed after
creating them are left alone.

usage: retarget-tags.py [--apply] repo:svn-tags-dir:prefix ...
Without --apply it reports each tag that would move and what SVN changed in it
after creating it.
"""
import os, re, subprocess, sys, xml.etree.ElementTree as ET

GIT = '/opt/homebrew/bin/git'
SVN = '/opt/homebrew/bin/svn'
HERE = os.path.dirname(os.path.abspath(__file__))
SVNREPO = 'file://' + os.path.expanduser('~/src/freshports/freshports-1')
ROOT = 'svn+ssh://svn.int.unixathome.org/freshports-1'
UUID = '46e82423-29d8-e211-989e-002590a4cdd4'

authors = {}
for line in open(os.path.join(HERE, 'authors.txt')):
    m = re.match(r'(.*?) = (.*) <(.*)>$', line.strip())
    if m:
        authors[m.group(1)] = (m.group(2), m.group(3))

def git(repo, *args, env=None, input=None):
    return subprocess.run([GIT, '-C', repo, *args], check=True, capture_output=True,
                          text=True, env=env, input=input).stdout.strip()

def svnlog(target, *args):
    xml = subprocess.run([SVN, 'log', '--xml', '-v', *args, SVNREPO + '/' + target],
                         check=True, capture_output=True, text=True).stdout
    return list(ET.fromstring(xml).iter('logentry'))

def creation(tagdir):
    """(rev, path, author, date, msg) of the newest add of the tag directory."""
    name = tagdir.rsplit('/', 1)[1]
    for e in svnlog(tagdir):			# newest first
        for p in e.iter('path'):
            if p.get('action') in ('A', 'R') and p.text.endswith('/tags/' + name):
                return (int(e.get('revision')), p.text.lstrip('/'),
                        e.findtext('author') or '(no author)', e.findtext('date'),
                        e.findtext('msg') or '')

def later_changes(tagdir, rev):
    out = []
    for e in svnlog(tagdir, '-r', f'{rev + 1}:HEAD'):
        for p in e.iter('path'):
            if p.text.lstrip('/').startswith(tagdir):
                out.append(f'r{e.get("revision")} {p.get("action")} {p.text}')
    return out

def svn_rev(repo, commit):
    m = re.search(r'git-svn-id: \S+@(\d+) ', git(repo, 'log', '-1', '--format=%B', commit))
    return int(m.group(1)) if m else None

apply = '--apply' in sys.argv
for spec in [a for a in sys.argv[1:] if a != '--apply']:
    repo, tagsdir, prefix = spec.split(':')
    r = os.path.join(HERE, 'repos', repo)
    moved = 0
    for tag in git(r, 'for-each-ref', '--format=%(refname:short)', 'refs/tags/' + prefix if prefix else 'refs/tags').split():
        svnname = tag[len(prefix):]
        if svnname.startswith('attic/') or (not prefix and '/' in svnname):
            continue
        svnname = {'cvs-head': 'head'}.get(svnname, svnname)
        svnname = svnname[len('svn-tag-'):] if svnname.startswith('svn-tag-') else svnname
        tagdir = tagsdir + '/' + svnname
        c = creation(tagdir)
        if c is None:
            print(f'{repo}: {tag}: no SVN creation found, left alone')
            continue
        rev, path, author, date, msg = c
        tip = git(r, 'rev-parse', tag + '^{}')
        if (svn_rev(r, tip) or 0) <= rev:
            continue			# never changed after creation
        target = None
        for commit in git(r, 'rev-list', '--first-parent', tip).split():
            sr = svn_rev(r, commit)
            if sr is not None and sr <= rev:
                target = commit
                break
        # a tag made by a pure copy has its source's tree: tag the source
        p = git(r, 'rev-list', '--parents', '-n1', target).split()[1:]
        if p and git(r, 'rev-parse', target + '^{tree}') == git(r, 'rev-parse', p[0] + '^{tree}'):
            target = p[0]
        same = git(r, 'rev-parse', tip + '^{tree}') == git(r, 'rev-parse', target + '^{tree}')
        moved += 1
        print(f'{repo}: {tag}: created r{rev} {date[:10]}; tag now at r{svn_rev(r, tip)}; '
              f'content {"unchanged" if same else "changes"}')
        for ch in later_changes(tagdir, rev):
            print(f'      {ch}')
        if apply:
            name, email = authors[author]
            env = dict(os.environ, GIT_COMMITTER_NAME=name, GIT_COMMITTER_EMAIL=email,
                       GIT_COMMITTER_DATE=date[:19] + '+00:00')
            body = msg.rstrip('\n') + f'\n\ngit-svn-id: {ROOT}/{path}@{rev} {UUID}\n'
            git(r, 'tag', '-f', '-a', '-F', '-', tag, target, env=env, input=body)
    print(f'{repo}: {moved} tags {"retargeted" if apply else "would move"}')
