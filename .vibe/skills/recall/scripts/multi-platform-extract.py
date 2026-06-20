#!/usr/bin/env python3
"""Multi-platform session extraction for recall skill.

Extracts sessions from Claude Code, Hermes, Gemini CLI, and OpenCode,
with optional GitHub and restic backup integration.

Usage:
    python3 multi-platform-extract.py [options] [query]

Examples:
    python3 multi-platform-extract.py yesterday
    python3 multi-platform-extract.py --platform hermes auth work
    python3 multi-platform-extract.py --github myrepo --backup ~/Workspace last week
"""

import argparse
import json
import glob
import os
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any


class MultiPlatformExtractor:
    """Extract sessions from multiple AI platforms with correlation."""

    # Decision thresholds for ck-search indexing
    SESSION_SIZE_ESTIMATE_KB = 2  # Avg session size estimate
    LARGE_SESSION_COUNT = 50       # Above this → auto-index
    LONG_DATE_RANGE_DAYS = 7       # Above this → auto-index
    TOPIC_SEARCH_THRESHOLD = 3     # Below this many words, treat as topic

    def __init__(self):
        self.platforms = ['claude', 'hermes', 'gemini', 'opencode', 'obsidian', 'workspace']
        # Use CWD instead of home to avoid sandbox /tmp trap
        self.default_index_dir = Path.cwd() / '.recall-index'

    def extract_sessions(self, platforms: List[str], date_range: Dict,
                        topic: Optional[str] = None) -> Dict[str, List[Dict]]:
        """Extract sessions and notes from specified platforms."""
        results = {}

        for platform in platforms:
            try:
                if platform == 'workspace':
                    # Special case for local workspace git activity
                    commits = self._extract_workspace_commits(date_range)
                    results['workspace'] = commits
                    print(f"✓ {platform}: {len(commits)} commits")
                else:
                    sessions = self._extract_platform_sessions(platform, date_range, topic)
                    results[platform] = sessions
                    print(f"✓ {platform}: {len(sessions)} sessions/notes")
            except Exception as e:
                print(f"✗ {platform}: {str(e)}")
                results[platform] = []

        return results

    def _extract_platform_sessions(self, platform: str, date_range: Dict,
                                 topic: Optional[str]) -> List[Dict]:
        """Extract sessions from specific platform."""
        extractors = {
            'claude': self._extract_claude_sessions,
            'hermes': self._extract_hermes_sessions,
            'gemini': self._extract_gemini_sessions,
            'opencode': self._extract_opencode_sessions,
            'obsidian': self._extract_obsidian_notes
        }

        if platform not in extractors:
            raise ValueError(f"Unsupported platform: {platform}")

        sessions = extractors[platform](date_range)

        if topic:
            sessions = self._filter_by_topic(sessions, topic)

        return sessions

    def _extract_obsidian_notes(self, date_range: Dict) -> List[Dict]:
        """Extract notes from Obsidian notebook."""
        notebook_path = Path("~/Notebook").expanduser()
        if not notebook_path.exists():
            return []
            
        notes = []
        for md_file in notebook_path.rglob("*.md"):
            if any(part.startswith(".") for part in md_file.parts):
                continue
                
            mtime = datetime.fromtimestamp(md_file.stat().st_mtime, tz=timezone.utc)
            if date_range['start'] <= mtime <= date_range['end']:
                try:
                    content = md_file.read_text()
                    notes.append({
                        'platform': 'obsidian',
                        'session_id': str(md_file.relative_to(notebook_path)),
                        'title': md_file.stem,
                        'content': content,
                        'timestamp': mtime.isoformat(),
                        'file_path': str(md_file)
                    })
                except Exception:
                    continue
        return notes

    def _extract_workspace_commits(self, date_range: Dict) -> List[Dict]:
        """Extract git commits from all repositories in ~/Workspace."""
        workspace_path = Path("~/Workspace").expanduser()
        if not workspace_path.exists():
            return []
            
        since = date_range['start'].strftime('%Y-%m-%d %H:%M:%S')
        all_commits = []
        
        # Look for .git directories up to 2 levels deep
        repos = []
        for entry in workspace_path.iterdir():
            if entry.is_dir():
                if (entry / ".git").exists():
                    repos.append(entry)
                else:
                    try:
                        for subentry in entry.iterdir():
                            if subentry.is_dir() and (subentry / ".git").exists():
                                repos.append(subentry)
                    except PermissionError:
                        continue
        
        for repo_path in repos:
            cmd = [
                "git", "-C", str(repo_path), "log", 
                f"--since={since}", 
                "--pretty=format:{\"sha\":\"%h\",\"message\":\"%s\",\"date\":\"%ad\",\"author\":\"%an\"}", 
                "--date=iso"
            ]
            try:
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode == 0:
                    for line in result.stdout.strip().split('\n'):
                        if line:
                            try:
                                commit = json.loads(line)
                                commit['platform'] = 'git'
                                commit['repo'] = repo_path.name
                                commit['session_id'] = f"git-{repo_path.name}-{commit['sha']}"
                                commit['timestamp'] = commit['date']
                                all_commits.append(commit)
                            except json.JSONDecodeError:
                                continue
            except Exception:
                continue
        return all_commits

    def _extract_claude_sessions(self, date_range: Dict) -> List[Dict]:
        """Extract Claude Code sessions using existing script."""
        script_path = Path(__file__).parent / "extract-sessions.py"
        days = (date_range['end'] - date_range['start']).days + 1

        cmd = f"python3 {script_path} --days {days}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"Claude extraction failed: {result.stderr}")

        # Parse existing extraction output (would need to modify extract-sessions.py to output JSON)
        sessions = []
        # For now, use glob to find recent JSONL files
        claude_dir = os.path.expanduser("~/.claude/projects")
        if os.path.exists(claude_dir):
            for project_dir in os.listdir(claude_dir):
                project_path = os.path.join(claude_dir, project_dir)
                if os.path.isdir(project_path):
                    for jsonl_file in glob.glob(f"{project_path}/*.jsonl"):
                        sessions.extend(self._parse_claude_jsonl(jsonl_file, date_range))

        return sessions

    def _extract_hermes_sessions(self, date_range: Dict) -> List[Dict]:
        """Extract Hermes sessions via CLI export."""
        # Hermes export writes JSONL to stdout when output is "-"
        # No --format or --days flags exist on hermes sessions export
        cmd = "hermes sessions export -"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"Hermes extraction failed: {result.stderr}")

        sessions = []
        for line in result.stdout.strip().split('\n'):
            if line:
                try:
                    session = json.loads(line)
                    session['platform'] = 'hermes'
                    sessions.append(session)
                except json.JSONDecodeError:
                    continue

        return self._filter_by_date_range(sessions, date_range)

    def _extract_gemini_sessions(self, date_range: Dict) -> List[Dict]:
        """Extract Gemini CLI sessions from antigravity/conversations directory."""
        # Primary: ~/.gemini/antigravity/conversations (actual session storage)
        session_dir = os.path.expanduser("~/.gemini/antigravity/conversations")
        sessions = []

        if not os.path.exists(session_dir):
            # Fallback: ~/.gemini/tmp
            session_dir = os.path.expanduser("~/.gemini/tmp")
            if not os.path.exists(session_dir):
                return sessions

        # Search for conversation JSON files
        for file_path in glob.glob(os.path.join(session_dir, "*.json")):
            file_time = datetime.fromtimestamp(os.path.getmtime(file_path), tz=timezone.utc)
            if self._is_in_date_range(file_time, date_range):
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                        # Try JSONL first (one JSON object per line)
                        lines = content.strip().split('\n')
                        if all(self._is_json(l) for l in lines if l.strip()):
                            for i, line in enumerate(lines):
                                if line.strip():
                                    try:
                                        session = json.loads(line)
                                        session['platform'] = 'gemini'
                                        session['file_path'] = file_path
                                        session['session_id'] = session.get('id', f"{Path(file_path).stem}_{i}")
                                        sessions.append(session)
                                    except json.JSONDecodeError:
                                        continue
                        else:
                            # Single JSON object - wrap in messages structure
                            obj = json.loads(content)
                            session = {
                                'platform': 'gemini',
                                'session_id': Path(file_path).stem,
                                'messages': obj.get('messages', [obj]),
                                'file_path': file_path,
                                'timestamp': obj.get('timestamp', obj.get('created_at', file_time.isoformat()))
                            }
                            sessions.append(session)
                except (json.JSONDecodeError, IOError):
                    continue

        return sessions

    def _is_json(self, s: str) -> bool:
        """Check if string is valid JSON."""
        try:
            json.loads(s)
            return True
        except (json.JSONDecodeError, TypeError):
            return False

    def _extract_opencode_sessions(self, date_range: Dict) -> List[Dict]:
        """Extract OpenCode sessions from SQLite database."""
        db_path = os.path.expanduser("~/.local/share/opencode/opencode.db")
        sessions = []

        if not os.path.exists(db_path):
            return sessions

        try:
            import sqlite3

            conn = sqlite3.connect(db_path)
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()

            # Query sessions with their messages
            # time_created is unix timestamp in milliseconds
            start_ts = int(date_range['start'].timestamp() * 1000)
            end_ts = int(date_range['end'].timestamp() * 1000) + 86399999  # End of day

            # Get sessions in date range
            cursor.execute("""
                SELECT id, project_id, slug, title, directory, time_created, time_updated
                FROM session
                WHERE time_created >= ? AND time_created <= ?
                ORDER BY time_created DESC
            """, (start_ts, end_ts))

            for row in cursor.fetchall():
                session_id = row['id']

                # Get messages for this session
                cursor.execute("""
                    SELECT id, data, time_created
                    FROM message
                    WHERE session_id = ?
                    ORDER BY time_created ASC
                """, (session_id,))

                messages = []
                for msg_row in cursor.fetchall():
                    try:
                        msg_data = json.loads(msg_row['data'])
                        msg_data['_msg_id'] = msg_row['id']
                        msg_data['_msg_time'] = msg_row['time_created']
                        messages.append(msg_data)
                    except (json.JSONDecodeError, TypeError):
                        # Fallback: store raw data
                        messages.append({'raw': msg_row['data'], '_msg_id': msg_row['id']})

                # Get parts (attachments/code blocks)
                cursor.execute("""
                    SELECT id, data, message_id, time_created
                    FROM part
                    WHERE session_id = ?
                    ORDER BY time_created ASC
                """, (session_id,))

                parts = []
                for part_row in cursor.fetchall():
                    try:
                        part_data = json.loads(part_row['data'])
                        part_data['_part_id'] = part_row['id']
                        parts.append(part_data)
                    except (json.JSONDecodeError, TypeError):
                        parts.append({'raw': part_row['data'], '_part_id': part_row['id']})

                # Convert timestamp
                timestamp = datetime.fromtimestamp(
                    row['time_created'] / 1000, tz=timezone.utc
                ).isoformat()

                session = {
                    'platform': 'opencode',
                    'session_id': session_id,
                    'project_id': row['project_id'],
                    'slug': row['slug'],
                    'title': row['title'],
                    'directory': row['directory'],
                    'messages': messages,
                    'parts': parts,
                    'timestamp': timestamp,
                    'file_path': db_path
                }
                sessions.append(session)

            conn.close()

        except (sqlite3.Error, ImportError) as e:
            print(f"   OpenCode SQLite error: {e}")

        return sessions

    def _parse_claude_jsonl(self, file_path: str, date_range: Dict) -> List[Dict]:
        """Parse Claude Code JSONL session file."""
        sessions = []
        current_session = None

        try:
            with open(file_path, 'r') as f:
                for line in f:
                    if not line.strip():
                        continue

                    try:
                        obj = json.loads(line)

                        # New session marker
                        if obj.get('type') == 'session_start' or obj.get('sessionId'):
                            if current_session:
                                sessions.append(current_session)

                            current_session = {
                                'platform': 'claude',
                                'session_id': obj.get('sessionId', Path(file_path).stem),
                                'messages': [],
                                'file_path': file_path,
                                'timestamp': obj.get('timestamp')
                            }

                        # Message
                        elif obj.get('role') in ['user', 'assistant']:
                            if current_session:
                                current_session['messages'].append(obj)
                                if not current_session.get('timestamp'):
                                    current_session['timestamp'] = obj.get('timestamp')

                    except json.JSONDecodeError:
                        continue

                if current_session:
                    sessions.append(current_session)

        except IOError:
            pass

        return [s for s in sessions if self._session_in_date_range(s, date_range)]

    def _parse_opencode_logs(self, file_path: str) -> List[Dict]:
        """Parse OpenCode log files for session data."""
        sessions = []

        try:
            with open(file_path, 'r') as f:
                content = f.read()

                # Look for conversation patterns (this is a guess at OpenCode format)
                session_blocks = re.split(r'\n\n\[SESSION START\]|\n\n---', content)

                for i, block in enumerate(session_blocks):
                    if not block.strip():
                        continue

                    # Extract timestamp if present
                    timestamp_match = re.search(r'(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})', block)
                    timestamp = timestamp_match.group(1) if timestamp_match else None

                    # Extract messages (USER/ASSISTANT pattern)
                    messages = []
                    for line in block.split('\n'):
                        if line.strip().startswith('USER:'):
                            messages.append({'role': 'user', 'content': line[5:].strip()})
                        elif line.strip().startswith('ASSISTANT:'):
                            messages.append({'role': 'assistant', 'content': line[10:].strip()})

                    if messages:
                        sessions.append({
                            'platform': 'opencode',
                            'session_id': f"{Path(file_path).stem}_{i}",
                            'messages': messages,
                            'file_path': file_path,
                            'timestamp': timestamp or datetime.fromtimestamp(os.path.getmtime(file_path)).isoformat()
                        })

        except IOError:
            pass

        return sessions

    def fetch_github_data(self, repo: str, date_range: Dict) -> Dict:
        """Fetch GitHub commits and PR activity."""
        since = date_range['start'].isoformat() + 'Z'
        until = date_range['end'].isoformat() + 'Z'

        # Check if gh cli is available
        result = subprocess.run(['gh', '--version'], capture_output=True)
        if result.returncode != 0:
            raise RuntimeError("GitHub CLI (gh) not available")

        # Get commits
        commits_cmd = [
            'gh', 'api', f'repos/{repo}/commits',
            '--method', 'GET',
            '--field', f'since={since}',
            '--field', f'until={until}',
            '--jq', '.[] | {sha: .sha, message: .commit.message, date: .commit.author.date, author: .commit.author.name}'
        ]

        commits_result = subprocess.run(commits_cmd, capture_output=True, text=True)
        commits = []
        if commits_result.returncode == 0:
            for line in commits_result.stdout.strip().split('\n'):
                if line:
                    try:
                        commits.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue

        # Get PR activity
        prs_cmd = [
            'gh', 'pr', 'list', '--repo', repo, '--state', 'all', '--limit', '50',
            '--json', 'number,title,createdAt,updatedAt,author,state'
        ]

        prs_result = subprocess.run(prs_cmd, capture_output=True, text=True)
        prs = []
        if prs_result.returncode == 0:
            try:
                all_prs = json.loads(prs_result.stdout)
                # Filter PRs by date range
                for pr in all_prs:
                    created = datetime.fromisoformat(pr['createdAt'].replace('Z', '+00:00'))
                    updated = datetime.fromisoformat(pr['updatedAt'].replace('Z', '+00:00'))
                    if (created >= date_range['start'] or updated >= date_range['start']):
                        prs.append(pr)
            except json.JSONDecodeError:
                pass

        return {'commits': commits, 'pull_requests': prs}

    def analyze_backup_diffs(self, backup_path: str, date_range: Dict) -> List[Dict]:
        """Analyze restic backup diffs for file changes."""
        # Check if restic is available
        result = subprocess.run(['restic', 'version'], capture_output=True)
        if result.returncode != 0:
            raise RuntimeError("Restic not available")

        # Get snapshots in date range
        snapshots_cmd = ['restic', 'snapshots', '--json']
        snapshots_result = subprocess.run(snapshots_cmd, capture_output=True, text=True)

        if snapshots_result.returncode != 0:
            raise RuntimeError(f"Failed to get snapshots: {snapshots_result.stderr}")

        snapshots = json.loads(snapshots_result.stdout)

        # Filter snapshots by date range
        relevant_snapshots = []
        for snapshot in snapshots:
            snapshot_time = datetime.fromisoformat(snapshot['time'].replace('Z', '+00:00'))
            if date_range['start'] <= snapshot_time <= date_range['end']:
                relevant_snapshots.append(snapshot)

        # Sort by time (newest first)
        relevant_snapshots.sort(key=lambda x: x['time'], reverse=True)

        # Get diffs between consecutive snapshots
        diffs = []
        for i in range(len(relevant_snapshots) - 1):
            current = relevant_snapshots[i]['id']
            previous = relevant_snapshots[i + 1]['id']

            diff_cmd = ['restic', 'diff', previous, current, '--json']
            diff_result = subprocess.run(diff_cmd, capture_output=True, text=True)

            if diff_result.returncode == 0:
                try:
                    diff_data = json.loads(diff_result.stdout)
                    diffs.append({
                        'snapshot_id': current,
                        'timestamp': relevant_snapshots[i]['time'],
                        'changes': diff_data
                    })
                except json.JSONDecodeError:
                    continue

        return self._filter_backup_changes(diffs, backup_path)

    def _filter_backup_changes(self, diffs: List[Dict], backup_path: str) -> List[Dict]:
        """Filter backup changes to only include relevant paths."""
        if not backup_path:
            return diffs

        filtered_diffs = []
        for diff in diffs:
            relevant_changes = []
            for change in diff.get('changes', []):
                if change.get('path', '').startswith(backup_path):
                    relevant_changes.append(change)

            if relevant_changes:
                filtered_diff = diff.copy()
                filtered_diff['changes'] = relevant_changes
                filtered_diffs.append(filtered_diff)

        return filtered_diffs

    def correlate_timeline(self, sessions: Dict[str, List[Dict]],
                          github_data: Dict, backup_diffs: List[Dict]) -> List[Dict]:
        """Correlate sessions with commits and file changes."""
        timeline = []

        # Flatten all sessions
        all_sessions = []
        for platform, platform_sessions in sessions.items():
            for session in platform_sessions:
                session['platform'] = platform
                all_sessions.append(session)

        for session in all_sessions:
            session_time = self._parse_session_timestamp(session)
            if not session_time:
                continue

            # Find commits within 30 minutes of session
            nearby_commits = []
            for commit in github_data.get('commits', []):
                commit_time = datetime.fromisoformat(commit['date'].replace('Z', '+00:00'))
                time_diff = abs((session_time - commit_time).total_seconds())
                if time_diff < 1800:  # 30 minutes
                    nearby_commits.append(commit)

            # Find file changes that might relate to session
            related_changes = []
            session_files = self._extract_files_mentioned_in_session(session)
            for diff in backup_diffs:
                diff_time = datetime.fromisoformat(diff['timestamp'].replace('Z', '+00:00'))
                time_diff = abs((session_time - diff_time).total_seconds())

                # Check if session mentions files that changed
                changed_files = [f.get('path', '') for f in diff.get('changes', [])
                               if f.get('type') in ['added', 'modified']]
                file_overlap = any(f in self._get_session_content(session) for f in changed_files if f)

                if time_diff < 3600 and file_overlap:  # 1 hour window + file relevance
                    related_changes.append(diff)

            timeline.append({
                'session': session,
                'platform': session['platform'],
                'timestamp': session_time,
                'commits': nearby_commits,
                'file_changes': related_changes
            })

        return sorted(timeline, key=lambda x: x['timestamp'])

    def generate_one_thing(self, timeline: List[Dict]) -> Dict:
        """Generate the single highest-leverage next action."""
        if not timeline:
            return {'action': 'No recent activity found', 'reasoning': 'No sessions or activity detected'}

        # Simple heuristic-based synthesis (would be more sophisticated in practice)
        recent_sessions = timeline[-5:]  # Last 5 sessions
        platforms_used = set(s['platform'] for s in recent_sessions)

        # Find most mentioned topics
        topics = {}
        for entry in recent_sessions:
            content = self._get_session_content(entry['session'])
            words = content.lower().split()
            for word in words:
                if len(word) > 4 and word.isalpha():
                    topics[word] = topics.get(word, 0) + 1

        top_topic = max(topics.items(), key=lambda x: x[1])[0] if topics else "development"

        # Check for recent commits
        has_recent_commits = any(len(e['commits']) > 0 for e in recent_sessions)

        action = f"Continue {top_topic} work across {len(platforms_used)} platforms"
        reasoning = f"Most active topic with activity across {', '.join(platforms_used)}"

        if has_recent_commits:
            action += " and review recent commits"
            reasoning += " with recent Git activity"

        return {
            'topic': top_topic,
            'action': action,
            'reasoning': reasoning,
            'platforms': list(platforms_used)
        }

    # Helper methods
    def _filter_by_topic(self, sessions: List[Dict], topic: str) -> List[Dict]:
        """Filter sessions by topic/keyword."""
        filtered = []
        for session in sessions:
            content = self._get_session_content(session)
            if topic.lower() in content.lower():
                filtered.append(session)
        return filtered

    def _filter_by_date_range(self, sessions: List[Dict], date_range: Dict) -> List[Dict]:
        """Filter sessions by date range."""
        filtered = []
        for session in sessions:
            session_time = self._parse_session_timestamp(session)
            if session_time and self._is_in_date_range(session_time, date_range):
                filtered.append(session)
        return filtered

    def _session_in_date_range(self, session: Dict, date_range: Dict) -> bool:
        """Check if session falls within date range."""
        session_time = self._parse_session_timestamp(session)
        return session_time and self._is_in_date_range(session_time, date_range)

    def _is_in_date_range(self, timestamp: datetime, date_range: Dict) -> bool:
        """Check if timestamp falls within date range."""
        return date_range['start'] <= timestamp <= date_range['end']

    def _is_file_in_date_range(self, file_path: str, date_range: Dict) -> bool:
        """Check if file modification time falls within date range."""
        file_time = datetime.fromtimestamp(os.path.getmtime(file_path), tz=timezone.utc)
        return self._is_in_date_range(file_time, date_range)

    def _parse_session_timestamp(self, session: Dict) -> Optional[datetime]:
        """Parse session timestamp."""
        timestamp_str = session.get('timestamp')
        if not timestamp_str:
            return None

        try:
            # Handle various timestamp formats
            if isinstance(timestamp_str, str):
                if 'Z' in timestamp_str:
                    return datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                else:
                    return datetime.fromisoformat(timestamp_str)
        except (ValueError, AttributeError):
            pass

        return None

    def _get_session_content(self, session: Dict) -> str:
        """Extract text content from session or note."""
        if 'content' in session and isinstance(session['content'], str):
            return session['content']
            
        content = []
        messages = session.get('messages', [])

        for msg in messages:
            if isinstance(msg, dict):
                content.append(msg.get('content', ''))
            elif isinstance(msg, str):
                content.append(msg)

        return ' '.join(content)

    def write_sessions_to_index(self, sessions: Dict[str, List[Dict]],
                                index_dir: Path,
                                date_range: Dict) -> Path:
        """Write sessions as text files for ck indexing.
        
        Creates a directory structure suitable for ck-search indexing:
        index_dir/
          sessions/
            platform_timestamp_sessionid.txt
          summary.json
        
        Returns the path to the index directory.
        """
        import uuid
        
        sessions_dir = index_dir / "sessions"
        sessions_dir.mkdir(parents=True, exist_ok=True)
        
        # Write each session as a separate file
        total_written = 0
        for platform, platform_sessions in sessions.items():
            for session in platform_sessions:
                session_id = session.get('session_id', str(uuid.uuid4())[:8])
                timestamp = self._parse_session_timestamp(session)
                ts_str = timestamp.strftime('%Y%m%d_%H%M%S') if timestamp else 'unknown'
                
                filename = f"{platform}_{ts_str}_{session_id}.txt"
                filepath = sessions_dir / filename
                
                # Build text content for indexing
                lines = [
                    f"# Session: {session_id}",
                    f"# Platform: {platform}",
                    f"# Timestamp: {session.get('timestamp', 'unknown')}",
                    f"# Source: {session.get('file_path', 'unknown')}",
                    "",
                ]
                
                # Add content or messages
                if 'content' in session:
                    lines.append(session['content'])
                else:
                    messages = session.get('messages', [])
                    for msg in messages:
                        role = msg.get('role', 'unknown') if isinstance(msg, dict) else 'unknown'
                        msg_content = msg.get('content', msg) if isinstance(msg, dict) else str(msg)
                        lines.append(f"[{role.upper()}]")
                        lines.append(msg_content)
                        lines.append("")
                
                filepath.write_text('\n'.join(lines))
                total_written += 1
        
        # Write summary metadata
        summary = {
            'date_range': {
                'start': date_range['start'].isoformat(),
                'end': date_range['end'].isoformat()
            },
            'platforms': {p: len(s) for p, s in sessions.items()},
            'total_sessions': total_written,
            'indexed_at': datetime.now(timezone.utc).isoformat()
        }
        
        with open(sessions_dir.parent / 'summary.json', 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"✓ Wrote {total_written} sessions to {sessions_dir}")
        return sessions_dir.parent

    def index_with_ck(self, index_dir: Path) -> bool:
        """Index the session directory with ck-search.
        
        Returns True if indexing succeeded, False otherwise.
        """
        try:
            # Check if ck is available
            result = subprocess.run(['ck', '--version'], capture_output=True)
            if result.returncode != 0:
                print("✗ ck-search not found in PATH")
                return False
            
            # Build the index
            cmd = ['ck', '--index', str(index_dir)]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"✗ ck indexing failed: {result.stderr}")
                return False
            
            print(f"✓ ck index built at {index_dir}/.ck/")
            return True
            
        except Exception as e:
            print(f"✗ ck indexing error: {e}")
            return False

    def search_indexed_sessions(self, index_dir: Path, query: str,
                               search_type: str = 'sem',
                               topk: int = 10) -> List[Dict]:
        """Search indexed sessions using ck.
        
        Args:
            index_dir: Path to the indexed session directory
            query: Search query string
            search_type: 'sem' (semantic), 'lex' (lexical), 'hybrid', or 'regex'
            topk: Number of results to return
        
        Returns list of search results with file, score, and preview.
        """
        import subprocess
        
        try:
            # Map search type to ck flag
            search_flags = {
                'sem': ['--sem'],
                'lex': ['--lex'],
                'hybrid': ['--hybrid'],
                'regex': [],  # default grep-style
            }
            
            flag_map = {
                'sem': '--sem',
                'lex': '--lex', 
                'hybrid': '--hybrid',
            }
            
            cmd = ['ck', '--jsonl']
            if search_type in flag_map:
                cmd.append(flag_map[search_type])
            cmd.extend(['--topk', str(topk), query, str(index_dir / 'sessions')])
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"✗ ck search failed: {result.stderr}")
                return []
            
            # Parse JSONL output
            results = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    try:
                        results.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
            
            return results
            
        except Exception as e:
            print(f"✗ ck search error: {e}")
            return []

    def _extract_files_mentioned_in_session(self, session: Dict) -> List[str]:
        """Extract file paths mentioned in session."""
        content = self._get_session_content(session)

        # Simple regex to find file paths
        file_patterns = [
            r'\b[\w/.-]+\.(py|js|ts|rb|md|json|yaml|yml|txt|log)\b',
            r'\b[\w.-]+/[\w/.-]+\b',
        ]

        files = []
        for pattern in file_patterns:
            files.extend(re.findall(pattern, content))

        return list(set(files))

    # =============================================================================
    # CK-SEARCH DECISION TREE
    # =============================================================================
    # Determines when to use ck-search indexing vs. direct extraction
    # to avoid loading everything into context

    def decide_extraction_mode(self, date_range: Dict, topic: Optional[str],
                               platforms: List[str], force_mode: Optional[str] = None) -> Dict:
        """Decision tree for extraction strategy.

        Returns:
            Dict with keys:
                mode: 'direct' | 'index-then-search' | 'index-only'
                reasoning: str explaining why
                index_dir: Path (if mode is index-*)
                search_query: str (if topic-based)
        """
        if force_mode:
            return self._force_mode_decision(force_mode, date_range, topic)

        date_span_days = (date_range['end'] - date_range['start']).days + 1
        estimated_sessions = self._estimate_session_count(date_range, platforms)
        has_topic = bool(topic and len(topic.split()) >= self.TOPIC_SEARCH_THRESHOLD)

        # Decision nodes
        decisions = []

        # Node 1: Topic search → use ck-search (semantic lookup)
        if has_topic:
            decisions.append({
                'node': 'topic_search',
                'mode': 'index-then-search',
                'reasoning': f"Topic query '{topic}' → semantic search via ck"
            })

        # Node 2: Long date range → index (avoid massive extraction)
        elif date_span_days > self.LONG_DATE_RANGE_DAYS:
            decisions.append({
                'node': 'long_range',
                'mode': 'index-only',
                'reasoning': f"Date range {date_span_days}d > {self.LONG_DATE_RANGE_DAYS}d → build index"
            })

        # Node 3: Many sessions → index (context overflow protection)
        elif estimated_sessions > self.LARGE_SESSION_COUNT:
            decisions.append({
                'node': 'large_count',
                'mode': 'index-only',
                'reasoning': f"~{estimated_sessions} sessions > {self.LARGE_SESSION_COUNT} → build index"
            })

        # Node 4: Multiple platforms → index (aggregation complexity)
        elif len(platforms) >= 3:
            decisions.append({
                'node': 'multi_platform',
                'mode': 'index-then-search',
                'reasoning': f"{len(platforms)} platforms → index for correlation"
            })

        # Default: direct extraction (fast path for simple temporal queries)
        else:
            decisions.append({
                'node': 'direct',
                'mode': 'direct',
                'reasoning': f"Simple temporal query, ~{estimated_sessions} sessions → direct extract"
            })

        # Use first (highest priority) decision
        decision = decisions[0]

        # Determine index directory
        index_dir = self.default_index_dir

        # Check if index already exists and is fresh (< 24h old)
        existing = self._get_existing_index_info(index_dir)
        if existing:
            if existing['date_range'] == self._date_range_key(date_range):
                decision['index_is_fresh'] = True
                decision['reasoning'] += f" (reusing existing index from {existing['indexed_at']})"
            else:
                decision['index_needs_update'] = True

        decision['index_dir'] = index_dir
        decision['estimated_sessions'] = estimated_sessions
        decision['date_span_days'] = date_span_days

        return decision

    def _force_mode_decision(self, force_mode: str, date_range: Dict,
                             topic: Optional[str]) -> Dict:
        """Handle forced mode flags."""
        modes = {
            'direct': ('direct', 'Forced direct mode'),
            'index': ('index-only', 'Forced indexing mode'),
            'search': ('index-then-search', 'Forced search mode')
        }
        if force_mode not in modes:
            return self.decide_extraction_mode(date_range, topic, self.platforms)

        mode, reasoning = modes[force_mode]
        return {
            'mode': mode,
            'reasoning': reasoning,
            'index_dir': self.default_index_dir,
            'forced': True
        }

    def _estimate_session_count(self, date_range: Dict, platforms: List[str]) -> int:
        """Estimate session count based on date range and platforms.

        Uses platform-specific heuristics from known usage patterns.
        """
        days = (date_range['end'] - date_range['start']).days + 1
        estimates = {
            'claude': 8,    # ~8 sessions/day typical
            'hermes': 5,    # ~5 sessions/day
            'gemini': 2,    # ~2 sessions/day
            'opencode': 1,  # ~1 session/day
        }
        total = sum(estimates.get(p, 2) for p in platforms) * days
        return min(total, 200)  # Cap at 200 for estimation

    def _date_range_key(self, date_range: Dict) -> str:
        """Create a comparable key for date range."""
        return f"{date_range['start'].strftime('%Y%m%d')}-{date_range['end'].strftime('%Y%m%d')}"

    def _get_existing_index_info(self, index_dir: Path) -> Optional[Dict]:
        """Check if a valid index exists."""
        summary_path = index_dir / 'summary.json'
        ck_dir = index_dir / '.ck'

        if not summary_path.exists() or not ck_dir.exists():
            return None

        try:
            with open(summary_path) as f:
                summary = json.load(f)

            # Check if index is < 24 hours old
            indexed_at = datetime.fromisoformat(summary['indexed_at'].replace('Z', '+00:00'))
            age_hours = (datetime.now(timezone.utc) - indexed_at).total_seconds() / 3600

            if age_hours > 24:
                return None

            return {
                'date_range': summary['date_range']['start'][:10] + '-' + summary['date_range']['end'][:10],
                'indexed_at': summary['indexed_at'],
                'total_sessions': summary['total_sessions']
            }
        except (json.JSONDecodeError, KeyError, ValueError):
            return None

    def execute_recall_with_decision(self, date_range: Dict, topic: Optional[str],
                                     platforms: List[str], github_repo: Optional[str] = None,
                                     force_mode: Optional[str] = None) -> Dict:
        """Execute recall using the decision tree.

        Implements the full flow:
        1. Decide extraction strategy
        2. Execute (direct or index+search)
        3. Return structured results with one_thing
        """
        decision = self.decide_extraction_mode(date_range, topic, platforms, force_mode)
        mode = decision['mode']
        index_dir = decision['index_dir']

        print(f"\n🎯 Extraction mode: {mode}")
        print(f"   Reasoning: {decision['reasoning']}")
        if 'estimated_sessions' in decision:
            print(f"   Est. sessions: {decision['estimated_sessions']}, span: {decision['date_span_days']}d")

        # MODE: direct (fast path - no indexing)
        if mode == 'direct':
            sessions = self.extract_sessions(platforms, date_range, topic)
            github_data = self._fetch_github_if_needed(github_repo, date_range)
            timeline = self.correlate_timeline(sessions, github_data, [])
            one_thing = self.generate_one_thing(timeline)

            return {
                'mode': 'direct',
                'sessions': sessions,
                'timeline': timeline,
                'one_thing': one_thing,
                'index_used': None
            }

        # MODE: index-then-search (topic queries, multi-platform)
        elif mode == 'index-then-search':
            # Check if we have a fresh index
            existing = self._get_existing_index_info(index_dir)

            if existing and existing.get('date_range') == self._date_range_key(date_range):
                print(f"\n📦 Using existing index: {existing['total_sessions']} sessions")
            else:
                print(f"\n📦 Building new index at {index_dir}...")
                sessions = self.extract_sessions(platforms, date_range, None)
                index_dir = self.write_sessions_to_index(sessions, index_dir, date_range)
                if not self.index_with_ck(index_dir):
                    # Fallback to direct if indexing fails
                    print("   ⚠ ck indexing failed, falling back to direct extraction")
                    timeline = self.correlate_timeline(sessions, {}, [])
                    one_thing = self.generate_one_thing(timeline)
                    return {'mode': 'direct-fallback', 'sessions': sessions,
                            'timeline': timeline, 'one_thing': one_thing}

            # Perform semantic search if topic provided
            if topic:
                print(f"\n🔍 Semantic search: '{topic}'")
                results = self.search_indexed_sessions(index_dir, topic, 'sem', topk=10)

                # Load matched sessions
                matched_sessions = self._load_matched_sessions_from_results(results)
                timeline = self.correlate_timeline(matched_sessions, {}, [])
                one_thing = self.generate_one_thing(timeline)

                return {
                    'mode': 'index-then-search',
                    'search_results': results,
                    'matched_sessions': matched_sessions,
                    'timeline': timeline,
                    'one_thing': one_thing,
                    'index_used': str(index_dir)
                }
            else:
                # No topic, return indexed sessions for correlation
                sessions = self.extract_sessions(platforms, date_range, None)
                github_data = self._fetch_github_if_needed(github_repo, date_range)
                timeline = self.correlate_timeline(sessions, github_data, [])
                one_thing = self.generate_one_thing(timeline)

                return {
                    'mode': 'index-ready',
                    'sessions': sessions,
                    'timeline': timeline,
                    'one_thing': one_thing,
                    'index_used': str(index_dir)
                }

        # MODE: index-only (long range, large count)
        else:  # index-only
            print(f"\n📦 Building index at {index_dir}...")
            sessions = self.extract_sessions(platforms, date_range, None)
            index_dir = self.write_sessions_to_index(sessions, index_dir, date_range)

            if not self.index_with_ck(index_dir):
                print("   ⚠ ck indexing failed")
                timeline = self.correlate_timeline(sessions, {}, [])
                one_thing = self.generate_one_thing(timeline)
                return {'mode': 'direct-fallback', 'sessions': sessions,
                        'timeline': timeline, 'one_thing': one_thing}

            github_data = self._fetch_github_if_needed(github_repo, date_range)
            timeline = self.correlate_timeline(sessions, github_data, [])
            one_thing = self.generate_one_thing(timeline)

            return {
                'mode': 'index-only',
                'sessions': sessions,
                'timeline': timeline,
                'one_thing': one_thing,
                'index_used': str(index_dir)
            }

    def _fetch_github_if_needed(self, repo: Optional[str],
                                date_range: Dict) -> Dict:
        """Fetch GitHub data if repo specified."""
        if not repo:
            return {}
        try:
            return self.fetch_github_data(repo, date_range)
        except Exception as e:
            print(f"   ⚠ GitHub fetch failed: {e}")
            return {}

    def _load_matched_sessions_from_results(self, results: List[Dict]) -> Dict[str, List]:
        """Re-extract full sessions from ck search results for correlation."""
        # Group results by platform
        by_platform = {'claude': [], 'hermes': [], 'gemini': [], 'opencode': []}

        for r in results:
            filepath = r.get('file', r.get('path', ''))
            if not filepath:
                continue

            # Parse platform from filename: platform_timestamp_sessionid.txt
            filename = Path(filepath).name
            parts = filename.split('_')
            if parts and parts[0] in by_platform:
                platform = parts[0]
                # Re-extract from source JSONL
                platform_sessions = self._extract_platform_sessions(
                    platform,
                    {'start': datetime.min.replace(tzinfo=timezone.utc),
                     'end': datetime.max.replace(tzinfo=timezone.utc)},
                    None
                )
                by_platform[platform] = platform_sessions
                break  # Just get all, filtering happens in correlation

        return by_platform


def parse_date_range(date_arg: str) -> Dict[str, datetime]:
    """Parse date argument into start/end datetime range."""
    now = datetime.now(timezone.utc)

    # Handle "last N days" pattern
    last_days_match = re.match(r'last\s+(\d+)\s+days?', date_arg, re.IGNORECASE)
    if last_days_match:
        num_days = int(last_days_match.group(1))
        start = (now - timedelta(days=num_days)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = now
        return {'start': start, 'end': end}

    if date_arg == 'yesterday':
        start = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = start.replace(hour=23, minute=59, second=59)
    elif date_arg == 'today':
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end = now
    elif date_arg == 'last week':
        start = (now - timedelta(days=7)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = now
    elif date_arg == 'this week':
        days_since_monday = now.weekday()
        start = (now - timedelta(days=days_since_monday)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = now
    elif re.match(r'\d{4}-\d{2}-\d{2}', date_arg):
        date = datetime.strptime(date_arg, '%Y-%m-%d').replace(tzinfo=timezone.utc)
        start = date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = date.replace(hour=23, minute=59, second=59)
    else:
        # Default to last 7 days
        start = (now - timedelta(days=7)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = now

    return {'start': start, 'end': end}


def main():
    parser = argparse.ArgumentParser(
        description='Multi-platform session recall with intelligent ck-search routing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Auto mode - decision tree picks extraction strategy
  python3 multi-platform-extract.py last week
  python3 multi-platform-extract.py "Ruby RAG" --platform claude

  # Force specific modes
  python3 multi-platform-extract.py last month --mode direct    # Skip indexing
  python3 multi-platform-extract.py --mode index                # Force indexing
  python3 multi-platform-extract.py --mode search "debugging"    # Force search

  # Advanced: Manual index control
  python3 multi-platform-extract.py --index /tmp/recall-index last week
  python3 multi-platform-extract.py --search "authentication" --index /tmp/recall-index
'''
    )
    parser.add_argument('query', nargs='*', help='Date range (yesterday/today/last week/YYYY-MM-DD) or topic keywords')
    parser.add_argument('--platform', action='append', help='Specific platform(s): claude/hermes/gemini/opencode')
    parser.add_argument('--github', help='GitHub repo for commit correlation (owner/repo)')
    parser.add_argument('--backup', help='Backup path for restic diff analysis')
    parser.add_argument('--output', help='Output file (default: stdout)')

    # Mode control (new)
    parser.add_argument('--mode', choices=['auto', 'direct', 'index', 'search'],
                       default='auto',
                       help='Extraction mode: auto (decision tree), direct (skip indexing), index (force), search (query index)')

    # Legacy ck-search RAG options (still supported)
    parser.add_argument('--index', metavar='DIR',
                       help='[LEGACY] Write sessions to DIR and index with ck-search')
    parser.add_argument('--search', metavar='QUERY',
                       help='[LEGACY] Search indexed sessions using ck')
    parser.add_argument('--search-type', choices=['sem', 'lex', 'hybrid', 'regex'],
                       default='sem',
                       help='ck search type (default: sem)')
    parser.add_argument('--topk', type=int, default=10,
                       help='Number of search results (default: 10)')

    args = parser.parse_args()

    extractor = MultiPlatformExtractor()

    # Parse query arguments
    platforms = args.platform if args.platform else extractor.platforms
    date_range = None
    topic = None

    for arg in args.query:
        if arg in ['yesterday', 'today', 'last week', 'this week'] or re.match(r'\d{4}-\d{2}-\d{2}', arg):
            date_range = parse_date_range(arg)
        else:
            topic = ' '.join(args.query) if not topic else topic + ' ' + arg

    if not date_range:
        date_range = parse_date_range('last week')  # Default

    print(f"🔍 Recalling from {len(platforms)} platforms: {', '.join(platforms)}")
    print(f"📅 Date range: {date_range['start'].strftime('%Y-%m-%d')} to {date_range['end'].strftime('%Y-%m-%d')}")
    if topic:
        print(f"🔎 Topic: {topic}")

    # Handle legacy --index / --search (backward compatibility)
    if args.index or args.search:
        _handle_legacy_mode(extractor, args, date_range, topic, platforms)
        return

    # Handle --mode flag
    force_mode = None
    if args.mode != 'auto':
        force_mode = args.mode
        print(f"⚠ Forced mode: {force_mode}")

    # NEW: Use decision tree execution
    result = extractor.execute_recall_with_decision(
        date_range=date_range,
        topic=topic,
        platforms=platforms,
        github_repo=args.github,
        force_mode=force_mode
    )

    # Output based on mode
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(result, f, indent=2, default=str)
        print(f"\n📝 Results written to {args.output}")
    else:
        print(f"\n🎯 ONE THING: {result['one_thing']['action']}")
        print(f"💡 Reasoning: {result['one_thing']['reasoning']}")
        if result.get('index_used'):
            print(f"📦 Index: {result['index_used']}")
        if result.get('search_results'):
            print(f"\n🔍 Top ck-search results:")
            for i, r in enumerate(result['search_results'][:5], 1):
                print(f"   {i}. {r.get('file', 'unknown')}: {r.get('preview', '')[:80]}...")


def _handle_legacy_mode(extractor, args, date_range, topic, platforms):
    """Handle legacy --index / --search flags for backward compatibility."""
    # Legacy: search only mode
    if args.search and args.index:
        index_path = Path(args.index).expanduser().resolve()
        if not index_path.exists():
            print(f"✗ Index directory not found: {index_path}")
            print("   Run without --search first to create the index")
            sys.exit(1)

        print(f"🔍 Searching index at {index_path}")
        print(f"   Query: {args.search}")
        print(f"   Type: {args.search_type}, topk: {args.topk}")

        results = extractor.search_indexed_sessions(
            index_path, args.search, args.search_type, args.topk
        )

        if results:
            print(f"\n📋 Found {len(results)} results:\n")
            for i, r in enumerate(results, 1):
                score = r.get('score', r.get('rrf_score', 'N/A'))
                file = r.get('file', r.get('path', 'unknown'))
                preview = r.get('preview', '')[:200]
                print(f"{i}. [{score}] {file}")
                print(f"   {preview}...")
                print()
        else:
            print("No results found")
        return

    # Legacy: index only mode
    if args.index:
        index_path = Path(args.index).expanduser().resolve()
        print(f"\n📦 Writing sessions to {index_path} for ck-search indexing...")

        sessions = extractor.extract_sessions(platforms, date_range, topic)
        total_sessions = sum(len(s) for s in sessions.values())
        print(f"📋 Total sessions: {total_sessions}")

        index_dir = extractor.write_sessions_to_index(sessions, index_path, date_range)

        print(f"\n🔧 Building ck-search index...")
        if extractor.index_with_ck(index_dir):
            print(f"\n✅ Index ready at: {index_dir}")
            print(f"   Search with: python3 multi-platform-extract.py --search \"query\" --index {index_path}")
        return

    # Legacy: search without index
    if args.search:
        print("⚠ --search requires --index. Use --mode search instead or build index first.")
        sys.exit(1)


if __name__ == '__main__':
    main()