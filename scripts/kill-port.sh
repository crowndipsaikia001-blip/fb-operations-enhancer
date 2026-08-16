#!/usr/bin/env bash
# Kill the process listening on a TCP port (default 3000)
PORT=${1:-3000}
PID=$(lsof -ti tcp:$PORT 2>/dev/null)
if [ -n "$PID" ]; then
  echo "Killing process $PID on port $PORT"
  kill -9 $PID
else
  echo "No process on port $PORT"
fi
