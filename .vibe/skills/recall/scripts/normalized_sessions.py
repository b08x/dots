#!/usr/bin/env python3
"""Normalized session extraction with DSPy-powered structured outputs.

This module provides:
1. Unified ParsedSession schema across all providers
2. Fixed Gemini path discovery (~/.gemini/tmp/<hash>/chats/*.json)
3. Direct SQLite access for Hermes (no CLI dependency)
4. DSPy signatures for cross-context correlation
5. Multi-source timeline generation (sessions + gh + restic)

Usage:
    python3 normalized_sessions.py extract --days 7 --platforms claude,hermes,gemini
    python3 normalized_sessions.py correlate --days 7 --github-repo owner/repo
    python3 normalized_sessions.py search "authentication work" --days 30
"""

try:
    import dspy
    DSPY_AVAILABLE = True
except ImportError:
    DSPY_AVAILABLE = False

import json
import sqlite3
import glob
import os
import re
import subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any, Literal, Union
from dataclasses import dataclass, asdict
from collections import defaultdict

# =============================================================================
# DSPY CONFIGURATION - Environment Variables
# =============================================================================

DSPY_PROVIDER = os.environ.get('RECALL_DSPY_PROVIDER', 'openrouter')
DSPY_MODEL = os.environ.get('RECALL_DSPY_MODEL', 'openai/gpt-4.1-nano')


# =============================================================================
# NORMALIZED SCHEMA (matches TypeScript ParsedSession)
# =============================================================================

@dataclass
class SessionUsage:
    """Unified usage metrics across providers."""
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    cache_creation_tokens: int = 0
    cache_read_tokens: int = 0
    estimated_cost_usd: float = 0.0
    models_used: List[str] = None
    primary_model: str = "unknown"
    usage_source: str = "session"  # 'session' | 'message'

    def __post_init__(self):
        if self.models_used is None:
            self.models_used = []


@dataclass
class ToolCall:
    """Unified tool call structure."""
    id: str
    name: str
    input: Dict[str, Any]


@dataclass  
class ToolResult:
    """Unified tool result structure."""
    tool_use_id: str
    output: str


@dataclass
class ParsedMessage:
    """Unified message structure."""
    id: str
    session_id: str
    type: Literal['user', 'assistant', 'system']
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
class ParsedNote:
    """Unified structure for notes (e.g., Obsidian)."""
    id: str
    title: str
    path: str
    content: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    tags: List[str] = None
    source: str = "obsidian"

    def __post_init__(self):
        if self.tags is None:
            self.tags = []


@dataclass
class ParsedSession:
    """Unified session schema matching TypeScript implementation."""
    id: str
    project_path: str
    project_name: str
    summary: Optional[str] = None
    generated_title: Optional[str] = None
    title_source: Optional[str] = None  # 'insight' | 'first_message'
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


# =============================================================================
# DSPY SIGNATURES FOR CORRELATION
# =============================================================================

# Only define DSPy signatures if dspy is available
if DSPY_AVAILABLE:
    class SessionTopicExtractor(dspy.Signature):
        """Extract primary topics and activities from session content.
        
        Analyzes session messages to identify the main areas of work,
        files that were touched, and key actions taken during the session.
        """
        
        session_content: str = dspy.InputField(desc="Combined text content from session messages, truncated to key exchanges")
        topics: List[str] = dspy.OutputField(desc="List of 3-5 main topics/activities in the session, prioritized by time spent")
        files_touched: List[str] = dspy.OutputField(desc="File paths mentioned or modified during the session")
        key_actions: List[str] = dspy.OutputField(desc="Key actions taken (commits, edits, tests run, bugs fixed)")


    class CommitSessionCorrelator(dspy.Signature):
        """Correlate a git commit with the most relevant session(s).
        
        Uses commit message and changed files to find sessions that likely
        relate to this commit, enabling temporal correlation of work.
        """
        
        commit_message: str = dspy.InputField(desc="Git commit message")
        commit_files: List[str] = dspy.InputField(desc="Files changed in commit")
        session_summaries: List[str] = dspy.InputField(desc="List of session summaries to compare against, each with platform and title")
        relevant_session_indices: List[int] = dspy.OutputField(desc="Indices of most relevant sessions (0-based)")
        confidence_scores: List[float] = dspy.OutputField(desc="Confidence scores (0.0-1.0) for each match")


    class TimelineSynthesizer(dspy.Signature):
        """Synthesize a coherent narrative from multiple data sources.
        
        Combines sessions from multiple AI platforms, GitHub commits,
        and file changes into a unified timeline with actionable insights.
        
        STRICT REQUIREMENT: Identify workstreams ONLY if backed by a commit,
        multiple file changes, or substantial session content in the current window.
        Do NOT hype new directories or untracked artifacts (??) as "Initiatives."
        """
        
        sessions: List[Dict] = dspy.InputField(desc="List of session data with platform, summary, and timestamp")
        commits: List[Dict] = dspy.InputField(desc="List of git commits with message and sha")
        file_changes: List[Dict] = dspy.InputField(desc="List of file changes from backup analysis")
        narrative: str = dspy.OutputField(desc="Coherent narrative of activities (2-3 sentences per platform). Focus on kinetic energy (work done), not potential (new folders).")
        workstreams: List[str] = dspy.OutputField(desc="Distinct workstreams identified. MUST be backed by session volume or commits. Label untracked folders as 'Untracked Artifacts'.")
        next_actions: List[str] = dspy.OutputField(desc="Suggested next actions, specific and actionable. Derived from current momentum.")


    class OneThingGenerator(dspy.Signature):
        """Generate the single highest-leverage next action.
        
        Analyzes recent activity across platforms to determine the one
        action that would provide the most value given current momentum.
        """
        
        recent_activity: str = dspy.InputField(desc="Summary of recent work across platforms (3-5 sentences)")
        workstreams: List[str] = dspy.InputField(desc="Active workstreams identified")
        open_questions: List[str] = dspy.InputField(desc="Unresolved questions or blockers (empty list if none)")
        one_thing: str = dspy.OutputField(desc="Single most important next action (specific, actionable, complete sentence)")
        reasoning: str = dspy.OutputField(desc="Why this action is highest leverage (1-2 sentences)")
    
    # =========================================================================
    # DSPy MODULES (Following Best Practices)
    # =========================================================================
    
    class SessionAnalysisModule(dspy.Module):
        """Analyze sessions to extract topics and actions."""
        
        def __init__(self):
            super().__init__()
            self.extract_topics = dspy.ChainOfThought(SessionTopicExtractor)
        
        def forward(self, session_content: str):
            return self.extract_topics(session_content=session_content)
    
    
    class CorrelationModule(dspy.Module):
        """Multi-stage correlation pipeline."""
        
        def __init__(self):
            super().__init__()
            self.correlate_commits = dspy.Predict(CommitSessionCorrelator)
            self.synthesize = dspy.ChainOfThought(TimelineSynthesizer)
            self.one_thing = dspy.ChainOfThought(OneThingGenerator)
        
        def forward(self, sessions: List[Dict], commits: List[Dict], file_changes: List[Dict]):
            # Stage 1: Synthesize timeline
            timeline_result = self.synthesize(
                sessions=sessions,
                commits=commits,
                file_changes=file_changes
            )
            
            # Stage 2: Generate One Thing
            one_thing_result = self.one_thing(
                recent_activity=timeline_result.narrative,
                workstreams=timeline_result.workstreams,
                open_questions=[]  # Could be extracted from session analysis
            )
            
            return dspy.Prediction(
                narrative=timeline_result.narrative,
                workstreams=timeline_result.workstreams,
                next_actions=timeline_result.next_actions,
                one_thing=one_thing_result.one_thing,
                one_thing_reasoning=one_thing_result.reasoning
            )
    
    # Module instances (initialized when needed)
    def get_dspy_modules():
        """Factory function for DSPy modules with lazy initialization."""
        return {
            'session_analyzer': SessionAnalysisModule(),
            'correlator': CorrelationModule()
        }

else:
    # Placeholder classes when dspy is not available
    SessionTopicExtractor = None
    CommitSessionCorrelator = None
    TimelineSynthesizer = None
    OneThingGenerator = None
    SessionAnalysisModule = None
    CorrelationModule = None
    
    def get_dspy_modules():
        return {}


# =============================================================================
# PROVIDER EXTRACTION CLASSES
# =============================================================================

# Import unified CodeInsightsProvider
from code_insights_provider import CodeInsightsProvider

# Old providers (GeminiProvider, HermesProvider, ClaudeCodeProvider, OpenCodeProvider)
# have been replaced by CodeInsightsProvider which reads from the unified
# code-insights database at ~/.code-insights/data.db

# ObsidianProvider and LocalGitProvider remain as they provide different data types.

class ObsidianProvider:
    """Extract notes from an Obsidian notebook at ~/Notebook."""
    
    def __init__(self, notebook_path: str = "~/Notebook"):
        self.notebook_path = Path(notebook_path).expanduser()
    
    def discover(self, days: int = 7) -> List[Path]:
        """Discover markdown files modified in the last N days."""
        if not self.notebook_path.exists():
            return []
        
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)
        notes = []
        
        for md_file in self.notebook_path.rglob("*.md"):
            # Skip hidden directories like .obsidian
            if any(part.startswith(".") for part in md_file.parts):
                continue
                
            mtime = datetime.fromtimestamp(md_file.stat().st_mtime, tz=timezone.utc)
            if mtime >= cutoff:
                notes.append(md_file)
        
        return notes
    
    def parse(self, filepath: Path) -> Optional[ParsedNote]:
        """Parse an Obsidian markdown file into a ParsedNote."""
        try:
            content = filepath.read_text()
            
            # Simple YAML frontmatter parsing
            tags = []
            title = filepath.stem
            
            frontmatter_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
            if frontmatter_match:
                frontmatter_text = frontmatter_match.group(1)
                for line in frontmatter_text.split('\n'):
                    if line.startswith('tags:'):
                        # Simple tag extraction
                        tag_str = line.replace('tags:', '').strip()
                        tags = [t.strip().strip('[]"\'') for t in re.split(r'[,\s]+', tag_str) if t.strip()]
                    elif line.startswith('title:'):
                        title = line.replace('title:', '').strip().strip('"\'')
            
            # Extract tags from content (#tag)
            content_tags = re.findall(r'#([\w/-]+)', content)
            tags.extend(content_tags)
            
            # Times
            mtime = datetime.fromtimestamp(filepath.stat().st_mtime, tz=timezone.utc)
            ctime = datetime.fromtimestamp(filepath.stat().st_ctime, tz=timezone.utc)
            
            return ParsedNote(
                id=str(filepath.relative_to(self.notebook_path)),
                title=title,
                path=str(filepath),
                content=content,
                created_at=ctime,
                updated_at=mtime,
                tags=list(set(tags)),
                source="obsidian"
            )
        except Exception as e:
            print(f"  [obsidian] Parse error {filepath}: {e}")
            return None


class LocalGitProvider:
    """Extract git activity from all repositories in ~/Workspace."""
    
    def __init__(self, workspace_path: str = "~/Workspace"):
        self.workspace_path = Path(workspace_path).expanduser()
    
    def discover(self) -> List[Path]:
        """Discover all git repositories in the workspace."""
        if not self.workspace_path.exists():
            return []
            
        repos = []
        # Look for .git directories up to 2 levels deep
        for entry in self.workspace_path.iterdir():
            if entry.is_dir():
                if (entry / ".git").exists():
                    repos.append(entry)
                else:
                    # Check one level deeper
                    try:
                        for subentry in entry.iterdir():
                            if subentry.is_dir() and (subentry / ".git").exists():
                                repos.append(subentry)
                    except PermissionError:
                        continue
        return repos
    
    def extract_commits(self, repo_path: Path, days: int = 7) -> List[Dict]:
        """Extract commits from a specific repository."""
        since = (datetime.now(timezone.utc) - timedelta(days=days)).strftime('%Y-%m-%d %H:%M:%S')
        
        cmd = [
            "git", "-C", str(repo_path), "log", 
            f"--since={since}", 
            "--pretty=format:{\"sha\":\"%h\",\"message\":\"%s\",\"date\":\"%ad\",\"author\":\"%an\"}", 
            "--date=iso"
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            commits = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    try:
                        commit = json.loads(line)
                        commit['repo'] = repo_path.name
                        commits.append(commit)
                    except json.JSONDecodeError:
                        continue
            return commits
        except subprocess.CalledProcessError:
            return []


# =============================================================================
# MULTI-SOURCE CORRELATION
# =============================================================================

class MultiSourceCorrelator:
    """Correlate sessions with git commits, restic backups, and notebook changes.

    Uses the unified code-insights database for all AI harness sessions.
    """

    def __init__(self, notebook_path: str = "~/Notebook", workspace_path: str = "~/Workspace"):
        # Unified provider for all AI harnesses
        try:
            self.code_insights = CodeInsightsProvider()
            self.available_tools = self.code_insights.get_available_tools()
        except FileNotFoundError as e:
            print(f"Warning: {e}")
            self.code_insights = None
            self.available_tools = []

        # Keep specialized providers for different data types
        self.obsidian = ObsidianProvider(notebook_path)
        self.local_git = LocalGitProvider(workspace_path)
    
    def extract_all(self, days: int = 7,
                    platforms: Optional[List[str]] = None) -> Dict[str, List[Any]]:
        """Extract sessions and notes from all platforms.

        Args:
            days: Number of days to look back
            platforms: List of platforms to extract from.
                      Use source tool names (e.g., ['claude-code', 'gemini-cli'])
                      or 'all' for all available tools, or None for default
                      Special: 'obsidian' for notes

        Returns:
            Dict mapping platform names to lists of sessions/notes
        """
        results = {}

        # Default platforms: all available tools + obsidian
        if platforms is None:
            platforms = self.available_tools + ["obsidian"]
        elif "all" in platforms:
            platforms = self.available_tools + ["obsidian"]

        # Extract Obsidian notes if requested
        if "obsidian" in platforms:
            files = self.obsidian.discover(days)
            notes = []
            for filepath in files:
                note = self.obsidian.parse(filepath)
                if note:
                    notes.append(note)
            results["obsidian"] = notes
            print(f"  [obsidian] Extracted {len(notes)} notes")

        # Extract AI harness sessions from code-insights
        session_platforms = [p for p in platforms if p != "obsidian"]

        if session_platforms and self.code_insights:
            # Discover sessions from code-insights
            virtual_paths = self.code_insights.discover(
                days=days,
                source_tools=session_platforms if session_platforms != self.available_tools else None
            )

            # Group by source tool
            sessions_by_tool = defaultdict(list)

            for virtual_path in virtual_paths:
                session = self.code_insights.parse(virtual_path)
                if session:
                    sessions_by_tool[session.source_tool].append(session)

            # Add to results
            for tool, sessions in sessions_by_tool.items():
                results[tool] = sessions
                print(f"  [{tool}] Extracted {len(sessions)} sessions")

        return results
    
    def fetch_local_git_data(self, days: int = 7) -> List[Dict]:
        """Fetch commits from all repositories in the workspace."""
        repos = self.local_git.discover()
        all_commits = []
        for repo in repos:
            commits = self.local_git.extract_commits(repo, days)
            all_commits.extend(commits)
        
        print(f"  [git] Extracted {len(all_commits)} commits from {len(repos)} repos")
        return all_commits

    def auto_discover_repos(self, days: int = 7) -> List[str]:
        """Auto-discover GitHub repos with recent user activity.

        Uses gh search commits to find all repos where the authenticated
        user has commits within the specified timeframe.

        Args:
            days: Number of days to look back

        Returns:
            List of repo full names in owner/name format
        """
        # Check gh CLI availability
        result = subprocess.run(["gh", "--version"], capture_output=True)
        if result.returncode != 0:
            print("  [github] gh CLI not available, skipping auto-discovery")
            return []

        # Get authenticated user
        try:
            user_result = subprocess.run([
                "gh", "api", "user", "--jq", ".login"
            ], capture_output=True, text=True)

            if user_result.returncode != 0:
                print("  [github] Failed to get authenticated user")
                return []

            username = user_result.stdout.strip()
        except Exception as e:
            print(f"  [github] Error getting user: {e}")
            return []

        # Calculate date threshold
        since_date = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")

        # Search for commits by this user
        try:
            result = subprocess.run([
                "gh", "search", "commits",
                f"--author={username}",
                f"--author-date=>={since_date}",
                "--json", "repository",
                "--limit", "1000"  # GitHub API limit
            ], capture_output=True, text=True)

            if result.returncode != 0:
                print(f"  [github] Commit search failed: {result.stderr}")
                return []

            # Extract unique repo names
            data = json.loads(result.stdout)
            repos = sorted(set(item["repository"]["fullName"] for item in data))

            if repos:
                print(f"  [github] Auto-discovered {len(repos)} repos with activity")
                for repo in repos:
                    print(f"    • {repo}")
            else:
                print(f"  [github] No repos found with commits in last {days} days")

            return repos

        except json.JSONDecodeError as e:
            print(f"  [github] JSON parse error: {e}")
            return []
        except Exception as e:
            print(f"  [github] Search error: {e}")
            return []

    def fetch_github_data(self, repos: Union[str, List[str], None] = None, days: int = 7, auto_discover: bool = False) -> Dict:
        """Fetch GitHub commits and PRs from one or more repos.

        Args:
            repos: Single repo (str), list of repos (List[str]), or None for auto-discovery
            days: Number of days to look back
            auto_discover: If True and repos is None, auto-discover repos with activity

        Returns:
            Dict with commits and pull_requests lists
        """
        since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

        # Check gh CLI
        result = subprocess.run(["gh", "--version"], capture_output=True)
        if result.returncode != 0:
            return {"commits": [], "pull_requests": []}

        # Determine repo list
        repo_list = []
        if repos is None and auto_discover:
            repo_list = self.auto_discover_repos(days)
        elif repos is None:
            return {"commits": [], "pull_requests": []}
        elif isinstance(repos, str):
            repo_list = [repos]
        else:
            repo_list = repos

        if not repo_list:
            return {"commits": [], "pull_requests": []}

        # Fetch commits from all repos
        all_commits = []
        for repo in repo_list:
            try:
                result = subprocess.run([
                    "gh", "api", f"repos/{repo}/commits",
                    "--method", "GET",
                    "--field", f"since={since}Z",
                    "--jq", ".[] | {sha: .sha[0:7], message: .commit.message, date: .commit.author.date, author: .commit.author.name, repo: \"" + repo + "\"}"
                ], capture_output=True, text=True)

                if result.returncode == 0:
                    for line in result.stdout.strip().split("\n"):
                        if line:
                            try:
                                commit = json.loads(line)
                                all_commits.append(commit)
                            except json.JSONDecodeError:
                                pass
            except Exception as e:
                print(f"  [github] Error fetching {repo}: {e}")
                continue

        if all_commits:
            print(f"  [github] Fetched {len(all_commits)} commits from {len(repo_list)} repos")

        return {"commits": all_commits, "pull_requests": []}
    
    def build_timeline(self, sessions: Dict[str, List[Any]],
                       github_data: Optional[Dict] = None,
                       local_commits: Optional[List[Dict]] = None) -> List[Dict]:
        """Build unified timeline from all sources."""
        timeline = []
        
        # Add all sessions and notes
        for platform, items in sessions.items():
            for item in items:
                if platform == "obsidian":
                    timeline.append({
                        "type": "note",
                        "platform": "obsidian",
                        "timestamp": item.updated_at,
                        "data": asdict(item),
                        "summary": f"Note: {item.title}"
                    })
                else:
                    timeline.append({
                        "type": "session",
                        "platform": platform,
                        "timestamp": item.started_at,
                        "data": asdict(item),
                        "summary": item.generated_title or f"{platform} session"
                    })
        
        # Add GitHub commits
        if github_data:
            for commit in github_data.get("commits", []):
                try:
                    ts = datetime.fromisoformat(commit["date"].replace("Z", "+00:00"))
                except (KeyError, ValueError):
                    ts = datetime.now(timezone.utc)
                
                timeline.append({
                    "type": "commit",
                    "platform": "github",
                    "timestamp": ts,
                    "data": commit,
                    "summary": f"GitHub Commit: {commit.get('message', '').split('\n')[0][:60]}"
                })
        
        # Add Local Git commits
        if local_commits:
            for commit in local_commits:
                try:
                    # git log date is usually iso format
                    ts = datetime.fromisoformat(commit["date"])
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=timezone.utc)
                except (KeyError, ValueError):
                    ts = datetime.now(timezone.utc)
                
                timeline.append({
                    "type": "commit",
                    "platform": f"git:{commit.get('repo', 'local')}",
                    "timestamp": ts,
                    "data": commit,
                    "summary": f"Local Commit: {commit.get('message', '').split('\n')[0][:60]}"
                })
        
        # Sort by timestamp
        return sorted(timeline, key=lambda x: x.get("timestamp") or datetime.min.replace(tzinfo=timezone.utc))
    
    def configure_dspy(self, model: Optional[str] = None, api_key: Optional[str] = None):
        """Configure DSPy with specified language model.
        
        Uses RECALL_DSPY_PROVIDER and RECALL_DSPY_MODEL environment variables
        as defaults. Falls back to openrouter/openai/gpt-4.1-nano if not set.
        
        Args:
            model: Model identifier. If None, uses RECALL_DSPY_MODEL env var.
                   Format: "<provider>/<model>" (e.g., "openai/gpt-4.1-nano")
            api_key: Optional API key (will use env var if not provided)
        
        Returns:
            True if configuration succeeded, False otherwise
        """
        if not DSPY_AVAILABLE:
            return False
        
        # Use env vars as defaults
        provider = DSPY_PROVIDER
        model_id = model or DSPY_MODEL
        
        try:
            # Handle OpenRouter provider
            if provider == 'openrouter':
                api_key = api_key or os.environ.get('OPENROUTER_API_KEY')
                if not api_key:
                    print("  [dspy] OPENROUTER_API_KEY not set")
                    return False
                
                # Format: openrouter/<model-id> where model-id includes provider
                # e.g., "openrouter/openai/gpt-4.1-nano"
                lm = dspy.LM(
                    f"openrouter/{model_id}",
                    api_key=api_key,
                    base_url="https://openrouter.ai/api/v1"
                )
            
            # Handle OpenAI provider directly
            elif provider == 'openai':
                api_key = api_key or os.environ.get('OPENAI_API_KEY')
                if not api_key:
                    print("  [dspy] OPENAI_API_KEY not set")
                    return False
                lm = dspy.LM(model_id, api_key=api_key)
            
            # Handle Anthropic provider
            elif provider == 'anthropic':
                api_key = api_key or os.environ.get('ANTHROPIC_API_KEY')
                if not api_key:
                    print("  [dspy] ANTHROPIC_API_KEY not set")
                    return False
                lm = dspy.LM(model_id, api_key=api_key)
            
            # Handle local Ollama
            elif provider == 'ollama':
                _, model_name = model_id.split("/", 1) if "/" in model_id else ("", model_id)
                lm = dspy.LM(f"ollama_chat/{model_name}")
            
            # Generic fallback
            else:
                api_key = api_key or os.environ.get(f"{provider.upper()}_API_KEY")
                lm = dspy.LM(f"{provider}/{model_id}", api_key=api_key)
            
            dspy.configure(lm=lm)
            return True
        except Exception as e:
            print(f"  [dspy] Configuration error: {e}")
            return False
    
    def correlate_with_dspy(self, timeline: List[Dict], model: Optional[str] = None) -> Dict:
        """Use DSPy to generate correlated narrative and next actions.
        
        Multi-stage pipeline:
        1. Configure LM with specified model (or env var default)
        2. Synthesize timeline from sessions + commits + file changes
        3. Generate One Thing recommendation
        
        Args:
            timeline: List of timeline events (sessions, commits, file changes)
            model: DSPy-compatible model identifier
        
        Returns:
            Dict with narrative, workstreams, next_actions, one_thing
        """
        if not DSPY_AVAILABLE:
            return self._heuristic_correlation(timeline)
        
        # Configure DSPy
        if not self.configure_dspy(model):
            return self._heuristic_correlation(timeline)
        
        # Prepare input data (limit to prevent context overflow)
        sessions = [
            {
                "platform": t["platform"],
                "type": t["type"],
                "summary": t.get("summary", "Untitled"),
                "timestamp": t.get("timestamp", "").isoformat() if hasattr(t.get("timestamp"), "isoformat") else str(t.get("timestamp", ""))
            }
            for t in timeline if t["type"] in ["session", "note"]
        ][:15]
        
        commits = [
            {
                "message": t["data"].get("message", "").split("\n")[0][:100],
                "sha": t["data"].get("sha", "")[:8]
            }
            for t in timeline if t["type"] == "commit"
        ][:10]
        
        file_changes = []  # TODO: Integrate restic backup analysis
        
        # Get DSPy modules
        modules = get_dspy_modules()
        correlator = modules.get('correlator')
        
        if not correlator:
            return self._heuristic_correlation(timeline)
        
        try:
            # Run correlation pipeline
            result = correlator(
                sessions=sessions,
                commits=commits,
                file_changes=file_changes
            )
            
            return {
                "narrative": result.narrative,
                "workstreams": result.workstreams,
                "next_actions": result.next_actions,
                "one_thing": result.one_thing,
                "one_thing_reasoning": result.one_thing_reasoning
            }
        except Exception as e:
            print(f"  [dspy] Pipeline error: {e}")
            return self._heuristic_correlation(timeline)
    
    def _heuristic_correlation(self, timeline: List[Dict]) -> Dict:
        """Fallback heuristic-based correlation."""
        sessions = [t for t in timeline if t["type"] == "session"]
        platforms = set(s["platform"] for s in sessions)
        
        # Extract topics from summaries
        topics = defaultdict(int)
        for s in sessions:
            for word in s["summary"].lower().split():
                if len(word) > 4 and word.isalpha():
                    topics[word] += 1
        
        top_topics = sorted(topics.items(), key=lambda x: -x[1])[:5]
        
        return {
            "narrative": f"Activity across {len(platforms)} platforms: {', '.join(platforms)}",
            "workstreams": [t[0] for t in top_topics[:3]],
            "next_actions": [f"Continue {top_topics[0][0]} work" if top_topics else "Review recent sessions"]
        }


# =============================================================================
# CLI INTERFACE
# =============================================================================

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Normalized session extraction with DSPy correlation")
    sub = parser.add_subparsers(dest="command", required=True)
    
    # Extract command
    p_extract = sub.add_parser("extract", help="Extract sessions from platforms")
    p_extract.add_argument("--days", type=int, default=7, help="Days to extract")
    p_extract.add_argument("--platforms", help="Comma-separated source tools (claude-code,gemini-cli,hermes-agent,mistral-vibe,opencode) or 'all'")
    p_extract.add_argument("--output", help="Output JSON file")
    
    # Correlate command
    p_correlate = sub.add_parser("correlate", help="Correlate sessions with GitHub and generate timeline")
    p_correlate.add_argument("--days", type=int, default=7)
    p_correlate.add_argument("--github-repo", help="GitHub repo (owner/name) - if not specified, auto-discovers repos with activity")
    p_correlate.add_argument("--no-github", action="store_true",
                              help="Skip GitHub correlation entirely (no auto-discovery)")
    p_correlate.add_argument("--model", default="openai/gpt-4o-mini",
                              help="DSPy model (default: openai/gpt-4o-mini)")
    p_correlate.add_argument("--output", help="Output JSON file")
    
    # Search command
    p_search = sub.add_parser("search", help="Search sessions by topic")
    p_search.add_argument("query", help="Search query")
    p_search.add_argument("--days", type=int, default=30)
    p_search.add_argument("--platforms", help="Comma-separated platforms")
    
    args = parser.parse_args()
    
    correlator = MultiSourceCorrelator()
    
    def serialize_message(msg):
        """Convert message to JSON-serializable dict."""
        if hasattr(msg, '__dataclass_fields__'):
            data = asdict(msg)
        else:
            data = dict(msg) if isinstance(msg, dict) else {'content': str(msg)}
        
        if data.get('timestamp'):
            data['timestamp'] = data['timestamp'].isoformat() if hasattr(data['timestamp'], 'isoformat') else str(data['timestamp'])
        
        # Handle tool_calls and tool_results
        if data.get('tool_calls'):
            data['tool_calls'] = [asdict(tc) if hasattr(tc, '__dataclass_fields__') else tc for tc in data['tool_calls']]
        if data.get('tool_results'):
            data['tool_results'] = [asdict(tr) if hasattr(tr, '__dataclass_fields__') else tr for tr in data['tool_results']]
        
        return data
    
    def serialize_item(item):
        """Convert session or note to JSON-serializable dict."""
        data = asdict(item)
        # Handle datetime fields
        for field in ['started_at', 'ended_at', 'created_at', 'updated_at']:
            if data.get(field) and hasattr(data[field], 'isoformat'):
                data[field] = data[field].isoformat()
        
        if 'messages' in data:
            data['messages'] = [serialize_message(m) for m in (data.get('messages') or [])]
        
        return data
    
    if args.command == "extract":
        platforms = args.platforms.split(",") if args.platforms else None
        results = correlator.extract_all(args.days, platforms)
        
        # Convert to serializable format
        output = {}
        for platform, items in results.items():
            output[platform] = [serialize_item(s) for s in items]
        
        if args.output:
            with open(args.output, "w") as f:
                json.dump(output, f, indent=2)
            print(f"\n✓ Saved to {args.output}")
        else:
            print(json.dumps(output, indent=2))
    
    elif args.command == "correlate":
        sessions = correlator.extract_all(args.days)
        
        github_data = None
        if args.github_repo:
            print(f"\n Fetching GitHub data for {args.github_repo}...")
            github_data = correlator.fetch_github_data(repos=args.github_repo, days=args.days)
            print(f"   Found {len(github_data['commits'])} commits")
        elif not getattr(args, 'no_github', False):
            # Auto-discover repos with activity
            print(f"\n Auto-discovering GitHub repos with activity...")
            github_data = correlator.fetch_github_data(repos=None, days=args.days, auto_discover=True)
            if github_data['commits']:
                print(f"   Found {len(github_data['commits'])} commits")
            
        print(f"\n Fetching local git data...")
        local_commits = correlator.fetch_local_git_data(args.days)
        
        timeline = correlator.build_timeline(sessions, github_data, local_commits)
        
        print(f"\n correlating {len(timeline)} events...")
        result = correlator.correlate_with_dspy(timeline, model=args.model)
        
        print(f"\n{'='*60}")
        print(result["narrative"])
        print(f"\n Workstreams: {', '.join(result['workstreams'])}")
        print(f"\n Next Actions:")
        for action in result["next_actions"]:
            print(f"   • {action}")
        
        if result.get("one_thing"):
            print(f"\n ONE THING: {result['one_thing']}")
            if result.get("one_thing_reasoning"):
                print(f" Reasoning: {result['one_thing_reasoning']}")
        
        if args.output:
            # Recursively serialize any datetime objects
            def serialize_value(v):
                if hasattr(v, 'isoformat'):
                    return v.isoformat()
                elif isinstance(v, dict):
                    return {k2: serialize_value(v2) for k2, v2 in v.items()}
                elif isinstance(v, list):
                    return [serialize_value(item) for item in v]
                else:
                    return v
            
            def serialize_timeline_event(event):
                return {k: serialize_value(v) for k, v in event.items()}
            
            with open(args.output, "w") as f:
                json.dump({
                    "timeline": [serialize_timeline_event(t) for t in timeline],
                    "correlation": result
                }, f, indent=2)
            print(f"\n✓ Saved to {args.output}")
    
    elif args.command == "search":
        platforms = args.platforms.split(",") if args.platforms else None
        sessions = correlator.extract_all(args.days, platforms)
        
        # Simple keyword search
        results = []
        query_lower = args.query.lower()
        
        for platform, platform_sessions in sessions.items():
            for session in platform_sessions:
                # Search in title and message content
                title_match = session.generated_title and query_lower in session.generated_title.lower()
                content_match = any(
                    query_lower in m.content.lower() 
                    for m in session.messages
                )
                
                if title_match or content_match:
                    results.append({
                        "platform": platform,
                        "session_id": session.id,
                        "title": session.generated_title or "Untitled",
                        "started_at": session.started_at.isoformat() if session.started_at else None,
                        "message_count": session.message_count
                    })
        
        print(f"\n Found {len(results)} matching sessions")
        for r in results[:20]:
            print(f"  [{r['platform']}] {r['title'][:50]} ({r['message_count']} msgs)")


if __name__ == "__main__":
    main()
