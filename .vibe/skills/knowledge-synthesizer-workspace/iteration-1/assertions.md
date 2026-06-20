# Knowledge Synthesizer - Test Assertions

## Test 0: High-Activity Multi-Tool Project

### File Existence
- [ ] Dashboard file created at outputs/ directory
- [ ] Canvas file created (*.canvas)
- [ ] Dashboard is valid markdown (parseable)
- [ ] Canvas is valid JSON

### Content Requirements - Dashboard
- [ ] Contains "Timeline" or "timeline" section heading
- [ ] Mentions all 4 tools: crush, gemini-cli, mistral-vibe, opencode
- [ ] Contains workflow pattern distribution data
- [ ] Shows "explore-then-build", "direct-execution", "iterative-refinement"
- [ ] Has friction analysis section
- [ ] Mentions "repeated-mistakes" friction category

### Content Requirements - Canvas
- [ ] Canvas JSON has "nodes" array with length > 0
- [ ] Canvas JSON has "edges" array
- [ ] At least one node references workflow patterns
- [ ] Node IDs are valid (16-char hex)
- [ ] All edge fromNode/toNode IDs exist in nodes array

### Data Accuracy
- [ ] Session count matches or is close to 104
- [ ] Tool count is 4
- [ ] Workflow patterns sum to reasonable total

---

## Test 1: Knowledge-Gap Friction Pattern

### File Existence
- [ ] Dashboard file created
- [ ] NotebookLM export directory exists OR error message about NotebookLM
- [ ] Dashboard is valid markdown

### Content Requirements - Dashboard
- [ ] Has "Friction" or "friction" section
- [ ] Mentions "knowledge-gap" friction type
- [ ] Mentions "stale-assumptions" friction type
- [ ] Mentions "repeated-mistakes" friction type
- [ ] Has "Learnings" or "learnings" section
- [ ] Has actionable items or recommendations
- [ ] Mentions all 4 tools: claude-code, gemini-cli, mistral-vibe, crush

### Insight Quality
- [ ] Extracts insights with confidence >= 0.85
- [ ] Shows which tool handled each friction type
- [ ] Provides specific examples from sessions

### NotebookLM Integration
- [ ] Either: NotebookLM sources created (17 sessions)
- [ ] Or: Clear error message explaining why NotebookLM unavailable
- [ ] No silent failure

---

## Test 2: Multi-Project Insight Correlation

### File Existence
- [ ] 3 dashboard files created (one per project)
- [ ] Cross-project canvas file created
- [ ] All dashboards are valid markdown
- [ ] Canvas is valid JSON

### Content Requirements - Dashboards
- [ ] Each dashboard mentions its project_id
- [ ] Each dashboard shows insight counts
- [ ] Each dashboard has insight type distribution

### Content Requirements - Canvas
- [ ] Canvas has central "topic" or "correlation" node
- [ ] Canvas has nodes for each of the 3 projects
- [ ] Canvas has edges connecting projects to central node
- [ ] Canvas mentions "common learnings"
- [ ] Canvas references "decision patterns"
- [ ] Canvas includes "prompt quality" analysis

### Data Accuracy
- [ ] Project 7988f69c: ~554 insights mentioned
- [ ] Project 1519a127: ~134 insights mentioned
- [ ] Project e3b0c442: ~128 insights mentioned
- [ ] Focus on confidence >= 0.9 insights (filters applied)

### Cross-Project Analysis
- [ ] Identifies at least 2 common patterns across projects
- [ ] Shows at least 1 difference in decision patterns
- [ ] References workflow pattern correlation with insight quality

---

## Grading Script Requirements

For each assertion:
- **Pass**: Requirement is met
- **Fail**: Requirement is not met
- **N/A**: Not applicable (e.g., NotebookLM not available)

Evidence should include:
- File path where requirement was checked
- Specific line/section that proves pass/fail
- Grep command used for verification

## Automated Checks

```bash
# Example assertion checks

# Test 0 - Dashboard exists
test -f outputs/dashboard.md && echo "PASS" || echo "FAIL"

# Test 0 - Mentions all 4 tools
grep -q "crush" outputs/dashboard.md && \
grep -q "gemini-cli" outputs/dashboard.md && \
grep -q "mistral-vibe" outputs/dashboard.md && \
grep -q "opencode" outputs/dashboard.md && \
echo "PASS: All tools mentioned" || echo "FAIL: Missing tools"

# Test 0 - Canvas is valid JSON
python3 -c "import json; json.load(open('outputs/*.canvas'))" && \
echo "PASS: Valid JSON" || echo "FAIL: Invalid JSON"

# Test 1 - Friction types mentioned
grep -i "knowledge-gap\|stale-assumptions\|repeated-mistakes" outputs/dashboard.md | \
wc -l | grep -q "3" && echo "PASS" || echo "FAIL"

# Test 2 - 3 dashboards created
find outputs/ -name "*dashboard*.md" | wc -l | grep -q "3" && \
echo "PASS" || echo "FAIL"
```
