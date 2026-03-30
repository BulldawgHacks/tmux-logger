#!/bin/zsh
# Initialize tmux logging - source this in .zshrc

export TMUX_LOGGER_ENABLED=1
export TMUX_LOGGER_DIR="${TMUX_LOGGER_DIR:-$HOME/terminal_logs}"
export TMUX_LOGGER_PY="$HOME/.tmux_logger.py"

# Ensure directory exists
mkdir -p "$TMUX_LOGGER_DIR"

# IMPORTANT: Prevent history sharing between tmux sessions/panes
# Each session should have its own isolated history to avoid logging history from other sessions
if [[ -n "$TMUX" ]]; then
    # Disable history sharing for this tmux session
    unsetopt share_history

    # Create a session-specific history file
    export HISTFILE="$HOME/.zsh_history_${TMUX##*.}"  # Use tmux session ID

    # Set reasonable history size
    HISTSIZE=10000
    SAVEHIST=10000
fi

# Track state
typeset -g _TMUX_LOGGER_LAST_CMD=""
typeset -g _TMUX_LOGGER_DEPTH=0
typeset -g _TMUX_LOGGER_CMD_START=0

# Initialize precmd_functions and preexec_functions arrays if needed
[[ -z "${precmd_functions[@]}" ]] && precmd_functions=()
[[ -z "${preexec_functions[@]}" ]] && preexec_functions=()

# The preexec hook - runs before command execution
_tmux_logger_preexec() {
    # Capture the start time of command execution using zsh SECONDS
    _TMUX_LOGGER_CMD_START=$SECONDS
}

# The precmd hook - runs after each command
_tmux_logger_precmd() {
    local exit_code=$?

    # Prevent recursion
    (( _TMUX_LOGGER_DEPTH > 0 )) && return
    (( _TMUX_LOGGER_DEPTH++ ))

    # Skip if not in tmux or logger disabled
    if [[ -z "$TMUX" || "$TMUX_LOGGER_ENABLED" != "1" || ! -f "$TMUX_LOGGER_PY" ]]; then
        (( _TMUX_LOGGER_DEPTH-- ))
        return $exit_code
    fi

    # Get the last command from history using tail to get just the last line
    # Suppress errors for empty history (first command in session)
    local last_cmd=$(history -1 2>/dev/null | tail -1)

    # Extract just the command part (remove history line numbers)
    last_cmd="${last_cmd#[[:space:]]*[0-9]*[[:space:]]}"

    # Only log if we have a new command and it's not a logger function
    if [[ -n "$last_cmd" && "$last_cmd" != "$_TMUX_LOGGER_LAST_CMD" && "$last_cmd" != *"_tmux_logger"* ]]; then
        python3 "$TMUX_LOGGER_PY" log-command "$last_cmd" 2>/dev/null || true

        # Calculate duration if we have a start time (using zsh SECONDS)
        local duration=""
        if [[ -n "$_TMUX_LOGGER_CMD_START" && "$_TMUX_LOGGER_CMD_START" != "0" ]]; then
            local end_time=$SECONDS
            duration=$((end_time - _TMUX_LOGGER_CMD_START))
        fi

        # Capture pane output and log it
        python3 "$TMUX_LOGGER_PY" capture-pane 2>/dev/null || true

        # Log exit code with duration
        if [[ -n "$duration" ]]; then
            python3 "$TMUX_LOGGER_PY" log-exit-code "$exit_code" "$duration" 2>/dev/null || true
        else
            python3 "$TMUX_LOGGER_PY" log-exit-code "$exit_code" 2>/dev/null || true
        fi

        _TMUX_LOGGER_LAST_CMD="$last_cmd"
    fi

    (( _TMUX_LOGGER_DEPTH-- ))
    return $exit_code
}

# Add to precmd_functions and preexec_functions
preexec_functions+=(_tmux_logger_preexec)
precmd_functions+=(_tmux_logger_precmd)

# Utility functions for viewing logs
tmux_logger_logfile() {
    if [[ -f "$TMUX_LOGGER_PY" ]]; then
        python3 "$TMUX_LOGGER_PY" logfile
    fi
}

tmux_logger_current_session() {
    if [[ -f "$TMUX_LOGGER_PY" ]]; then
        python3 "$TMUX_LOGGER_PY" context | python3 -c "import sys, json; print(json.load(sys.stdin).get('session', 'unknown'))"
    fi
}

tmux_logger_logs() {
    local session="${1:=$(tmux_logger_current_session)}"
    local logdir="$TMUX_LOGGER_DIR/$session"

    if [[ -d "$logdir" ]]; then
        echo "Logs for session: $session"
        ls -lh "$logdir"
    else
        echo "No logs found for session: $session"
        return 1
    fi
}

tmux_logger_tail() {
    local logfile=$(tmux_logger_logfile)
    if [[ -f "$logfile" ]]; then
        echo "Tailing: $logfile"
        tail -f "$logfile"
    else
        echo "No log file found"
        return 1
    fi
}

tmux_logger_cat() {
    local logfile=$(tmux_logger_logfile)
    if [[ -f "$logfile" ]]; then
        cat "$logfile"
    else
        echo "No log file found"
        return 1
    fi
}

tmux_logger_list() {
    echo "Logged tmux sessions:"
    if [[ -d "$TMUX_LOGGER_DIR" ]]; then
        ls -d "$TMUX_LOGGER_DIR"/*/ 2>/dev/null | xargs -I {} basename {} | sort
    else
        echo "No logs directory found"
    fi
}

# Functions are automatically available in zsh

echo "[TMUX Logger] Initialized. Logging to: $TMUX_LOGGER_DIR"
