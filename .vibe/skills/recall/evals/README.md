# Recall GitHub Auto-Discovery - Test Cases

This directory contains test cases for validating the GitHub auto-discovery feature added in v1.2.0.

## Test Scenarios

### Test 1: Auto-Discovery (Default Behavior)
**Objective**: Verify that recall automatically discovers repos with recent activity

**Command**:
```bash
cd /home/b08x/Workspace/Syncopated/Context/skills/recall
PYTHONPATH=. python3 scripts/recall_workflow.py --days 7
```

**Expected Behavior**:
1. Should detect authenticated `gh` CLI user
2. Should run `gh search commits --author=<user> --author-date=>=<date>`
3. Should display: "Auto-discovered N repos with activity"
4. Should list each discovered repo (e.g., "• b08x/omega-13")
5. Should fetch commits from all discovered repos
6. Should include commits in the unified timeline with repo names

**Success Criteria**:
- ✅ Output shows "Auto-discovering GitHub repos with activity"
- ✅ Lists at least 1 discovered repo
- ✅ Timeline includes GitHub commits with `"platform": "github"`
- ✅ Each commit includes `"repo": "owner/name"` field

---

### Test 2: Manual Repo Specification (Backward Compatibility)
**Objective**: Verify that manual repo specification still works (no auto-discovery)

**Command**:
```bash
cd /home/b08x/Workspace/Syncopated/Context/skills/recall
PYTHONPATH=. python3 scripts/recall_workflow.py --days 3 --github-repo b08x/omega-13
```

**Expected Behavior**:
1. Should NOT trigger auto-discovery
2. Should show: "GitHub repo: b08x/omega-13"
3. Should fetch commits ONLY from b08x/omega-13
4. Should behave exactly like pre-v1.2.0 version

**Success Criteria**:
- ✅ Output shows "GitHub repo: b08x/omega-13" (not auto-discovery message)
- ✅ No `gh search commits` command executed
- ✅ Only commits from specified repo in timeline
- ✅ Backward compatible with old behavior

---

### Test 3: Skip GitHub Entirely (--no-github)
**Objective**: Verify that GitHub can be completely skipped

**Command**:
```bash
cd /home/b08x/Workspace/Syncopated/Context/skills/recall
PYTHONPATH=. python3 scripts/recall_workflow.py --days 14 --no-github
```

**Expected Behavior**:
1. Should NOT trigger auto-discovery
2. Should NOT fetch from any GitHub repos
3. Should show: "GitHub: Skipped"
4. Should include local sessions and local git only

**Success Criteria**:
- ✅ Output shows "GitHub: Skipped"
- ✅ No `gh` commands executed at all
- ✅ Timeline includes local sessions (Claude Code, Gemini, etc.)
- ✅ Timeline includes local git commits (from workspace)
- ✅ Timeline does NOT include GitHub API commits

---

## Manual Testing Checklist

### Prerequisites
- [ ] `gh` CLI is installed and authenticated (`gh auth status`)
- [ ] Have at least one GitHub repo with commits in last 7 days
- [ ] Recall skill dependencies are installed

### Test Execution
- [ ] Test 1: Auto-discovery with `--days 7`
- [ ] Test 2: Manual repo with `--github-repo owner/repo`
- [ ] Test 3: Skip GitHub with `--no-github`
- [ ] Test 4: Verify error handling when `gh` CLI not authenticated
- [ ] Test 5: Verify behavior when no repos have activity (empty result)

### Regression Testing
- [ ] Verify existing `--github-repo` behavior unchanged
- [ ] Verify local git correlation still works
- [ ] Verify Obsidian notes correlation still works
- [ ] Verify DSPy synthesis still works
- [ ] Verify "One Thing" generation still works

---

## Automated Testing (Future)

To run automated tests once implemented:

```bash
cd /home/b08x/Workspace/Syncopated/Context/skills/recall
pytest tests/test_github_autodiscovery.py -v
```

---

## Debugging

If auto-discovery fails:

1. **Check `gh` CLI authentication**:
   ```bash
   gh auth status
   ```

2. **Test search manually**:
   ```bash
   gh search commits --author=$(gh api user --jq .login) --author-date=">=$(date -d '7 days ago' +%Y-%m-%d)" --json repository --limit 5
   ```

3. **Enable verbose output**:
   Set `RECALL_DEBUG=1` environment variable

4. **Check rate limits**:
   ```bash
   gh api rate_limit
   ```

---

## Notes

- Auto-discovery uses GitHub Search API which has higher rate limits than REST API
- Discovery limit is 1000 commits (configurable in source)
- Commits are deduplicated if same commit appears in search multiple times
- Repo names are sorted alphabetically in output for consistency
