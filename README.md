# tmux-logger

Automatic command logging for tmux with timestamps, output capture, and session isolation.

## Features

- **Full command logging** - Every command logged with ISO 8601 timestamps
- **Timestamps** - Automatic duration tracking for each command
- **Output capture** - Full terminal output saved with each command

## Installation

### Clone and install:

```bash
git clone https://github.com/BulldawgHacks/tmux-logger.git
cd tmux-logger

# Copy files to home directory
cp .tmux_logger.py ~/.tmux_logger.py
cp .tmux_logger_init.zsh ~/.tmux_logger_init.zsh
cp .tmux_logger_utils.sh ~/.tmux_logger_utils.sh

# Add to ~/.zshrc
cat >> ~/.zshrc << 'EOF'

source ~/.tmux_logger_init.zsh
source ~/.tmux_logger_utils.sh
EOF

# Reload shell
source ~/.zshrc
```

## Quick Start

```bash
# Start a tmux session - logging begins automatically
tmux -u

# Run commands normally
echo "test"
python script.py
ls -la

# View formatted logs
tmux_logs_view

# Search logs
tmux_logs_search "python"

# Export session
tmux_logs_export mywork ~/backup.log

# View statistics
tmux_logs_stats
```

## Usage

### View logs

```bash
tmux_logs_view              # Current session
tmux_logs_view session-name # Specific session
tmux_logger_tail            # Follow mode (tail -f)
```

### Search

```bash
tmux_logs_search "pattern"           # Find pattern
tmux_logs_search "EXIT CODE: [1-9]"  # Find failures
tmux_logs_search "DURATION: [5-9]"   # Find slow commands
```

### Manage

```bash
tmux_logs_summary       # Overview of all sessions
tmux_logs_sessions      # Sessions with metadata
tmux_logs_stats         # Statistics and analysis
tmux_logs_export session ~/backup.log  # Export session
tmux_logs_clean 30      # Remove logs older than 30 days
```

## Log Format

```
================================================================================
[2026-03-30T09:10:56.744365] COMMAND STARTED
echo "test"
================================================================================

[OUTPUT]
test

[2026-03-30T09:10:58.806451] COMMAND COMPLETED
[2026-03-30T09:10:58.806451] EXIT CODE: 0
[2026-03-30T09:10:58.806451] DURATION: 2.000s
```

## Logs Location

```
~/terminal_logs/
├── sessionname_created_1704033600/
│   ├── window0-pane0.log
│   ├── window0-pane1.log
│   └── .session_info
└── anothersession_created_1704046800/
    └── window0-pane0.log
```

Each session gets a unique directory based on its creation timestamp, preventing log contamination even after system restarts.

## Configuration

```bash
# Custom log directory
export TMUX_LOGGER_DIR=/custom/path

# Disable temporarily
export TMUX_LOGGER_ENABLED=0

# Re-enable
export TMUX_LOGGER_ENABLED=1
```
