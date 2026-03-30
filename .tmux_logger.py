#!/usr/bin/env python3
"""
TMux session/pane logging manager.
Detects current tmux context and provides logging helpers.
"""

import os
import sys
import json
import subprocess
import time
from pathlib import Path
from datetime import datetime

class TmuxLogger:
    def __init__(self, log_dir="~/terminal_logs"):
        self.log_dir = Path(log_dir).expanduser()
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.in_tmux = os.environ.get('TMUX') is not None

    def get_tmux_context(self):
        """Get current tmux session and pane info."""
        if not self.in_tmux:
            return {'session': 'no-tmux', 'window': '0', 'pane': '0'}

        try:
            session = subprocess.check_output(
                ['tmux', 'display-message', '-p', '#{session_name}'],
                text=True
            ).strip()
            window = subprocess.check_output(
                ['tmux', 'display-message', '-p', '#{window_index}'],
                text=True
            ).strip()
            pane = subprocess.check_output(
                ['tmux', 'display-message', '-p', '#{pane_index}'],
                text=True
            ).strip()
            # Get session creation time to prevent log contamination after restarts
            created = subprocess.check_output(
                ['tmux', 'display-message', '-p', '#{session_created}'],
                text=True
            ).strip()

            # Append creation time to session name for uniqueness
            session_unique = f"{session}_created_{created}" if created else session

            return {'session': session_unique, 'window': window, 'pane': pane}
        except:
            return {'session': 'unknown', 'window': '0', 'pane': '0'}

    def get_log_file(self, context=None):
        """Get log file path for current context."""
        if context is None:
            context = self.get_tmux_context()

        session = context.get('session', 'unknown')
        window = context.get('window', '0')
        pane = context.get('pane', '0')

        # Create session subdirectory
        session_dir = self.log_dir / session
        session_dir.mkdir(parents=True, exist_ok=True)

        # Write session metadata on first access
        metadata_file = session_dir / '.session_info'
        if not metadata_file.exists():
            try:
                with open(metadata_file, 'w') as f:
                    f.write(f"Created: {datetime.now().isoformat()}\n")
                    f.write(f"Session: {session}\n")
                    # Attempt to get more info
                    try:
                        user = os.environ.get('USER', 'unknown')
                        host = os.environ.get('HOSTNAME', 'unknown')
                        f.write(f"User: {user}\n")
                        f.write(f"Host: {host}\n")
                    except:
                        pass
            except:
                pass

        # Log file: session/window-pane.log
        log_file = session_dir / f"window{window}-pane{pane}.log"
        return log_file

    def log_command(self, cmd, context=None):
        """Log a command execution with timestamp."""
        log_file = self.get_log_file(context)
        timestamp = datetime.now().isoformat()

        with open(log_file, 'a') as f:
            f.write(f"\n{'='*80}\n")
            f.write(f"[{timestamp}] COMMAND STARTED\n")
            f.write(f"{cmd}\n")
            f.write(f"{'='*80}\n")

    def log_output(self, output, context=None):
        """Log command output."""
        log_file = self.get_log_file(context)

        if output:
            with open(log_file, 'a') as f:
                f.write(f"\n[OUTPUT]\n")
                f.write(output)
                if not output.endswith('\n'):
                    f.write('\n')

    def capture_pane_output(self, context=None):
        """Capture visible output from current tmux pane."""
        if not self.in_tmux:
            return ""

        try:
            # Get current pane and capture its output (last 30 lines)
            output = subprocess.check_output(
                ['tmux', 'capture-pane', '-p', '-S', '-30'],
                text=True,
                stderr=subprocess.DEVNULL
            )

            # Clean up excessive blank lines
            lines = output.split('\n')

            # Remove trailing blank lines
            while lines and not lines[-1].strip():
                lines.pop()

            # Replace multiple consecutive blank lines with just one
            cleaned = []
            prev_blank = False
            for line in lines:
                is_blank = not line.strip()
                if is_blank:
                    if not prev_blank:
                        cleaned.append(line)
                    prev_blank = True
                else:
                    cleaned.append(line)
                    prev_blank = False

            return '\n'.join(cleaned)
        except:
            return ""

    def log_exit_code(self, code, context=None, duration=None):
        """Log command exit code with completion timestamp and optional duration."""
        log_file = self.get_log_file(context)
        timestamp = datetime.now().isoformat()

        with open(log_file, 'a') as f:
            f.write(f"[{timestamp}] COMMAND COMPLETED\n")
            f.write(f"[{timestamp}] EXIT CODE: {code}\n")
            if duration is not None:
                f.write(f"[{timestamp}] DURATION: {duration:.3f}s\n")
            f.write(f"\n")

    def get_session_logs(self, session_name):
        """Get all log files for a session."""
        session_dir = self.log_dir / session_name
        if session_dir.exists():
            return sorted(session_dir.glob("*.log"))
        return []

    def list_all_sessions(self):
        """List all logged sessions."""
        if self.log_dir.exists():
            return [d.name for d in self.log_dir.iterdir() if d.is_dir()]
        return []

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: .tmux_logger.py <command> [args]")
        sys.exit(1)

    cmd = sys.argv[1]
    logger = TmuxLogger()

    if cmd == 'context':
        print(json.dumps(logger.get_tmux_context()))
    elif cmd == 'logfile':
        print(logger.get_log_file())
    elif cmd == 'list-sessions':
        for session in logger.list_all_sessions():
            print(session)
    elif cmd == 'list-logs':
        session = sys.argv[2] if len(sys.argv) > 2 else 'no-tmux'
        for log in logger.get_session_logs(session):
            print(log)
    elif cmd == 'log-command':
        if len(sys.argv) > 2:
            cmd_text = ' '.join(sys.argv[2:])
            logger.log_command(cmd_text)
    elif cmd == 'log-output':
        if len(sys.argv) > 2:
            output_text = ' '.join(sys.argv[2:])
            logger.log_output(output_text)
    elif cmd == 'capture-pane':
        # Capture current pane output and log it
        output = logger.capture_pane_output()
        if output:
            logger.log_output(output)
    elif cmd == 'log-exit-code':
        if len(sys.argv) > 2:
            try:
                exit_code = int(sys.argv[2])
                duration = None
                if len(sys.argv) > 3:
                    try:
                        duration = float(sys.argv[3])
                    except ValueError:
                        pass
                logger.log_exit_code(exit_code, duration=duration)
            except ValueError:
                pass
