#!/bin/sh

PROCESS_NAME="erlang"

# check if the process is running
PROCESS_IDS=$(ps aux | grep $PROCESS_NAME | grep -v grep | awk '{print $2}')

if [ -n "$PROCESS_IDS" ]; then
  echo "kill $PROCESS_NAME"
  for PID in $PROCESS_IDS; do
    echo "stopping ID: $PID"
    kill -9 $PID
  done
fi

iex -S mix
