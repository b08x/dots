#!/usr/bin/env python3
"""CodeInsights provider for unified session extraction.

Extracts sessions from the code-insights database which aggregates data
from all AI harnesses: Claude Code, Gemini CLI, Hermes, OpenCode, Mistral-Vibe, etc.
"""

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass

# Import shared schema from normalized_sessions
import sys
sys.path.insert(0, str(Path(__file__).parent))

try:
    from normalized_sessions import (
        ParsedSession, ParsedMessage, SessionUsage,
        ToolCall, ToolResult
    )
except ImportError:
    # Fallback if running standalone
    @dataclass
    class SessionUsage:
        total_input_tokens: int = 0
        total_output_tokens: int = 0
        cache_creation_tokens: int = 0
        cache_read_tokens: int = 0
        estimated_cost_usd: float = 0.0
        models_used: List[str] = None
        primary_model: str = "unknown"
        usage_source: str = "session"

        def __post_init__(self):
            if self.models_used is None:
                self.models_used = []

    @dataclass
    class ToolCall:
        id: str
        name: str
        input: Dict[str, Any]

    @dataclass
    class ToolResult:
        tool_use_id: str
        output: str

    @dataclass
    class ParsedMessage:
        id: str
        session_id: str
        type: str
        content: str
        thinking: Optional[str] = None
        tool_calls: List[ToolCall] = None
        tool_results: List[ToolResult] = None
        usage: Optional[Dict[str, Any]] = None
        timestamp: datetime = None
        parent_id: Optional[str] = None

        def __post_init__(self):
            if self.tool_calls is None:
                self.tool_calls = []
            if self.tool_results is None:
                self.tool_results = []

    @dataclass
    class ParsedSession:
        id: str
        project_path: str
        project_name: str
        summary: Optional[str] = None
        generated_title: Optional[str] = None
        title_source: Optional[str] = None
        session_character: Optional[str] = None
        started_at: datetime = None
        ended_at: datetime = None
        message_count: int = 0
        user_message_count: int = 0
        assistant_message_count: int = 0
        tool_call_count: int = 0
        compact_count: int = 0
        auto_compact_count: int = 0
        slash_commands: List[str] = None
        git_branch: Optional[str] = None
        claude_version: Optional[str] = None
        source_tool: str = "unknown"
        usage: SessionUsage = None
        messages: List[ParsedMessage] = None

        def __post_init__(self):
            if self.slash_commands is None:
                self.slash_commands = []
            if self.messages is None:
                self.messages = []
            if self.usage is None:
                self.usage = SessionUsage()


class CodeInsightsProvider:
    """Extract sessions from unified code-insights database.

    The code-insights database aggregates session data from all AI harnesses:
    - claude-code
    - gemini-cli
    - hermes-agent
    - opencode
    - mistral-vibe
    - and more...

    This replaces the need for separate provider classes for each tool.
    """

    def __init__(self, db_path: Optional[str] = None):
        """Initialize provider with database path.

        Args:
            db_path: Path to code-insights database.
                    Defaults to ~/.code-insights/data.db
        """
        if db_path:
            self.db_path = Path(db_path)
        else:
            self.db_path = Path.home() / ".code-insights" / "data.db"

        if not self.db_path.exists():
            raise FileNotFoundError(
                f"Code-insights database not found at {self.db_path}. "
                "Ensure code-insights is installed and has collected session data."
            )

    def discover(self,
                 days: int = 7,
                 source_tools: Optional[List[str]] = None,
                 project_filter: Optional[str] = None) -> List[str]:
        """Discover session IDs matching the criteria.

        Args:
            days: Number of days to look back
            source_tools: Filter by specific tools (e.g., ['claude-code', 'gemini-cli'])
                         If None, returns all tools
            project_filter: Filter by project name or path substring

        Returns:
            List of session IDs in format "source_tool:session_id"
        """
        cutoff = (datetime.now(timezone.utc) -
                 __import__('datetime').timedelta(days=days))
        cutoff_str = cutoff.isoformat()

        conn = sqlite3.connect(f"file:{self.db_path}?mode=ro", uri=True)

        # Build query with optional filters
        query = """
            SELECT id, source_tool
            FROM sessions
            WHERE started_at >= ?
              AND deleted_at IS NULL
        """
        params = [cutoff_str]

        if source_tools:
            placeholders = ",".join("?" * len(source_tools))
            query += f" AND source_tool IN ({placeholders})"
            params.extend(source_tools)

        if project_filter:
            query += " AND (project_name LIKE ? OR project_path LIKE ?)"
            params.extend([f"%{project_filter}%", f"%{project_filter}%"])

        query += " ORDER BY started_at DESC"

        cursor = conn.execute(query, params)
        session_ids = [f"{row[1]}:{row[0]}" for row in cursor.fetchall()]
        conn.close()

        return session_ids

    def parse(self, virtual_path: str) -> Optional[ParsedSession]:
        """Parse a session and its messages from the database.

        Args:
            virtual_path: Session identifier in format "source_tool:session_id"

        Returns:
            ParsedSession with messages, or None if not found
        """
        if ":" not in virtual_path:
            return None

        source_tool, session_id = virtual_path.split(":", 1)

        try:
            conn = sqlite3.connect(f"file:{self.db_path}?mode=ro", uri=True)
            conn.row_factory = sqlite3.Row

            # Get session metadata
            cursor = conn.execute(
                "SELECT * FROM sessions WHERE id = ?", (session_id,)
            )
            session_row = cursor.fetchone()
            if not session_row:
                conn.close()
                return None

            # Get messages
            cursor = conn.execute(
                """SELECT * FROM messages
                   WHERE session_id = ?
                   ORDER BY timestamp ASC""",
                (session_id,)
            )
            message_rows = cursor.fetchall()
            conn.close()

            # Parse messages
            messages = self._parse_messages(message_rows, session_id)

            # Parse timestamps
            started_at = self._parse_timestamp(session_row["started_at"])
            ended_at = self._parse_timestamp(session_row["ended_at"])

            # Helper to safely get values from sqlite3.Row
            def get_value(row, key, default=None):
                return row[key] if key in row.keys() else default

            # Parse JSON fields
            slash_commands = self._parse_json_list(get_value(session_row, "slash_commands"))
            models_used = self._parse_json_list(get_value(session_row, "models_used"))

            # Build SessionUsage
            usage = SessionUsage(
                total_input_tokens=get_value(session_row, "total_input_tokens") or 0,
                total_output_tokens=get_value(session_row, "total_output_tokens") or 0,
                cache_creation_tokens=get_value(session_row, "cache_creation_tokens") or 0,
                cache_read_tokens=get_value(session_row, "cache_read_tokens") or 0,
                estimated_cost_usd=get_value(session_row, "estimated_cost_usd") or 0.0,
                models_used=models_used,
                primary_model=get_value(session_row, "primary_model") or "unknown",
                usage_source=get_value(session_row, "usage_source") or "session"
            )

            # Build ParsedSession
            return ParsedSession(
                id=session_row["id"],
                project_path=session_row["project_path"],
                project_name=session_row["project_name"],
                summary=get_value(session_row, "summary") or get_value(session_row, "generated_title"),
                generated_title=get_value(session_row, "generated_title"),
                title_source=get_value(session_row, "title_source"),
                session_character=get_value(session_row, "session_character"),
                started_at=started_at,
                ended_at=ended_at,
                message_count=get_value(session_row, "message_count") or 0,
                user_message_count=get_value(session_row, "user_message_count") or 0,
                assistant_message_count=get_value(session_row, "assistant_message_count") or 0,
                tool_call_count=get_value(session_row, "tool_call_count") or 0,
                compact_count=get_value(session_row, "compact_count") or 0,
                auto_compact_count=get_value(session_row, "auto_compact_count") or 0,
                slash_commands=slash_commands,
                git_branch=get_value(session_row, "git_branch"),
                claude_version=get_value(session_row, "claude_version"),
                source_tool=session_row["source_tool"],
                usage=usage,
                messages=messages
            )

        except sqlite3.Error as e:
            print(f"  [code-insights] Database error for {session_id}: {e}")
            return None

    def _parse_messages(self,
                       message_rows: List[sqlite3.Row],
                       session_id: str) -> List[ParsedMessage]:
        """Parse message rows into ParsedMessage objects."""
        messages = []

        for row in message_rows:
            # Parse JSON fields - sqlite3.Row uses dict-style access
            tool_calls = self._parse_tool_calls(row["tool_calls"] if "tool_calls" in row.keys() else None)
            tool_results = self._parse_tool_results(row["tool_results"] if "tool_results" in row.keys() else None)
            usage = self._parse_json_dict(row["usage"] if "usage" in row.keys() else None)

            # Parse timestamp
            timestamp = self._parse_timestamp(row["timestamp"])

            messages.append(ParsedMessage(
                id=row["id"],
                session_id=session_id,
                type=row["type"],
                content=row["content"] or "",
                thinking=row["thinking"] if "thinking" in row.keys() else None,
                tool_calls=tool_calls,
                tool_results=tool_results,
                usage=usage,
                timestamp=timestamp,
                parent_id=row["parent_id"] if "parent_id" in row.keys() else None
            ))

        return messages

    def _parse_tool_calls(self, json_str: Optional[str]) -> List[ToolCall]:
        """Parse tool_calls JSON field."""
        if not json_str:
            return []

        try:
            data = json.loads(json_str)
            if not isinstance(data, list):
                return []

            return [
                ToolCall(
                    id=tc.get("id", ""),
                    name=tc.get("name", ""),
                    input=tc.get("input", {})
                )
                for tc in data
            ]
        except (json.JSONDecodeError, KeyError):
            return []

    def _parse_tool_results(self, json_str: Optional[str]) -> List[ToolResult]:
        """Parse tool_results JSON field."""
        if not json_str:
            return []

        try:
            data = json.loads(json_str)
            if not isinstance(data, list):
                return []

            return [
                ToolResult(
                    tool_use_id=tr.get("tool_use_id", ""),
                    output=tr.get("output", "")
                )
                for tr in data
            ]
        except (json.JSONDecodeError, KeyError):
            return []

    def _parse_json_list(self, json_str: Optional[str]) -> List[str]:
        """Parse a JSON array field."""
        if not json_str:
            return []

        try:
            data = json.loads(json_str)
            if isinstance(data, list):
                return data
        except json.JSONDecodeError:
            pass

        return []

    def _parse_json_dict(self, json_str: Optional[str]) -> Optional[Dict]:
        """Parse a JSON object field."""
        if not json_str:
            return None

        try:
            return json.loads(json_str)
        except json.JSONDecodeError:
            return None

    def _parse_timestamp(self, ts_str: Optional[str]) -> Optional[datetime]:
        """Parse ISO8601 timestamp string."""
        if not ts_str:
            return None

        try:
            # Handle both with and without timezone
            if ts_str.endswith('Z'):
                ts_str = ts_str[:-1] + '+00:00'

            dt = datetime.fromisoformat(ts_str)

            # Ensure timezone aware
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)

            return dt
        except (ValueError, AttributeError):
            return None

    def get_available_tools(self) -> List[str]:
        """Get list of all source tools in the database."""
        conn = sqlite3.connect(f"file:{self.db_path}?mode=ro", uri=True)
        cursor = conn.execute(
            "SELECT DISTINCT source_tool FROM sessions ORDER BY source_tool"
        )
        tools = [row[0] for row in cursor.fetchall()]
        conn.close()
        return tools


if __name__ == "__main__":
    # Quick test
    provider = CodeInsightsProvider()
    print(f"Database: {provider.db_path}")
    print(f"Available tools: {provider.get_available_tools()}")

    sessions = provider.discover(days=7)
    print(f"\nFound {len(sessions)} sessions in last 7 days")

    if sessions:
        print("\nSample session:")
        session = provider.parse(sessions[0])
        if session:
            print(f"  ID: {session.id}")
            print(f"  Tool: {session.source_tool}")
            print(f"  Project: {session.project_name}")
            print(f"  Started: {session.started_at}")
            print(f"  Messages: {session.message_count}")
            print(f"  Summary: {session.summary}")
