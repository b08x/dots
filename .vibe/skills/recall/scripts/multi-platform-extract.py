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
import shutil
import uuid
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any


class MultiPlatformExtractor:
    """Extract sessions from multiple AI platforms with correlation."""

    # Decision thresholds for qmd indexing
    SESSION_SIZE_ESTIMATE_KB = 2  # Avg session size estimate
    LARGE_SESSION_COUNT = 50       # Above this → auto-index
    LONG_DATE_RANGE_DAYS = 7       # Above this → auto-index
    TOPIC_SEARCH_THRESHOLD = 3     # Below this many words, treat as topic

    def __init__(self):
        self.platforms = ['claude', 'hermes', 'antigravity', 'opencode', 'codeinsights']
        self.default_index_dir = Path.home() / '.recall-index'

    def extract_sessions(self, platforms: List[str], date_range: Dict,
                        topic: Optional[str] = None) -> Dict[str, List[Dict]]:
        """Extract sessions from specified platforms."""
        results = {}

        for platform in platforms:
            try:
                sessions = self._extract_platform_sessions(platform, date_range, topic)
                results[platform] = sessions
                print(f"✓ {platform}: {len(sessions)} sessions")
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
            'antigravity': self._extract_antigravity_sessions,
            'opencode': self._extract_opencode_sessions,
            'codeinsights': self._extract_codeinsights_sessions
        }

        if platform not in extractors:
            raise ValueError(f"Unsupported platform: {platform}")

        sessions = extractors[platform](date_range, topic)

        if topic and platform != 'codeinsights':
            sessions = self._filter_by_topic(sessions, topic)

        return sessions

    def _extract_claude_sessions(self, date_range: Dict, topic: Optional[str] = None) -> List[Dict]:
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

    def _extract_hermes_sessions(self, date_range: Dict, topic: Optional[str] = None) -> List[Dict]:
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

    def _parse_antigravity_transcript(self, transcript_path: str, file_time: datetime, session_id: str) -> List[Dict]:
        """Parse an Antigravity transcript.jsonl file."""
        import json
        messages = []
        try:
            with open(transcript_path, 'r') as f:
                for line in f:
                    if not line.strip(): continue
                    try:
                        step = json.loads(line)
                        role = 'user' if step.get('type') == 'USER_INPUT' else 'assistant' if step.get('type') == 'PLANNER_RESPONSE' else step.get('type', 'system').lower()
                        messages.append({
                            'role': role,
                            'content': step.get('content', '')
                        })
                    except json.JSONDecodeError:
                        continue
        except IOError:
            pass

        if not messages:
            return []

        session = {
            'platform': 'antigravity',
            'session_id': session_id,
            'messages': messages,
            'file_path': transcript_path,
            'timestamp': file_time.isoformat()
        }
        return [session]
    def _extract_antigravity_sessions(self, date_range: Dict, topic: Optional[str] = None) -> List[Dict]:
        """Extract Antigravity sessions from ~/.gemini/antigravity-cli/brain/*/."""
        import os
        import glob
        from datetime import datetime, timezone
        
        brain_dir = os.path.expanduser("~/.gemini/antigravity-cli/brain")
        sessions = []

        if not os.path.exists(brain_dir):
            return sessions

        for session_dir in glob.glob(os.path.join(brain_dir, "*")):
            if not os.path.isdir(session_dir):
                continue
            
            transcript_path = os.path.join(session_dir, ".system_generated", "logs", "transcript.jsonl")
            if not os.path.exists(transcript_path):
                continue

            session_id = os.path.basename(session_dir)
            file_time = datetime.fromtimestamp(os.path.getmtime(transcript_path), tz=timezone.utc)
            
            if self._is_in_date_range(file_time, date_range):
                sessions.extend(self._parse_antigravity_transcript(transcript_path, file_time, session_id))

        return sessions


    def _is_json(self, s: str) -> bool:
        """Check if string is valid JSON."""
        try:
            json.loads(s)
            return True
        except (json.JSONDecodeError, TypeError):
            return False

    def _extract_opencode_sessions(self, date_range: Dict, topic: Optional[str] = None) -> List[Dict]:
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


    def _get_codeinsights_embedding(self, text: str) -> Optional[List[float]]:
        import urllib.request
        config_path = Path.home() / ".code-insights" / "config.json"
        if not config_path.exists():
            return None
        try:
            with open(config_path) as f:
                config = json.load(f)
            emb_cfg = config.get("dashboard", {}).get("embedding", {})
            if emb_cfg.get("provider") != "ollama":
                return None
            base_url = emb_cfg.get("baseUrl", "http://localhost:11434").rstrip("/")
            model = emb_cfg.get("model", "nomic-embed-text")
            req = urllib.request.Request(
                f"{base_url}/api/embeddings",
                data=json.dumps({"model": model, "prompt": text}).encode('utf-8'),
                headers={'Content-Type': 'application/json'}
            )
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                return data.get("embedding")
        except Exception:
            return None

    def _extract_codeinsights_sessions(self, date_range: Dict, topic: Optional[str] = None) -> List[Dict]:
        """Extract code-insights sessions using Hybrid RAG search if topic is provided."""
        db_path = Path.home() / ".code-insights" / "data.db"
        if not db_path.exists():
            return []

        try:
            import sqlite3
            import struct
            
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            conn.row_factory = sqlite3.Row
            
            # Load sqlite-vec for vector search
            try:
                import sqlite_vec
                conn.enable_load_extension(True)
                sqlite_vec.load(conn)
                conn.enable_load_extension(False)
            except Exception as e:
                print(f"Warning: sqlite-vec failed to load for code-insights ({e}). Hybrid search may degrade to FTS.")
            
            since = date_range['start'].isoformat()
            until = date_range['end'].isoformat()
            
            sessions = []
            
            if topic:
                emb = self._get_codeinsights_embedding(topic)
                if emb:
                    emb_bytes = struct.pack(f"{len(emb)}f", *emb)
                    cur = conn.execute(f"""
                        WITH fts_matches AS (
                            SELECT m.session_id, bm25(messages_fts) as rank
                            FROM messages_fts 
                            JOIN messages m ON m.rowid = messages_fts.rowid
                            WHERE messages_fts MATCH ?
                            ORDER BY rank LIMIT 50
                        ),
                        vec_matches AS (
                            SELECT m.session_id, v.distance
                            FROM vec_messages v
                            JOIN messages m ON m.id = v.id
                            WHERE v.embedding MATCH ? 
                              AND k = 50
                        )
                        SELECT DISTINCT s.id as session_id, s.project_name, s.summary, s.started_at, s.ended_at,
                               COALESCE(s.custom_title, s.generated_title, 'Untitled') AS title, s.source_tool
                        FROM sessions s
                        WHERE s.id IN (SELECT session_id FROM fts_matches UNION SELECT session_id FROM vec_matches)
                          AND s.started_at >= ? AND s.started_at <= ?
                        ORDER BY s.started_at DESC
                    """, (topic, emb_bytes, since, until))
                else:
                    # Fallback to FTS only
                    cur = conn.execute(f"""
                        WITH fts_matches AS (
                            SELECT m.session_id, bm25(messages_fts) as rank
                            FROM messages_fts 
                            JOIN messages m ON m.rowid = messages_fts.rowid
                            WHERE messages_fts MATCH ?
                            ORDER BY rank LIMIT 50
                        )
                        SELECT DISTINCT s.id as session_id, s.project_name, s.summary, s.started_at, s.ended_at,
                               COALESCE(s.custom_title, s.generated_title, 'Untitled') AS title, s.source_tool
                        FROM sessions s
                        JOIN fts_matches ON s.id = fts_matches.session_id
                        WHERE s.started_at >= ? AND s.started_at <= ?
                        ORDER BY s.started_at DESC
                    """, (topic, since, until))
            else:
                # No topic, just fetch by date
                cur = conn.execute(f"""
                    SELECT id as session_id, project_name, summary, started_at, ended_at,
                           COALESCE(custom_title, generated_title, 'Untitled') AS title, source_tool
                    FROM sessions
                    WHERE started_at >= ? AND started_at <= ?
                    ORDER BY started_at DESC
                """, (since, until))
                
            session_rows = cur.fetchall()
            
            for row in session_rows:
                session_id = row['session_id']
                
                # Fetch messages
                msg_cur = conn.execute("""
                    SELECT id, type, content, timestamp
                    FROM messages
                    WHERE session_id = ?
                    ORDER BY timestamp ASC
                """, (session_id,))
                
                messages = []
                for msg_row in msg_cur.fetchall():
                    messages.append({
                        '_msg_id': msg_row['id'],
                        'role': msg_row['type'],
                        'content': msg_row['content'],
                        'timestamp': msg_row['timestamp']
                    })
                
                session = {
                    'platform': row['source_tool'] if row['source_tool'] else 'codeinsights',
                    'session_id': session_id,
                    'project_id': row['project_name'],
                    'slug': row['project_name'],
                    'title': row['title'],
                    'summary': row['summary'],
                    'messages': messages,
                    'timestamp': row['started_at'],
                    'file_path': str(db_path)
                }
                sessions.append(session)

            conn.close()
            return sessions

        except Exception as e:
            print(f"Code-insights extraction failed: {e}")
            return []

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
        """Extract text content from session."""
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
        """Write sessions as text files for qmd indexing.
        
        Creates a directory structure suitable for qmd indexing:
        index_dir/
          sessions/
            platform_timestamp_sessionid.txt
          summary.json
        
        Returns the path to the index directory.
        """
        import uuid
        
        sessions_dir = index_dir / "sessions"
        sessions_dir.mkdir(parents=True, exist_ok=True)
        
        # Ensure unique filenames in index
        for session in sessions:
            platform = session.get('platform', 'unknown')
            # Create a safe filename
            timestamp_str = session.get('timestamp', '').replace(':', '').replace('-', '')
            if 'T' in timestamp_str:
                timestamp_str = timestamp_str.split('T')[0] + '_' + timestamp_str.split('T')[1][:6]
                
            session_id = session.get('session_id', str(uuid.uuid4())[:8])
            # Clean session_id for filename
            session_id = re.sub(r'[^a-zA-Z0-9_]', '_', str(session_id))
            
            filename = f"{platform}_{timestamp_str}_{session_id}.txt"
            filepath = sessions_dir / filename
            
            # Write session content as markdown text
            try:
                # Extract text content from messages
                lines = []
                messages = session.get('messages', [])
                if isinstance(messages, str):
                    # Handle opencode which might just have raw text
                    lines.append(messages)
                elif isinstance(messages, list):
                    for msg in messages:
                        if isinstance(msg, dict):
                            role = msg.get('role', 'unknown').upper()
                            lines.append(f"\n[{role}]")
                            
                            msg_content = msg.get('content', '')
                            if isinstance(msg_content, str):
                                lines.append(msg_content)
                            elif isinstance(msg_content, list):
                                # Handle complex Claude blocks
                                text_parts = []
                                for block in msg_content:
                                    if isinstance(block, dict) and 'text' in block:
                                        text_parts.append(block['text'])
                                    else:
                                        text_parts.append(str(block))
                                msg_content = '\n'.join(text_parts)
                                lines.append(msg_content)   
                # Build text content for indexing
                lines = [
                    f"# Session: {session_id}",
                    f"# Platform: {platform}",
                    f"# Timestamp: {session.get('timestamp', 'unknown')}",
                    f"# Source: {session.get('file_path', 'unknown')}",
                    "",
                ]
                
                # Add messages
                messages = session.get('messages', [])
                for msg in messages:
                    role = msg.get('role', 'unknown') if isinstance(msg, dict) else 'unknown'
                    msg_content = msg.get('content', msg) if isinstance(msg, dict) else msg
                    
                    if isinstance(msg_content, list):
                        text_parts = []
                        for block in msg_content:
                            if isinstance(block, dict) and 'text' in block:
                                text_parts.append(block['text'])
                            else:
                                text_parts.append(str(block))
                        msg_content = '\\n'.join(text_parts)
                    elif not isinstance(msg_content, str):
                        msg_content = str(msg_content)
                        
                    lines.append(f"[{role.upper()}]")
                    lines.append(msg_content)
                    lines.append("")
                
                filepath.write_text('\n'.join(lines))
                total_written += 1
            except Exception as e:
                print(f"Warning: Failed to write session {session_id} to {filepath}: {e}")
        
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

    def index_with_qmd(self, index_dir: Path) -> bool:
        """Index the session directory with qmd.
        
        Returns True if indexing succeeded, False otherwise.
        """
        try:
            # Check if qmd is available
            if shutil.which('qmd') is None:
                print("✗ qmd not found in PATH")
                return False
            
            index_name = index_dir.name
            sessions_dir = index_dir / 'sessions'
            
            # Create the collection
            add_result = subprocess.run(['qmd', '--index', index_name, 'collection', 'add', str(sessions_dir)], capture_output=True)
            if add_result.returncode != 0:
                print(f"✗ qmd collection add failed: {add_result.stderr.decode('utf-8', 'ignore')}")
                return False
            
            # Update the index
            cmd = ['qmd', '--index', index_name, 'update']
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"✗ qmd indexing failed: {result.stderr}")
                return False
            
            print(f"✓ qmd index built at ~/.cache/qmd/{index_name}.sqlite")
            return True
            
        except Exception as e:
            print(f"✗ qmd indexing error: {e}")
            return False

    def search_indexed_sessions(self, index_dir: Path, query: str,
                               search_type: str = 'sem',
                               topk: int = 10) -> List[Dict]:
        """Search indexed sessions using qmd.
        
        Args:
            index_dir: Path to the indexed session directory
            query: Search query string
            search_type: 'sem' (semantic), 'lex' (lexical), 'hybrid', or 'regex'
            topk: Number of results to return
        
        Returns list of search results with file, score, and preview.
        """
        try:
            index_name = index_dir.name
            collection_name = 'sessions'
            uri_prefix = f"qmd://{collection_name}/"
            
            cmd = ['qmd', '--index', index_name]
            
            if search_type == 'lex':
                cmd.extend(['search'])
            elif search_type in ('sem', 'hybrid'):
                cmd.extend(['query'])
            else:
                cmd.extend(['search'])
                
            cmd.extend(['--json', '-n', str(topk), query])
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"✗ qmd search failed: {result.stderr}")
                return []
            
            # Parse JSON output
            results = []
            try:
                qmd_results = json.loads(result.stdout.strip())
                for r in qmd_results:
                    file_uri = r.get('file', '')
                    uri_path = file_uri.split('?')[0]
                    if uri_path.startswith(uri_prefix):
                        filename = uri_path[len(uri_prefix):]
                        filepath = str(index_dir / collection_name / filename)
                    else:
                        filepath = file_uri
                        
                    results.append({
                        'file': filepath,
                        'score': r.get('score', 0),
                        'content': r.get('snippet', '')
                    })
            except json.JSONDecodeError:
                pass
            
            return results
            
        except Exception as e:
            print(f"✗ qmd search error: {e}")
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
    # QMD DECISION TREE
    # =============================================================================
    # Determines when to use qmd indexing vs. direct extraction
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

        # Node 1: Topic search → use qmd (semantic lookup)
        if has_topic:
            decisions.append({
                'node': 'topic_search',
                'mode': 'index-then-search',
                'reasoning': f"Topic query '{topic}' → semantic search via qmd"
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
            'antigravity': 2,    # ~2 sessions/day
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
        sqlite_path = Path.home() / '.cache' / 'qmd' / f"{index_dir.name}.sqlite"

        if not summary_path.exists() or not sqlite_path.exists():
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

        sessions_to_correlate = []
        github_data = []
        search_results = []
        matched_sessions = []
        index_used = None
        final_mode = mode

        if mode == 'direct':
            sessions_to_correlate = self.extract_sessions(platforms, date_range, topic)
            github_data = self._fetch_github_if_needed(github_repo, date_range)
            
        elif mode == 'index-then-search':
            existing = self._get_existing_index_info(index_dir)
            if existing and existing.get('date_range') == self._date_range_key(date_range):
                print(f"\n📦 Using existing index: {existing['total_sessions']} sessions")
                index_used = str(index_dir)
            else:
                print(f"\n📦 Building new index at {index_dir}...")
                extracted = self.extract_sessions(platforms, date_range, None)
                index_dir = self.write_sessions_to_index(extracted, index_dir, date_range)
                if not self.index_with_qmd(index_dir):
                    print("   ⚠ qmd indexing failed, falling back to direct extraction")
                    final_mode = 'direct-fallback'
                    sessions_to_correlate = extracted
                else:
                    index_used = str(index_dir)

            if final_mode != 'direct-fallback':
                if topic:
                    print(f"\n🔍 Semantic search: '{topic}'")
                    search_results = self.search_indexed_sessions(index_dir, topic, 'sem', topk=10)
                    matched_sessions = self._load_matched_sessions_from_results(search_results)
                    sessions_to_correlate = matched_sessions
                else:
                    final_mode = 'index-ready'
                    sessions_to_correlate = self.extract_sessions(platforms, date_range, None)
                    github_data = self._fetch_github_if_needed(github_repo, date_range)
                    
        else:  # index-only
            print(f"\n📦 Building index at {index_dir}...")
            extracted = self.extract_sessions(platforms, date_range, None)
            index_dir = self.write_sessions_to_index(extracted, index_dir, date_range)
            
            if not self.index_with_qmd(index_dir):
                print("   ⚠ qmd indexing failed, falling back to direct extraction")
                final_mode = 'direct-fallback'
                sessions_to_correlate = extracted
            else:
                index_used = str(index_dir)
                sessions_to_correlate = extracted
                github_data = self._fetch_github_if_needed(github_repo, date_range)

        # Unified correlation and return block
        timeline = self.correlate_timeline(sessions_to_correlate, github_data, [])
        one_thing = self.generate_one_thing(timeline)

        result = {
            'mode': final_mode,
            'timeline': timeline,
            'one_thing': one_thing,
            'index_used': index_used
        }
        
        if final_mode == 'index-then-search':
            result['search_results'] = search_results
            result['matched_sessions'] = matched_sessions
        else:
            result['sessions'] = sessions_to_correlate
            
        return result

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
        """Re-extract full sessions from qmd search results for correlation."""
        # Group results by platform
        by_platform = {'claude': [], 'hermes': [], 'antigravity': [], 'opencode': []}

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
        description='Multi-platform session recall with intelligent qmd routing',
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
    parser.add_argument('--platform', action='append', help='Specific platform(s): claude/hermes/antigravity/opencode')
    parser.add_argument('--github', help='GitHub repo for commit correlation (owner/repo)')
    parser.add_argument('--backup', help='Backup path for restic diff analysis')
    parser.add_argument('--output', help='Output file (default: stdout)')

    # Mode control (new)
    parser.add_argument('--mode', choices=['auto', 'direct', 'index', 'search'],
                       default='auto',
                       help='Extraction mode: auto (decision tree), direct (skip indexing), index (force), search (query index)')

    # Legacy qmd RAG options (still supported)
    parser.add_argument('--index', metavar='DIR',
                       help='[LEGACY] Write sessions to DIR and index with qmd')
    parser.add_argument('--search', metavar='QUERY',
                       help='[LEGACY] Search indexed sessions using qmd')
    parser.add_argument('--search-type', choices=['sem', 'lex', 'hybrid', 'regex'],
                       default='sem',
                       help='qmd search type (default: sem)')
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
            print(f"\n🔍 Top qmd results:")
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
        print(f"\n📦 Writing sessions to {index_path} for qmd indexing...")

        sessions = extractor.extract_sessions(platforms, date_range, topic)
        total_sessions = sum(len(s) for s in sessions.values())
        print(f"📋 Total sessions: {total_sessions}")

        index_dir = extractor.write_sessions_to_index(sessions, index_path, date_range)

        print(f"\n🔧 Building qmd index...")
        if extractor.index_with_qmd(index_dir):
            print(f"\n✅ Index ready at: {index_dir}")
            print(f"   Search with: python3 multi-platform-extract.py --search \"query\" --index {index_path}")
        return

    # Legacy: search without index
    if args.search:
        print("⚠ --search requires --index. Use --mode search instead or build index first.")
        sys.exit(1)


if __name__ == '__main__':
    main()