#!/bin/sh

if [ -z "$1" ]; then
  echo "Missing file" >&2
  exit 1
fi

if [ -z "$ACODE_GIT_IPC_DIR" ]; then
  echo "Missing ACODE_GIT_IPC_DIR" >&2
  exit 1
fi

if [ -z "$ACODE_GIT_IPC_PIPE" ]; then
  echo "Missing ACODE_GIT_IPC_PIPE" >&2
  exit 1
fi

COMMIT_MSG_FILE="$1"
REQUEST_ID="editor_$(date +%s%N)_$$"
RESPONSE_PIPE="$ACODE_GIT_IPC_DIR/resp_${REQUEST_ID}.sock"

cleanup() {
  rm -f "$RESPONSE_PIPE" 2>/dev/null
  kill $WRITE_PID 2>/dev/null
}

trap cleanup EXIT INT TERM

if ! mkfifo "$RESPONSE_PIPE" 2>/dev/null; then
  echo "Failed to create response pipe" >&2
  exit 1
fi

JSON_REQUEST=$(cat <<EOF
{
  "id": "$REQUEST_ID",
  "handler": "git-editor",
  "responsePipe": "$RESPONSE_PIPE",
  "body": {
    "commitMessagePath": "$COMMIT_MSG_FILE"
  }
}
EOF
)

# Send request
echo "$JSON_REQUEST" > "$ACODE_GIT_IPC_PIPE" &
WRITE_PID=$!

# Wait for response with timeout 10 minutes for user to write commit message
if RESPONSE=$(timeout 600 cat "$RESPONSE_PIPE" 2>/dev/null); then
  if echo "$RESPONSE" | grep -q '"error"'; then
    echo "Editor failed" >&2
    exit 1
  fi
  exit 0
else
  echo "Timeout waiting for editor" >&2
  exit 1
fi