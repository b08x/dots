# Intelligent Refactoring Engine

I'll help you restructure your code systematically - preserving functionality while improving structure, readability, and maintainability.

Arguments: `$ARGUMENTS` - files, directories, or refactoring scope

**SESSION FILES LOCATION: Always use refactor/ folder in current directory**

## Session Intelligence

I'll maintain refactoring continuity across sessions:

**Session Files (in current project):**
- `refactor/plan.md` - Refactoring plan with progress tracking  
- `refactor/state.json` - Current state and completed actions

**IMPORTANT:** The `refactor` folder is created in your CURRENT PROJECT directory. Use `refactor/` to access it.

**Auto-Detection:**
- If session exists: Resume from last checkpoint
- If no session: Create new refactoring plan
- Commands: `resume`, `continue`, `status`, `new`

**EXAMPLE OF CORRECT PATH USAGE:**
```
# CORRECT - looks in current project:
Read refactor/state.json
LS refactor

# WRONG - these will fail:
Read ../../../refactor/state.json
Read $HOME/.claude/refactor/state.json
```

## Phase 1: Initial Setup & Analysis

**MANDATORY FIRST STEPS FOR SESSION CHECK:**
```
Step 1: Check for refactor directory in CURRENT directory
Command: LS refactor

Step 2: If refactor exists, read session files:
Command: Read refactor/state.json
Command: Read refactor/plan.md

DO NOT USE THESE WRONG PATHS:
- ../../../refactor/  (WRONG - goes up directories)
- $HOME/refactor/  (WRONG - home directory)
- ~/refactor/  (WRONG - home directory)

ONLY USE: refactor/ (current directory)
```

**CRITICAL:** The refactor folder is created in the CURRENT WORKING DIRECTORY where user is running the command. NOT in home, NOT in parent directories.

I'll examine your codebase to identify improvement opportunities:

**Analysis Focus:**
- Code complexity hotspots using **Grep** patterns
- Duplication detection across files
- Architecture inconsistencies
- Test coverage for safe refactoring
- Performance bottlenecks

**Smart Scoping:**
- If specific files provided: Focused analysis
- If directory provided: Recursive analysis
- If no arguments: Strategic project-wide scan

## Phase 2: Refactoring Planning

Based on analysis, I'll create a structured plan:

**Refactoring Categories:**
- **Quick Wins**: Variable renames, method extractions
- **Structural**: Pattern applications, dependency improvements
- **Architectural**: Major reorganizations, module boundaries
- **Performance**: Algorithm optimizations, caching strategies

**Plan Structure:**
I'll create a detailed plan in `refactor/plan.md`:
- Prioritized refactoring tasks
- Risk assessment for each change
- Checkpoints for validation
- Rollback points if needed

## Phase 3: Incremental Execution

I'll apply refactorings systematically:

**Execution Order:**
1. Create git checkpoint for safety
2. Apply low-risk improvements first
3. Validate after each change
4. Progress to higher-impact refactorings
5. Update plan with completion status

**Continuous Validation:**
- Run tests after each refactoring
- Check for compilation/syntax errors
- Verify behavior preservation
- Monitor performance impact

## Phase 4: Pattern Application

I'll apply consistent patterns throughout:

**Pattern Recognition:**
- Identify existing patterns in your code
- Detect anti-patterns to eliminate
- Apply design patterns where beneficial
- Maintain architectural consistency

**Code Improvements:**
- Extract duplicated code into utilities
- Simplify complex functions
- Improve naming for clarity
- Reduce coupling between modules

## Phase 5: Quality Metrics

I'll track refactoring impact:

**Measurable Improvements:**
- Complexity reduction percentages
- Duplication elimination count
- Test coverage maintenance
- Performance benchmarks
- Code readability scores

## Context Continuity

**Session Management:**
When you return and run `/refactor` or `/refactor resume`:
- I'll load existing plan and state
- Display progress summary
- Continue from last checkpoint
- Maintain all refactoring decisions

**Progress Example:**
```
RESUMING REFACTORING SESSION
├── Session: refactor_2025_08_02_1430
├── Progress: 12 of 20 tasks complete
├── Last Action: Extract UserService methods
└── Next: Simplify PaymentProcessor logic

Continuing from checkpoint...
```

## Practical Examples

**Start Refactoring:**
```
/refactor                    # Analyze entire project
/refactor src/components/    # Focus on specific directory
/refactor UserService.ts     # Target single file
```

**Session Control:**
```
/refactor resume    # Continue existing session
/refactor status    # Check progress without continuing
/refactor new       # Start fresh (archives existing)
```

## Safety Guarantees

**Protection Measures:**
- Git checkpoints before changes
- Incremental commits at logical points
- Test validation after each step
- Clear rollback strategy

**Important:** I will NEVER:
- Add AI attribution or signatures
- Modify git configuration
- Break working functionality
- Make changes without validation

## Execution Guarantee

**My workflow ALWAYS follows this order:**

1. **Setup session** - Check/create state files FIRST
2. **Analyze completely** - Full codebase understanding
3. **Write plan** - Document all changes in `refactor_plan.md`
4. **Get confirmation** - Show plan summary before starting
5. **Execute incrementally** - Follow plan with checkpoints

**I will NEVER:**
- Start refactoring without a written plan
- Make changes before complete analysis
- Skip session file creation
- Proceed without showing the plan first

I'll ensure perfect continuity between sessions, always resuming exactly where we left off with full context and decision history.