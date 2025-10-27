# Documentation Manager

I'll intelligently manage your project documentation by analyzing what actually happened and updating ALL relevant docs accordingly.

**My approach:**
1. **Analyze our entire conversation** - Understand the full scope of changes
2. **Read ALL documentation files** - README, CHANGELOG, docs/*, guides, everything
3. **Identify what changed** - Features, architecture, bugs, performance, security, etc
4. **Update EVERYTHING affected** - Not just one file, but all relevant documentation
5. **Maintain consistency** - Ensure all docs tell the same story

**I won't make assumptions** - I'll look at what ACTUALLY changed and update accordingly.
If you refactored the entire architecture, I'll update architecture docs, README, migration guides, API docs, and anything else affected.

## Mode 1: Documentation Overview (Default)

When you run `/docs` without context, I'll:
- **Glob** all markdown files (README, CHANGELOG, docs/*)
- **Read** each documentation file
- **Analyze** documentation coverage
- **Present** organized summary

Output format:
```
DOCUMENTATION OVERVIEW
├── README.md - [status: current/outdated]
├── CHANGELOG.md - [last updated: date]
├── CONTRIBUTING.md - [completeness: 85%]
├── docs/
│   ├── API.md - [status]
│   └── architecture.md - [status]
└── Total coverage: X%

KEY FINDINGS
- Missing: Setup instructions
- Outdated: API endpoints (3 new ones)
- Incomplete: Testing guide
```

## Mode 2: Smart Update

When you run `/docs update` or after implementations, I'll:

1. **Run `/understand`** to analyze current codebase
2. **Compare** code reality vs documentation
3. **Identify** what needs updating:
   - New features not documented
   - Changed APIs or interfaces
   - Removed features still in docs
   - New configuration options
   - Updated dependencies

4. **Update systematically:**
   - README.md with new features/changes
   - CHANGELOG.md with version entries
   - API docs with new endpoints
   - Configuration docs with new options
   - Migration guides if breaking changes

## Mode 3: Session Documentation

When run after a long coding session, I'll:
- **Analyze conversation history**
- **List all changes made**
- **Group by feature/fix/enhancement**
- **Update appropriate docs**

Updates will follow your project's documentation style and conventions, organizing changes by type (Added, Fixed, Changed, etc.) in the appropriate sections.

## Mode 4: Context-Aware Updates

Based on what happened in session:
- **After new feature**: Update README features, add to CHANGELOG
- **After bug fixes**: Document in CHANGELOG, update troubleshooting
- **After refactoring**: Update architecture docs, migration guide
- **After security fixes**: Update security policy, CHANGELOG
- **After performance improvements**: Update benchmarks, CHANGELOG

## Smart Documentation Rules

1. **Preserve custom content** - Never overwrite manual additions
2. **Match existing style** - Follow current doc formatting
3. **Semantic sections** - Add to correct sections
4. **Version awareness** - Respect semver in CHANGELOG
5. **Link updates** - Fix broken internal links

## Agent Selection Logic

**I use specialized SFL-enhanced documentation agents based on documentation type:**

### **Documentation Type Detection**

**Step 1: Analyze Scope**
- Scan changed files to identify documentation needs
- Analyze conversation history for context
- Determine primary documentation focus

**Step 2: Select Appropriate Agent(s)**

**Single-Agent Scenarios:**
- **API Documentation** → `api-documenter` agent
  - Use for: Endpoint docs, OpenAPI specs, request/response examples
  - Output: Transformation contracts, edge cases, performance characteristics
  - Template: API/Interface Documentation (SFL Template 6)

- **Architecture Documentation** → `technical_documentation_expert_sfl` agent
  - Use for: System architecture, component relationships, technical depth
  - Output: 10-section analysis + architecture template enhancements
  - Template: Technical Architecture Blueprint

- **Algorithmic Analysis** → `algo-depth` agent
  - Use for: Codebase analysis, complexity documentation, performance analysis
  - Output: Algorithm transformations, component relationships, evidence-based complexity
  - Template: System Overview + Technical Architecture

- **General Documentation** → `documentation-expert` agent
  - Use for: User guides, feature descriptions, troubleshooting, system overviews
  - Output: SFL-structured docs with appropriate template application
  - Template: System Overview, Feature Description, or Troubleshooting

**Multi-Agent Scenarios:**

- **Feature with API + User Docs** → `api-documenter` + `documentation-expert` (parallel)
- **Architecture + Algorithms** → `technical_documentation_expert_sfl` + `algo-depth` (parallel)
- **Complete System Documentation** → All agents (coordinated sequence)

### **Agent Invocation Pattern**

**Single Agent:**
```
Use Task tool with subagent_type and detailed prompt:
"Document [specific scope] using SFL [template] for [files/context]"
```

**Parallel Agents (Independent Updates):**
```
Use multiple Task tool invocations in single message for concurrent execution
```

**Sequential Agents (Dependent Updates):**
```
1. Invoke first agent with analysis context
2. Capture results and insights
3. Invoke dependent agent with enriched context
```

### **Mode-Specific Agent Usage**

**Mode 1: Documentation Overview**
- Analyze existing docs (Glob/Read)
- Invoke `documentation-expert` for SFL quality assessment
- Report: Coverage + SFL validation results

**Mode 2: Smart Update**
- Detect changes by analyzing code and conversation
- Route to specialized agents:
  - API changes → `api-documenter`
  - Architecture changes → `technical_documentation_expert_sfl`
  - Algorithm changes → `algo-depth`
  - General changes → `documentation-expert`

**Mode 3: Session Documentation**
- Analyze conversation history for all changes
- Group changes by type
- Invoke parallel agents for independent documentation
- Consolidate with SFL quality validation

**Mode 4: Context-Aware Updates**
- **After new feature** → `documentation-expert` (Feature Description template)
- **After bug fixes** → `documentation-expert` (Troubleshooting template)
- **After refactoring** → `technical_documentation_expert_sfl` (Architecture template)
- **After API changes** → `api-documenter` (API/Interface template)
- **After performance work** → `algo-depth` (Complexity analysis)

## Agent Coordination Workflow

**For complex documentation updates requiring multiple agents:**

### **Phase 1: Analysis (Sequential if needed)**
```
If codebase analysis required:
├─ Invoke algo-depth agent first
├─ Capture architectural insights
├─ Document complexity analysis
└─ Use results to inform downstream agents
```

### **Phase 2: Documentation (Parallel where possible)**
```
Launch independent agents simultaneously:
├─ api-documenter (API endpoints)
├─ technical_documentation_expert_sfl (Architecture)
├─ documentation-expert (User guides)
└─ Execute in parallel for efficiency
```

### **Phase 3: Consolidation (Sequential)**
```
After agents complete:
├─ Collect all outputs
├─ Validate SFL quality across all docs
├─ Ensure consistency and cross-references
├─ Update internal links and navigation
└─ Final quality gate check
```

### **Example Workflows**

**Major Feature Addition:**
```
/docs after implementing authentication feature
├─ Step 1: Invoke algo-depth to analyze new code structure
├─ Step 2 (Parallel):
│  ├─ api-documenter for authentication endpoints
│  ├─ documentation-expert for user authentication guide
│  └─ technical_documentation_expert_sfl for security architecture
└─ Step 3: Consolidate and validate SFL quality
```

**API Enhancement:**
```
/docs after adding new REST endpoints
├─ Invoke api-documenter agent
├─ Generate transformation contracts for each endpoint
├─ Update OpenAPI specification with SFL-calibrated descriptions
├─ Document edge cases and performance characteristics
└─ Validate against API documentation checklist
```

**Architecture Refactoring:**
```
/docs after microservices migration
├─ Invoke technical_documentation_expert_sfl
├─ Generate 10-section documentation with architecture template
├─ Create component relationship diagrams
├─ Document dependency analysis with failure propagation
└─ Validate against architecture documentation checklist
```

## SFL Quality Validation

**All agent outputs undergo SFL quality validation:**

### **Validation Checklist**

**1. Modality Calibration Verification**
- [ ] High certainty ("does/is/has") matches verified specifications only
- [ ] Medium certainty ("typically/generally") used for observable patterns
- [ ] Low certainty ("may/might/can") applied to conditional outcomes
- [ ] No absolute claims ("always/never") without comprehensive evidence

**2. Process Coverage Validation**
- [ ] Material processes specify inputs → transformations → outputs
- [ ] Mental processes document user cognitive journey
- [ ] Relational processes map component dependencies
- [ ] Appropriate process types for documentation context

**3. Evidence Backing Verification**
- [ ] Performance claims include metrics with conditions
- [ ] Capability descriptions specify what system actually does
- [ ] No vague terms ("comprehensive", "robust") without specification
- [ ] Circumstantial qualifiers prevent overgeneralization

**4. Limitation Documentation**
- [ ] What system can't do documented as clearly as capabilities
- [ ] Edge cases included with trigger conditions
- [ ] Boundary conditions specified
- [ ] Failure modes documented with mitigation strategies

### **Quality Gates**

**Reject Documentation If:**
- ❌ Uses vague capability terms without specification
- ❌ Contains overclaiming (absolute statements without evidence)
- ❌ Missing circumstantial qualifiers for conditional behavior
- ❌ Omits limitation documentation
- ❌ Conflates process types (Material ≠ Mental ≠ Relational)

**Accept Documentation If:**
- ✅ Passes all SFL validation checklist items
- ✅ Modality matches evidence quality throughout
- ✅ Process types clearly identified and appropriate
- ✅ Evidence backing provided or referenced
- ✅ Limitations documented alongside capabilities

### **Post-Agent Validation Process**

```
After agent completes documentation:
1. Review output against SFL quality checklist
2. Verify modality calibration accuracy
3. Validate process type coverage
4. Check evidence backing for claims
5. Confirm limitation documentation
6. If validation fails → Provide feedback to agent for revision
7. If validation passes → Integrate documentation
```

## Operational Instructions: Agent Invocation

**How to actually invoke specialized agents using the Task tool:**

### **Step 1: Determine Documentation Needs**

```
Analyze context to identify:
1. What changed? (code, features, architecture, APIs, algorithms)
2. What documentation types needed? (API, architecture, general, analysis)
3. Independent or dependent updates? (parallel or sequential agents)
```

### **Step 2: Invoke Appropriate Agent(s)**

**For Single Agent (API Documentation Example):**
```
I'll invoke the api-documenter agent to document the new authentication endpoints.

Use Task tool with:
- subagent_type: "api-documenter"
- description: "Document authentication API"
- prompt: "Document the authentication API endpoints for the user authentication system.

**Context:**
- New endpoints: POST /auth/login, POST /auth/register, POST /auth/logout
- Authentication uses JWT tokens
- Includes rate limiting (5 requests/minute for login)

**Requirements:**
- Use SFL API/Interface Documentation template (Template 6)
- Generate transformation contracts for each endpoint
- Document edge cases (invalid credentials, expired tokens, rate limit exceeded)
- Include performance characteristics with conditions
- Validate against API documentation checklist

**Files to analyze:**
- /src/api/auth.js (implementation)
- /tests/api/auth.test.js (test cases for validation)"
```

**For Multiple Parallel Agents (Feature Documentation Example):**
```
I'll invoke multiple agents in parallel for the authentication feature documentation.

Use multiple Task tool invocations in single message:

Task 1:
- subagent_type: "api-documenter"
- description: "Document auth API endpoints"
- prompt: "Document authentication API endpoints with transformation contracts..."

Task 2:
- subagent_type: "documentation-expert"
- description: "Create user authentication guide"
- prompt: "Create user guide for authentication feature using Feature Description template..."

Task 3:
- subagent_type: "technical_documentation_expert_sfl"
- description: "Document security architecture"
- prompt: "Document security architecture for authentication using Architecture template..."
```

**For Sequential Agents (Architecture Analysis → Documentation):**
```
Step 1: Analyze codebase first

Use Task tool:
- subagent_type: "algo-depth"
- description: "Analyze authentication architecture"
- prompt: "Analyze the authentication system architecture, component relationships, and complexity..."

Step 2: After receiving analysis results, invoke documentation agent

Use Task tool:
- subagent_type: "technical_documentation_expert_sfl"
- description: "Document architecture findings"
- prompt: "Based on the architectural analysis provided:
[paste analysis results]

Document the authentication architecture using Technical Architecture template..."
```

### **Step 3: Validate Agent Output**

```
After agent completes:
1. Review output against SFL quality checklist
2. Check for:
   - Evidence-based claims (no vague "robust", "comprehensive")
   - Modality calibration (high/medium/low certainty appropriate)
   - Process coverage (Material, Mental, Relational addressed)
   - Limitation documentation (what system can't do)
3. If validation fails: Provide specific feedback for revision
4. If validation passes: Integrate documentation
```

### **Agent Invocation Decision Tree**

```
Documentation Request Received
    │
    ├─ API Changes Detected?
    │   └─ YES → Invoke api-documenter
    │       - Use API/Interface template
    │       - Focus on transformation contracts
    │
    ├─ Architecture Changes Detected?
    │   └─ YES → Invoke technical_documentation_expert_sfl
    │       - Use Technical Architecture template
    │       - Include 10-section analysis + architecture enhancements
    │
    ├─ Algorithm/Performance Changes Detected?
    │   └─ YES → Invoke algo-depth
    │       - Analyze complexity and transformations
    │       - Document with code evidence
    │
    ├─ Multiple Change Types Detected?
    │   └─ YES → Invoke parallel agents
    │       - Launch independent agents simultaneously
    │       - Consolidate results with SFL validation
    │
    └─ General Documentation Needed?
        └─ YES → Invoke documentation-expert
            - Select appropriate template (Feature/System/Troubleshooting)
            - Apply SFL methodology
```

### **Example: Complete Agent Workflow**

```
User runs /docs after implementing authentication feature

Analysis Phase:
✓ Detected: New auth.js file with API endpoints
✓ Detected: New user-guide.md needed
✓ Detected: Architecture changes (new security layer)

Agent Selection:
→ 3 independent documentation needs = Parallel agents
→ api-documenter for endpoints
→ documentation-expert for user guide
→ technical_documentation_expert_sfl for architecture

Invocation:
[Launch 3 Task tool calls in single message]

Consolidation:
✓ Collect all 3 agent outputs
✓ Validate each against SFL checklist
✓ Ensure cross-references correct
✓ Update internal links
✓ Final quality gate → PASS

Result:
✓ API documentation with transformation contracts
✓ User guide with cognitive journey mapping
✓ Architecture docs with component relationships
✓ All validated for evidence-based language
✓ No capability overclaiming detected
```

## Integration with Commands

Works seamlessly with:
- `/understand` - Get current architecture first
- `/contributing` - Update contribution guidelines
- `/test` - Document test coverage changes
- `/scaffold` - Add new component docs
- `/security-scan` - Update security documentation

## Documentation Rules

**ALWAYS:**
- Read existing docs completely before any update
- Find the exact section that needs updating
- Update in-place, never duplicate
- Preserve custom content and formatting
- Only create new docs if absolutely essential (README missing, etc)

**Preserve sections:**
```markdown
<!-- CUSTOM:START -->
User's manual content preserved
<!-- CUSTOM:END -->
```

**Smart CHANGELOG:**
- Groups changes by type
- Suggests version bump (major/minor/patch)
- Links to relevant PRs/issues
- Maintains chronological order

**Important**: I will NEVER:
- Delete existing documentation
- Overwrite custom sections
- Change documentation style drastically
- Add AI attribution markers
- Create unnecessary documentation

After analysis, I'll ask: "How should I proceed?"
- Update all outdated docs
- Focus on specific files
- Create missing documentation
- Generate migration guide
- Skip certain sections

## Additional Scenarios & Integrations

### When to Use /docs

Simply run `/docs` after any significant work:
- After `/understand` - Ensure docs match code reality
- After `/fix-todos` or bug fixes - Update all affected documentation
- After `/scaffold` or new features - Document what was added
- After `/security-scan` or `/review` - Document findings and decisions
- After major refactoring - Update architecture, migration guides, everything

**I'll figure out what needs updating based on what actually happened, not rigid rules.**

### Documentation Types
I can manage:
- **API Documentation** - Endpoints, parameters, responses
- **Database Schema** - Tables, relationships, migrations
- **Configuration** - Environment variables, settings
- **Deployment** - Setup, requirements, procedures
- **Troubleshooting** - Common issues and solutions
- **Performance** - Benchmarks, optimization guides
- **Security** - Policies, best practices, incident response

### Smart Features
- **Version Detection** - Auto-increment version numbers
- **Breaking Change Alert** - Warn when docs need migration guide
- **Cross-Reference** - Update links between docs
- **Example Generation** - Create usage examples from tests
- **Diagram Updates** - Update architecture diagrams (text-based)
- **Dependency Tracking** - Document external service requirements

### Team Collaboration
- **PR Documentation** - Generate docs for pull requests
- **Release Notes** - Create from CHANGELOG for releases
- **Onboarding Docs** - Generate from project analysis
- **Handoff Documentation** - Create when changing teams
- **Knowledge Transfer** - Document before leaving project

### Quality Checks
- **Doc Coverage** - Report undocumented features
- **Freshness Check** - Flag stale documentation
- **Consistency** - Ensure uniform style across docs
- **Completeness** - Verify all sections present
- **Accuracy** - Compare docs vs actual implementation

### Smart Command Combinations

**After analyzing code:**
```bash
/understand && /docs
# Analyzes entire codebase
# Then invokes algo-depth agent for algorithmic analysis
# Then invokes documentation-expert for system overview documentation
# Output: Comprehensive codebase documentation with complexity analysis
```

**After fixing technical debt:**
```bash
/fix-todos && /test && /docs
# Fixes TODOs, verifies everything works
# Then invokes documentation-expert with Troubleshooting template
# Output: Updated CHANGELOG and troubleshooting documentation
```

**After major refactoring:**
```bash
/fix-imports && /format && /docs
# Fixes imports, formats code
# Then invokes technical_documentation_expert_sfl with Architecture template
# Output: Updated architecture docs with component relationships and failure propagation
```

**Before creating PR:**
```bash
/review && /docs
# Reviews code for issues
# Then routes to appropriate agents based on findings:
#   - api-documenter for API changes
#   - documentation-expert for general docs
# Output: All documentation updated with SFL quality validation
```

**After adding features:**
```bash
/scaffold component && /test && /docs
# Creates component, tests it
# Then invokes parallel agents:
#   - api-documenter if component exposes API
#   - documentation-expert for feature description
# Output: Feature documentation with transformation contracts
```

**After API implementation:**
```bash
/test && /docs
# Runs API tests to verify behavior
# Then invokes api-documenter agent
# Output: OpenAPI spec + transformation contracts + edge case documentation
```

### Simple Usage

Just run `/docs` and I'll intelligently figure out what you need:

**Context-Aware Agent Selection:**
- **Fresh project?** → `documentation-expert` assesses existing docs with SFL quality checklist
- **Just coded?** → Routes to specialized agents based on changes detected:
  - API changes → `api-documenter` with transformation contracts
  - Architecture changes → `technical_documentation_expert_sfl` with 10-section analysis
  - Algorithm changes → `algo-depth` with complexity analysis
  - General changes → `documentation-expert` with appropriate template
- **Long session?** → Analyzes all changes, invokes parallel agents for independent updates
- **Just fixed bugs?** → `documentation-expert` updates CHANGELOG + troubleshooting docs

**Agent Intelligence Examples:**

```bash
# After implementing user authentication
/docs
→ Detects: New auth endpoints + auth flow + user model changes
→ Invokes parallel agents:
  - api-documenter: Document auth endpoints with transformation contracts
  - documentation-expert: Create user authentication guide
  - technical_documentation_expert_sfl: Document security architecture
→ Validates: All outputs pass SFL quality checklist
→ Result: Complete authentication documentation with evidence-based claims
```

```bash
# After optimizing database queries
/docs
→ Detects: Performance improvements in data layer
→ Invokes: algo-depth agent for complexity analysis
→ Documents: Query optimization with before/after complexity
→ Updates: Performance benchmarks with measured improvements
→ Result: Evidence-based performance documentation (not "fast queries")
```

```bash
# After bug fixes
/docs
→ Detects: Bug fixes in conversation history
→ Invokes: documentation-expert with Troubleshooting template
→ Updates: CHANGELOG + troubleshooting guide with diagnostic workflows
→ Result: Structured error documentation with resolution strategies
```

**No need to remember arguments - I understand context and route to the right agents automatically!**

**SFL Quality Guarantee:**
- All documentation uses evidence-based language
- Modality calibration prevents capability overclaiming
- Limitations documented alongside capabilities
- Process types (Material/Mental/Relational) clearly identified
- Transformation contracts for all system behaviors

This keeps your documentation as current as your code while ensuring precision, honesty, and systematic SFL methodology throughout your entire development lifecycle.