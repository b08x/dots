# Code-Insights Skill Changelog

## [1.1.0] - 2026-05-17

### Changed
- **Human-Readable Session Exports**: Session directories now use descriptive names instead of UUIDs
  - Format: `{sanitized-title}_{date}_{short-uuid}/`
  - Example: `pdca-guided-recursive-refactor_2026-05-16_cf4bc34/`
  - Improves discoverability and user experience when browsing exports

### Added
- `generate_session_directory()`: Creates human-readable directory names from session titles
- `sanitize_title()`: Cleans session titles for filesystem compatibility
  - Strips XML/HTML tags
  - Removes special characters
  - Handles truncation markers
  - Limits to 50 characters
- `find_session_directory()`: Backward-compatible session lookup by ID
  - Supports both old (UUID-only) and new (name_date_uuid) formats

### Technical Details
- Maintains backward compatibility with existing exports
- Graphify integration fully compatible with new naming
- Session ID preserved in metadata.json for reverse lookups
- Directory structure: `{title}_{YYYY-MM-DD}_{7-char-uuid}/`

### Migration Notes
- Existing UUID-only directories will continue to work
- New exports will use the improved naming scheme
- No action required from users
