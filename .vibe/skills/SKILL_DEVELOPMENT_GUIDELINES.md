# Skill Development Guidelines

## Best Practices for Loading Reference Files

### Problem: Relative Path Resolution

Skills often need to load reference files (templates, style guides, patterns, etc.) stored in subdirectories like `references/`, `assets/`, or `templates/`. When a skill is invoked, the agent follows the instructions in `SKILL.md` and may call `read_file()` with paths mentioned in the documentation.

**Critical Issue**: Using relative paths like `references/filename.md` will fail when the skill is invoked from a directory other than the skill's own directory. This is because relative paths resolve against the **current working directory**, not the skill's installation directory.

### Solution: Use Absolute Paths

Always use **absolute paths** when referencing skill assets. The standard skill installation path is:

```
~/.vibe/skills/{skill_name}/{subdirectory}/{filename}
```

#### Examples:

**Before (Problematic):**
```markdown
Load `references/readme-structure.md` for the template.
```

**After (Fixed):**
```markdown
Load `~/.vibe/skills/readme-generator/references/readme-structure.md` for the template.

**Path Resolution Note**: Use absolute path `~/.vibe/skills/readme-generator/references/readme-structure.md` to ensure file loads correctly regardless of current working directory. Fallback: try relative path `references/readme-structure.md` if absolute path fails.
```

### Path Resolution Pattern

For maximum robustness, include a **Path Resolution Note** in your skill instructions:

```markdown
**Path Resolution**: Use absolute path `~/.vibe/skills/{skill_name}/{path}/{filename}` to ensure file loads correctly regardless of current working directory.
Fallback: If absolute path fails, try relative path `{path}/{filename}`.
```

### Implementation Checklist

1. ✅ **Audit all file references** in `SKILL.md` and `README.md`
2. ✅ **Replace relative paths** with absolute paths using `~/.vibe/skills/{skill_name}/...`
3. ✅ **Add Path Resolution Notes** explaining the absolute path and fallback strategy
4. ✅ **Test from multiple directories** to verify paths work correctly
5. ✅ **Document the pattern** in your skill's documentation

### Testing Your Skill

To verify your skill works correctly from any directory:

```bash
# Test from a different directory (e.g., /tmp)
cd /tmp

# Verify the absolute path exists
test -f ~/.vibe/skills/{skill_name}/{path}/{filename} && echo "✓ Path accessible"

# Verify the relative path fails (confirming the problem would exist)
test -f {path}/{filename} && echo "✗ Relative path works (unexpected)" || echo "✓ Relative path correctly fails"
```

### Common Directories for Reference Files

| Directory | Purpose | Example Usage |
|-----------|---------|---------------|
| `references/` | Templates, style guides, documentation | `~/.vibe/skills/readme-generator/references/readme-structure.md` |
| `assets/` | Templates, images, static files | `~/.vibe/skills/architecture-diagram/assets/template.html` |
| `templates/` | Reusable code/templates | `~/.vibe/skills/{name}/templates/{file}` |

### Why This Matters

1. **Portability**: Skills can be invoked from any user project directory
2. **Reliability**: No "File not found" errors due to working directory issues
3. **User Experience**: Skills work consistently regardless of where they're invoked from
4. **Maintainability**: Clear, explicit paths are easier to debug and maintain

### Related Issues

- GitHub Issue: Skills failing with "File not found" when invoked from user projects
- Root Cause: Relative path resolution against wrong working directory
- Solution: Absolute path resolution with fallback strategy

---

*Last updated: 2024*
*See also: [Mistral Vibe Documentation](https://github.com/mistralai/vibe)*
