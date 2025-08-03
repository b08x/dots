# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository, with enhanced debugging methodologies and error analysis strategies.

## Project Configuration

**Project Type**: [Language/Framework - e.g., Ruby CLI, Node.js API, Python ML, React App]
**Main Technology Stack**: [Primary technologies - e.g., Ruby/Thor, Node.js/Express, Python/FastAPI, React/TypeScript]
**Runtime Environment**: [Development environment details - e.g., Ruby 3.x, Node 18+, Python 3.9+]

## Debugging Methodology & Error Analysis

### Root Cause Analysis Framework

**Primary Principle**: Always distinguish between *primary root causes* and *contributing architectural issues*. 

#### Error Investigation Priority Matrix

1. **Immediate Error Source** (Priority 1)
   - Focus on the exact error message and its immediate context
   - If fixing a "contributing factor" doesn't resolve the *specific* error message, escalate back to deeper analysis
   - Ask continuously: "Did this fix resolve the *exact* error message I'm debugging?"

2. **Execution Context Analysis** (Priority 2)
   - When runtime errors occur during module/file loading, examine:
     - Initialization methods and constructor chains
     - Top-level code execution (including malformed comments/docs)
     - Import/require statements and dependency resolution
     - Configuration blocks that might execute during load
     - Documentation or comment blocks that might be parsed as executable code

3. **Architectural Issues** (Priority 3)
   - Circular dependencies, early instantiations, method/function visibility
   - Address these after confirming they're not the primary cause

### Diagnostic Tool Interpretation

#### Language-Specific "Clean Syntax" Paradox Resolution
**Critical Understanding**: Syntax checkers returning "OK" does NOT eliminate syntax-related issues as the root cause.

**When Syntax Check Passes + Runtime Error occurs**:

##### For Ruby Projects:
- `ruby -c file.rb` returns "Syntax OK" but runtime errors during `require`
- **Focus Areas**: YARD documentation blocks, here-docs, multi-line strings, embedded code examples

##### For JavaScript/TypeScript Projects:
- ESLint/TSC passes but runtime errors during `import`
- **Focus Areas**: JSDoc examples, dynamic imports, type assertions in comments

##### For Python Projects:
- `python -m py_compile` succeeds but import errors
- **Focus Areas**: Docstring examples, type hints, decorator execution

**Immediate Action Pattern**:
```
Syntax Valid + Runtime Error = Examine how comments, documentation, 
or string literals might be interpreted by the parser/runtime
```

#### Static Analysis Simulation Protocol
When encountering syntax errors (missing brackets, unexpected tokens):

**Instead of manual pattern matching**:
1. **Simulate IDE Analysis**: "A modern IDE would immediately identify this. Let me simulate that analysis..."
2. **Language-Specific Bracket Matching**: Systematic counting with line number tracking
3. **Linter Simulation**: "The linter would flag this as..." and provide the likely specific violation

### Enhanced Search and Investigation Patterns

#### Targeted Error Tracking
When an error mentions unexpected method/function calls during initialization:

```bash
# Primary search: Find ALL instances of the problematic method/function
grep -rn "method_name" src/ lib/ app/

# Secondary search: Include non-code contexts (comments, docs)
grep -rn -A 2 -B 2 "method_name" .

# Tertiary search: Look for similar patterns that might be misinterpreted
grep -rn -E "(example|demo|sample).*method_name" .
```

#### Context-Aware File Analysis
For files throwing errors during import/require:

1. **Top-Level Execution Check**: Scan for code outside class/function definitions
2. **Documentation Block Analysis**: Examine inline code examples
3. **Variable/Constant Initialization**: Look for early instantiation patterns

## Common Commands

### Development Commands

```bash
# Install dependencies
[package_manager_install_command]  # e.g., npm install, bundle install, pip install -r requirements.txt

# Run main application
[main_application_command]         # e.g., npm start, bundle exec app, python main.py

# Run tests
[test_command]                     # e.g., npm test, bundle exec rspec, pytest

# Run linting/code style checks
[linting_command]                  # e.g., eslint ., rubocop, flake8

# Generate documentation
[docs_command]                     # e.g., jsdoc, yard doc, sphinx-build

# Start development console/REPL
[repl_command]                     # e.g., node, bundle exec pry, python
```

### Debugging Commands

#### Systematic Error Investigation
```bash
# 1. Syntax validation (understand limitations)
[syntax_check_command] path/to/file

# 2. Minimal load test (isolate loading issues)
[minimal_import_test] path/to/file

# 3. Module/Class introspection
[introspection_command]

# 4. Documentation parsing check
[doc_validation_command]
```

#### Language-Specific Diagnostics

##### Ruby Projects:
```bash
# Syntax check
ruby -c lib/target_file.rb

# Minimal load test
ruby -e "require_relative 'lib/target_file'"

# Class method introspection
ruby -e "require_relative 'lib/target_file'; puts ClassName.methods(false)"

# YARD documentation check
yard stats lib/target_file.rb
```

##### JavaScript/Node.js Projects:
```bash
# Syntax check
node --check src/target_file.js

# Minimal import test
node -e "require('./src/target_file')"

# Module introspection
node -e "console.log(Object.getOwnPropertyNames(require('./src/target_file')))"

# ESLint check
eslint src/target_file.js
```

##### Python Projects:
```bash
# Syntax check
python -m py_compile src/target_file.py

# Minimal import test
python -c "import src.target_file"

# Module introspection
python -c "import src.target_file; print(dir(src.target_file))"

# Type checking
mypy src/target_file.py
```

#### Error-Specific Diagnostics
```bash
# For missing bracket/delimiter errors - simulate IDE analysis
[syntax_checker_verbose] path/to/file 2>&1 | head -20

# For method/function resolution errors during load
[minimal_load_test] 2>&1

# For circular dependency detection
[dependency_analyzer] 2>&1 | grep -i circular
```

### Project-Specific Commands

#### [Custom Command Category 1]
```bash
# Add project-specific commands here
# e.g., Database commands, Build commands, Deployment commands
```

#### [Custom Command Category 2]
```bash
# Add additional project-specific commands here
```

## Error Pattern Recognition

### Common Loading/Import Errors

#### Method/Function Not Found during module load
**Pattern**: Method/function called on object that doesn't respond during import/require
**Primary Causes**:
1. **Malformed documentation** with executable code examples
2. **Early instantiation** in module/class body
3. **Circular dependencies** causing incomplete definition

**Investigation Strategy**:
```bash
# 1. Check for top-level execution
grep -rn "^\s*[^#]*\." src/ lib/

# 2. Examine documentation blocks
grep -rn -A 5 "@example\|```" src/ lib/

# 3. Look for early instantiation
grep -rn "new \|instantiate\|\.call" src/ lib/
```

#### Syntax Error: unexpected end/missing delimiter
**Pattern**: Missing closing brackets, parentheses, or language-specific delimiters
**Efficient Resolution**:
1. **Simulate IDE**: "Modern IDEs highlight this immediately"
2. **Use language parser**: Language-specific syntax checker with line focus
3. **Bracket matching**: Systematic delimiter counting

#### Import/Require Error or circular dependency
**Pattern**: Module cannot be loaded due to dependency cycles
**Resolution Strategy**:
1. **Dependency mapping**: Trace import/require chains
2. **Module loading examination**: Check for loading conflicts
3. **Import order**: Identify initialization sequence issues

## Architecture Overview

### [Project Architecture Section]
*Customize this section based on your project's specific architecture*

#### Core Components
- **[Component 1]** (`path/to/component`) - [Description]
- **[Component 2]** (`path/to/component`) - [Description]
- **[Component 3]** (`path/to/component`) - [Description]

#### Key Technologies
- **[Technology 1]** - [Usage description]
- **[Technology 2]** - [Usage description]
- **[Technology 3]** - [Usage description]

#### Design Patterns
*Document the key design patterns used in your project*

### Configuration System
*Document your project's configuration approach*

#### Configuration Files
- `config/file1` - [Purpose]
- `config/file2` - [Purpose]

#### Environment Variables
- `ENV_VAR_1` - [Description]
- `ENV_VAR_2` - [Description]

## Development Notes

### Important File Locations
*Document key files and their locations*
- Configuration files: `path/to/config`
- Main source: `path/to/src`
- Tests: `path/to/tests`
- Documentation: `path/to/docs`

### Testing Framework
*Document your testing approach*
- Test runner: [Framework name]
- Test files located in: `path/to/tests`
- Test types: [unit, integration, e2e, etc.]

### Code Quality Tools
*List your code quality tools*
- Linting: [Tool name and configuration]
- Type checking: [If applicable]
- Documentation generation: [Tool name]
- Code formatting: [Tool name]

### [Custom Development Notes Section]
*Add project-specific development notes*

## Debugging Decision Tree

```
Runtime Error During Module Load
├── Syntax Check Passes?
│   ├── YES → Check documentation blocks, top-level execution
│   └── NO → Standard syntax error resolution
├── Error mentions specific method/function call?
│   ├── YES → Search ALL instances in codebase (including docs)
│   └── NO → Check initialization chain
├── Method/Function Not Found during import?
│   ├── Check inline code examples for executable code
│   ├── Examine module-level instantiation
│   └── Review circular dependencies (lower priority)
└── Syntax Error (missing delimiter)?
    ├── Simulate IDE analysis first
    ├── Use bracket matching if needed
    └── Avoid manual pattern counting
```

## Language-Specific Considerations

### [Primary Language] Specific Notes
*Add language-specific debugging tips and common patterns*

#### Common Pitfalls
1. [Language-specific pitfall 1]
2. [Language-specific pitfall 2]
3. [Language-specific pitfall 3]

#### Best Practices
1. [Language-specific best practice 1]
2. [Language-specific best practice 2]
3. [Language-specific best practice 3]

### Framework-Specific Notes
*Add framework-specific debugging guidance*

## Project-Specific Error Patterns

### [Custom Error Pattern 1]
**Pattern**: [Description]
**Common Causes**: [List causes]
**Resolution Strategy**: [Steps to resolve]

### [Custom Error Pattern 2]
**Pattern**: [Description]
**Common Causes**: [List causes]
**Resolution Strategy**: [Steps to resolve]

---

## Template Usage Instructions

**To customize this template for your project:**

1. **Replace all bracketed placeholders** `[like this]` with project-specific information
2. **Fill in the Project Configuration section** with your tech stack details
3. **Customize the Common Commands section** with your actual commands
4. **Document your specific architecture** in the Architecture Overview
5. **Add project-specific error patterns** you've encountered
6. **Update language-specific diagnostics** for your primary language/framework
7. **Remove unused sections** or add new ones as needed

**Key sections to always customize:**
- Project Configuration
- Common Commands (Development and Debugging)
- Architecture Overview
- Important File Locations
- Project-Specific Error Patterns
