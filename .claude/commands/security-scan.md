# Security Analysis

I'll perform comprehensive security analysis with tracking and remediation continuity across sessions.

Arguments: `$ARGUMENTS` - specific paths or security focus areas

## Session Intelligence

I'll maintain security remediation progress:

**Session Files (in current project directory):**
- `security-scan/plan.md` - All vulnerabilities and fixes
- `security-scan/state.json` - Remediation progress

**IMPORTANT:** Session files are stored in a `security-scan` folder in your current project root

**Auto-Detection:**
- If session exists: Show fixed vs pending vulnerabilities
- If no session: Perform new security scan
- Commands: `resume`, `status`, `new`

## Phase 1: Security Assessment

**MANDATORY FIRST STEPS:**
1. First, check for `security-scan` directory in project root
2. Check for existing session files in `security-scan/` (NOT in parent directories or absolute paths)
3. If no session exists:
   - Perform full security scan
   - Create vulnerability report
   - Initialize tracking
4. Show risk summary before remediation

**Note:** Always look for session files in the current project's `security-scan/` folder, not `../../../security-scan/` or absolute paths

I'll analyze security across dimensions:

**Vulnerability Detection:**
- Hardcoded secrets and credentials
- Dependency vulnerabilities
- Insecure configurations
- Input validation issues
- Authentication weaknesses

**Risk Categorization:**
- **Critical**: Immediate exploitation possible
- **High**: Serious vulnerabilities
- **Medium**: Should be addressed
- **Low**: Best practice improvements

## Phase 2: Remediation Planning

Based on findings, I'll create remediation plan:

**Priority Order:**
1. Critical credential exposures
2. High-risk vulnerabilities
3. Dependency updates
4. Configuration hardening
5. Code pattern improvements

I'll write this plan to `security-scan/plan.md` with:
- Each vulnerability details
- Risk assessment
- Remediation approach
- Verification method

## Phase 3: Intelligent Remediation

I'll fix vulnerabilities appropriately:

**Remediation Patterns:**
- Secrets → Environment variables
- Hardcoded values → Configuration files
- Weak validation → Strong patterns
- Outdated deps → Safe updates

**Safe Practices:**
- Never log sensitive data
- Use secure defaults
- Apply principle of least privilege
- Implement defense in depth

## Phase 4: Incremental Fixing

I'll remediate systematically:

**Execution Process:**
1. Create git checkpoint
2. Fix vulnerability safely
3. Verify fix doesn't break functionality
4. Update plan with completion
5. Move to next vulnerability

**Progress Tracking:**
- Mark each fix in plan
- Update state with decisions
- Create security-focused commits

## Phase 5: Verification

After each remediation:
- Test functionality preserved
- Verify vulnerability resolved
- Check for new issues introduced
- Update security documentation

## Context Continuity

**Session Resume:**
When you return and run `/security-scan` or `/security-scan resume`:
- Load vulnerability list and progress
- Show remediation statistics
- Continue from last fix
- Maintain fix decisions

**Progress Example:**
```
RESUMING SECURITY REMEDIATION
├── Total Vulnerabilities: 23
├── Fixed: 15 (65%)
├── Critical: 0 remaining
├── High: 3 remaining
└── Next: SQL injection in UserQuery

Continuing remediation...
```

## Practical Examples

**Start Scanning:**
```
/security-scan                # Full project scan
/security-scan src/api/       # Focus on API
/security-scan "credentials"  # Credential focus
```

**Session Control:**
```
/security-scan resume    # Continue remediation
/security-scan status    # Check progress
/security-scan new       # Fresh scan
```

## Safety Guarantees

**Protection Measures:**
- Git checkpoint before fixes
- Functionality preservation
- No security regression
- Clear audit trail

**Important:** I will NEVER:
- Expose secrets in commits
- Break existing security
- Add AI attribution
- Log sensitive data

## What I'll Actually Do

1. **Scan thoroughly** - Find all vulnerabilities
2. **Prioritize wisely** - Critical issues first
3. **Fix safely** - Preserve functionality
4. **Track completely** - Perfect continuity
5. **Verify constantly** - Ensure security improved

I'll maintain complete continuity between sessions, always resuming exactly where we left off with full remediation context.