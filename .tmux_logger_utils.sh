#!/bin/bash
# Utility script for managing tmux logs
# Usage: source this script or use functions directly

export TMUX_LOGGER_DIR="${TMUX_LOGGER_DIR:-$HOME/terminal_logs}"

# View all log sessions with sizes
tmux_logs_summary() {
    echo "=== TMUX Session Logs Summary ==="
    echo ""

    if [ ! -d "$TMUX_LOGGER_DIR" ]; then
        echo "No logs directory found at: $TMUX_LOGGER_DIR"
        return 1
    fi

    for session_dir in "$TMUX_LOGGER_DIR"/*; do
        if [ -d "$session_dir" ]; then
            session_name=$(basename "$session_dir")
            total_size=$(du -sh "$session_dir" | cut -f1)
            pane_count=$(ls -1 "$session_dir"/*.log 2>/dev/null | wc -l)

            echo "Session: $session_name"
            echo "  Size: $total_size | Panes: $pane_count"
            echo "  Panes:"

            for logfile in "$session_dir"/*.log; do
                if [ -f "$logfile" ]; then
                    filename=$(basename "$logfile")
                    filesize=$(ls -lh "$logfile" | awk '{print $5}')
                    cmd_count=$(grep -c "^\[.*\] COMMAND" "$logfile" 2>/dev/null || echo "0")
                    echo "    - $filename ($filesize, $cmd_count commands)"
                fi
            done
            echo ""
        fi
    done
}

# Search through all logs for a pattern
tmux_logs_search() {
    local pattern="$1"
    if [ -z "$pattern" ]; then
        echo "Usage: tmux_logs_search <pattern>"
        return 1
    fi

    echo "Searching logs for pattern: $pattern"
    echo ""

    grep -r "$pattern" "$TMUX_LOGGER_DIR" --include="*.log" -l | while read logfile; do
        echo "Found in: $logfile"
        grep "$pattern" "$logfile" -B 1 -A 1 --color=auto | head -10
        echo ""
    done
}

# Export logs from a session to a single file
tmux_logs_export() {
    local session="$1"
    local outfile="${2:-./$session-export.log}"

    if [ -z "$session" ]; then
        echo "Usage: tmux_logs_export <session_name> [output_file]"
        return 1
    fi

    session_dir="$TMUX_LOGGER_DIR/$session"
    if [ ! -d "$session_dir" ]; then
        echo "Session not found: $session"
        return 1
    fi

    # Combine all pane logs in order
    {
        echo "=== TMUX Session Log Export: $session ==="
        echo "Exported: $(date)"
        echo ""

        # Sort by pane number
        for logfile in $(ls -v "$session_dir"/*.log 2>/dev/null); do
            echo "=== Pane: $(basename $logfile) ==="
            cat "$logfile"
            echo ""
        done
    } > "$outfile"

    echo "✓ Logs exported to: $outfile"
    ls -lh "$outfile"
}

# Clear old logs (older than N days)
tmux_logs_clean() {
    local days="${1:-30}"

    echo "Removing logs older than $days days..."
    echo ""

    find "$TMUX_LOGGER_DIR" -name "*.log" -type f -mtime +$days -exec rm {} \; -print

    echo ""
    echo "✓ Cleanup complete"
}

# Get statistics about logs
tmux_logs_stats() {
    echo "=== TMUX Logging Statistics ==="
    echo ""

    if [ ! -d "$TMUX_LOGGER_DIR" ]; then
        echo "No logs found"
        return 1
    fi

    # Count sessions, panes, and total commands
    session_count=$(ls -1d "$TMUX_LOGGER_DIR"/*/ 2>/dev/null | wc -l)
    pane_count=$(find "$TMUX_LOGGER_DIR" -name "*.log" -type f | wc -l)
    total_commands=$(grep -r "^\[.*\] COMMAND" "$TMUX_LOGGER_DIR" 2>/dev/null | wc -l)
    total_size=$(du -sh "$TMUX_LOGGER_DIR" 2>/dev/null | cut -f1)

    echo "Sessions: $session_count"
    echo "Total Panes: $pane_count"
    echo "Total Commands Logged: $total_commands"
    echo "Total Size: $total_size"
    echo ""

    # Show most frequently used commands
    echo "Top 10 Most Frequently Used Commands:"
    grep "^\[.*\] COMMAND" "$TMUX_LOGGER_DIR"/*/*.log 2>/dev/null | \
        sed 's/^.*\] COMMAND//' | \
        sed 's/^\s*//' | \
        sort | uniq -c | sort -rn | head -10 | \
        awk '{print "  " $2 " (" $1 " times)" }' || \
        echo "  (none)"
}

# View formatted log entries with timestamps and durations
tmux_logs_view() {
    local session="${1:=$(tmux_logger_current_session 2>/dev/null)}"
    local logdir="$TMUX_LOGGER_DIR/$session"

    if [ -z "$session" ] || [ ! -d "$logdir" ]; then
        echo "Session not found: $session"
        return 1
    fi

    echo "=== Command Log for Session: $session ==="
    echo ""

    for logfile in "$logdir"/*.log; do
        if [ -f "$logfile" ]; then
            echo "Pane: $(basename $logfile)"
            echo "---"

            # Extract command blocks and format them
            awk '
            /COMMAND STARTED/ {
                timestamp = $0
                sub(/.*\[/, "", timestamp)
                sub(/\] COMMAND.*/, "", timestamp)
                getline
                cmd = $0

                # Read until we find EXIT CODE
                while (getline && !/EXIT CODE/) {
                    if (/COMMAND COMPLETED/ || /DURATION/) {
                        match($0, /[0-9]+\.?[0-9]*/)
                        if ($0 ~ /DURATION/) {
                            duration = $NF
                        }
                    }
                }

                # Found EXIT CODE line
                exit_code = $NF

                # Check for duration on next line
                getline
                if ($0 ~ /DURATION/) {
                    duration = $NF
                }

                if (duration) {
                    printf "  [%s] %s\n    → Exit: %d, Duration: %s\n", timestamp, cmd, exit_code, duration
                } else {
                    printf "  [%s] %s\n    → Exit: %d\n", timestamp, cmd, exit_code
                }
                duration = ""
            }
            ' "$logfile"
            echo ""
        fi
    done
}

# Show session information and metadata
tmux_logs_sessions() {
    echo "=== Logged TMux Sessions ==="
    echo ""

    if [ ! -d "$TMUX_LOGGER_DIR" ]; then
        echo "No logs directory found"
        return 1
    fi

    for session_dir in "$TMUX_LOGGER_DIR"/*/; do
        if [ -d "$session_dir" ]; then
            session_name=$(basename "$session_dir")
            echo "Session: $session_name"

            # Show metadata if available
            if [ -f "$session_dir/.session_info" ]; then
                echo "  Metadata:"
                sed 's/^/    /' "$session_dir/.session_info"
            fi

            # Show size and pane count
            total_size=$(du -sh "$session_dir" 2>/dev/null | awk '{print $1}')
            pane_count=$(find "$session_dir" -name "window*-pane*.log" 2>/dev/null | wc -l)
            echo "  Size: $total_size | Panes: $pane_count"
            echo ""
        fi
    done
}

# Display help
tmux_logs_help() {
    cat << 'EOF'
=== TMUX Logger Utilities ===

Available functions:

  tmux_logs_summary
    Show overview of all logged sessions with sizes and pane counts

  tmux_logs_search <pattern>
    Search through all logs for a pattern

  tmux_logs_view [session_name]
    View formatted command history with timestamps and durations

  tmux_logs_sessions
    Show all sessions with metadata and creation info

  tmux_logs_export <session_name> [output_file]
    Export entire session logs to a single file

  tmux_logs_clean [days]
    Remove logs older than N days (default: 30)

  tmux_logs_stats
    Show statistics about all logs (sessions, commands, size, etc.)

  tmux_logs_help
    Show this help message

Environment:
  TMUX_LOGGER_DIR: $TMUX_LOGGER_DIR

EOF
}

# Show help if no command provided
if [ -z "$1" ] && [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    tmux_logs_help
fi
