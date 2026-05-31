const cp = require('child_process');
const exec = (cmd) => {
    console.log('RUNNING:', cmd);
    const res = cp.execSync(cmd, { encoding: 'utf8', stdio: 'pipe' });
    console.log(res);
    return res;
};

try {
    const branch = exec('git rev-parse --abbrev-ref HEAD').trim();
    if (branch !== 'feat/ai-face-auth') {
        throw new Error('Not on feat/ai-face-auth');
    }

    exec('git reset --hard e811b46');

    // 56a2080
    exec('git cherry-pick 56a2080');
    exec('git commit --amend -m "chore(face-auth): drop scratch files"');

    // 5fc42c9
    exec('git cherry-pick 5fc42c9');
    exec('git commit --amend -m "fix(face-auth): resolve web build regressions"');

    // d8726c9
    exec('git cherry-pick d8726c9');
    exec('git commit --amend -m "fix(face-auth): secure auth bypass and improve ux"');

    // 37bc14a
    exec('git cherry-pick 37bc14a');
    exec('git commit --amend -m "fix(face-auth): patch critical vulnerabilities"');

    // d6867ad
    exec('git cherry-pick d6867ad');
    exec('git commit --amend -m "feat(face-auth): add rate limit and brute protect"');

    // 2ba90cc
    exec('git cherry-pick 2ba90cc');
    exec('git commit --amend -m "fix(face-auth): stabilize json parse and login"');

    // 6f4bc60
    exec('git cherry-pick 6f4bc60');
    exec('git commit --amend -m "fix(face-auth): fix web race condition and ux"');

    // ef388de
    exec('git cherry-pick ef388de');
    exec('git commit --amend -m "fix(face-auth): fix error code and memory leak"');

    // ff52976
    exec('git cherry-pick ff52976');
    exec('git commit --amend -m "fix(face-auth): remove redundant liveness check"');

    // 8546af0
    exec('git cherry-pick 8546af0');
    exec('git commit --amend -m "fix(face-auth): add request timeout"');

    // ac40c08
    exec('git cherry-pick ac40c08');
    exec('git commit --amend -m "chore(face-auth): fix round 4 audit issues"');

    // 13e003a
    exec('git cherry-pick 13e003a');
    exec('git commit --amend -m "fix(ai-backend): stabilize health checks"');

    // eebc35b
    exec('git cherry-pick eebc35b');
    exec('git commit --amend -m "chore(face-auth): apply round 5 fixes"');

    // d816f94
    exec('git cherry-pick d816f94');
    exec('git commit --amend -m "fix(face-auth): move beta badge to login button"');

    // 24aa43d
    exec('git cherry-pick 24aa43d');
    exec('git commit --amend -m "fix(face-auth): add missing ui navigation"');

    exec('git push -f origin feat/ai-face-auth');
    
    console.log('SUCCESS');
} catch(e) {
    console.error('ERROR:', e.message);
    if (e.stdout) console.log('STDOUT:', e.stdout);
    if (e.stderr) console.log('STDERR:', e.stderr);
}
