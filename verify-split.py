#!/usr/bin/env python3
"""Check every commit and tag of the repos made by split-daemontools.sh
against an svn export of the path and revision in its git-svn-id.
usage: verify-split.py <git-conversion dir>"""
import os, re, subprocess, sys, tempfile, filecmp
D = sys.argv[1]
SVN = 'file://' + os.path.expanduser('~/src/freshports/freshports-1')
def git(r, *a): return subprocess.run(['git','-C',r,*a],capture_output=True,text=True,errors='surrogateescape',check=True).stdout.strip()
def dircmp_equal(a, b):
    c = filecmp.dircmp(a, b, ignore=['.git'])
    def walk(c):
        if c.left_only or c.right_only or c.diff_files or c.funny_files: return False
        # filecmp shallow compare -> do deep
        for f in c.common_files:
            if not filecmp.cmp(os.path.join(c.left,f), os.path.join(c.right,f), shallow=False): return False
        return all(walk(s) for s in c.subdirs.values())
    return walk(c)
def compare(repo, ref, svnpath, rev, tmp):
    s, g = os.path.join(tmp,'s'), os.path.join(tmp,'g')
    subprocess.run(['rm','-rf',s,g]); os.makedirs(g)
    subprocess.run(['svn','export','-q','--ignore-keywords',f'{SVN}/{svnpath}@{rev}',s],check=True)
    subprocess.run(['find',s,'-type','d','-empty','-delete']); os.makedirs(s, exist_ok=True)
    a = subprocess.run(['git','-C',repo,'archive',ref],capture_output=True,check=True).stdout
    subprocess.run(['tar','-x','-C',g],input=a,check=True)
    if os.path.exists(os.path.join(g,'README')) and not os.path.exists(os.path.join(s,'README')): os.remove(os.path.join(g,'README'))
    return dircmp_equal(s, g)
dirs = {'daemon-freshports': lambda r: 'freshports' if r<5050 else 'fp-daemon' if r<5388 else 'fp-freshports' if r<5416 else 'freshports',
        'daemon-ingress':    lambda r: 'freshports' if r<5050 else 'fp-daemon' if r<5386 else 'fp-ingress' if r<5417 else 'ingress',
        'fp-listen':         lambda r: 'fp-listen'}
with tempfile.TemporaryDirectory() as tmp:
    for name, dir_for in dirs.items():
        repo = os.path.join(D,'repos',name); ok=bad=0
        for c in git(repo,'rev-list','--all').split():
            msg = git(repo,'log','-1','--format=%B',c)
            m = re.search(r'git-svn-id: \S+/freshports-1/(\S+)@(\d+) ', msg)
            if not m: continue          # README commit
            base, rev = m.group(1), int(m.group(2))
            if not compare(repo, c, f'{base}/{dir_for(rev)}', rev, tmp):
                bad += 1; print(f'  {name}: commit {c[:8]} r{rev} differs from {base}/{dir_for(rev)}@{rev}')
            else: ok += 1
        tok=tbad=0
        for t in git(repo,'tag').split():
            msg = git(repo,'for-each-ref','--format=%(contents)',f'refs/tags/{t}')
            m = re.search(r'git-svn-id: \S+/freshports-1/(\S+)@(\d+) ', msg)
            if compare(repo, t, m.group(1), int(m.group(2)), tmp): tok += 1
            else: tbad += 1; print(f'  {name}: tag {t} differs from {m.group(1)}@{m.group(2)}')
        print(f'{name}: {ok} commits match SVN, {bad} differ; {tok} tags match SVN, {tbad} differ')
