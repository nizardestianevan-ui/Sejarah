#!/bin/sh

if [ -z "$ACODE_GIT_IPC_DIR" ]; then
  echo "Missing ACODE_GIT_IPC_DIR" >&2
  exit 1
fi

if [ -z "$ACODE_GIT_IPC_PIPE" ]; then
  echo "Missing ACODE_GIT_IPC_PIPE" >&2
  exit 1
fi

REQUEST_ID="req_$(date +%s%N)_$$"
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
  "handler": "askpass",
  "responsePipe": "$RESPONSE_PIPE",
  "body": {
    "askpassType": "https",
    "argv": ["$0", "$1", "$2", "$3", "$4", "$5", "$6", "$7", "$8", "$9"]
  }
}
EOF
)

# Send request
echo "$JSON_REQUEST" > "$ACODE_GIT_IPC_PIPE" &
WRITE_PID=$!

if RESPONSE=$(timeout 300 cat "$RESPONSE_PIPE" 2>/dev/null); then
  if echo "$RESPONSE" | grep -q '"error"'; then
    echo "Authentication failed" >&2
    exit 1
  fi
  echo "$RESPONSE"
  exit 0
else
  echo "Timeout waiting for credentials" >&2
  exit 1
fi