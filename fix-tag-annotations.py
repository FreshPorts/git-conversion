#!/usr/bin/env python3
"""Rewrite annotated tags so their tagger, date and message come from the SVN
revision that created the tag.

git-svn adds a commit to a tag's line whenever the tag directory changes, for
example when a parent directory is renamed (r5068 /scripts -> /scripts.ARCHIVE).
convert.sh takes the tag annotation from the newest commit on that line, so such
a rename overwrites the original tagger and date. The tag targets are correct;
only the annotations are fixed here.

usage: fix-tag-annotations.py [--apply] repo:svn-tags-dir:prefix ...
  e.g. scripts.ARCHIVE:scripts.ARCHIVE/tags:  ingress-scripts:scripts.ARCHIVE/tags:pre-split/
Without --apply it only reports what would change.
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
                          text=True, env=env, input=input).stdout

def creation(tagdir):
    """Newest revision in which a directory named like tagdir's tag was added."""
    name = tagdir.rsplit('/', 1)[1]
    xml = subprocess.run([SVN, 'log', '--xml', '-v', SVNREPO + '/' + tagdir],
                         check=True, capture_output=True, text=True).stdout
    for e in ET.fromstring(xml).iter('logentry'):	# newest first
        for p in e.iter('path'):
            if p.get('action') in ('A', 'R') and p.text.endswith('/tags/' + name):
                return (int(e.get('revision')), p.text.lstrip('/'),
                        (e.findtext('author') or '(no author)'),
                        e.findtext('date'), e.findtext('msg') or '')
    return None

apply = '--apply' in sys.argv
for spec in [a for a in sys.argv[1:] if a != '--apply']:
    repo, tagsdir, prefix = spec.split(':')
    rpath = os.path.join(HERE, 'repos', repo)
    changed = same = 0
    refs = git(rpath, 'for-each-ref', '--format=%(refname:short)%09%(taggerdate:iso-strict)',
               'refs/tags/' + prefix if prefix else 'refs/tags').splitlines()
    for line in refs:
        tag, tdate = line.split('\t')
        svnname = tag[len(prefix):]
        # attic/ refs have no live SVN tag; with no prefix, a slash means a
        # tag brought in from elsewhere (pre-split/...)
        if svnname.startswith('attic/') or (not prefix and '/' in svnname):
            continue
        svnname = {'cvs-head': 'head'}.get(svnname, svnname)
        svnname = svnname[len('svn-tag-'):] if svnname.startswith('svn-tag-') else svnname
        c = creation(tagsdir + '/' + svnname)
        if c is None:
            print(f'{repo}: {tag}: no SVN creation found, left alone')
            continue
        rev, path, author, date, msg = c
        name, email = authors[author]
        date = date[:19] + '+00:00'
        if tdate.replace('Z', '+00:00')[:19] == date[:19]:
            same += 1
            continue
        changed += 1
        print(f'{repo}: {tag}: {tdate} -> r{rev} {date} {author}: {msg.splitlines()[0] if msg else ""}')
        if apply:
            target = git(rpath, 'rev-parse', tag + '^{}').strip()
            env = dict(os.environ, GIT_COMMITTER_NAME=name, GIT_COMMITTER_EMAIL=email,
                       GIT_COMMITTER_DATE=date)
            body = msg.rstrip('\n') + f'\n\ngit-svn-id: {ROOT}/{path}@{rev} {UUID}\n'
            git(rpath, 'tag', '-f', '-a', '-F', '-', tag, target, env=env, input=body)
    print(f'{repo}: {changed} tags {"rewritten" if apply else "would change"}, {same} already right')
