#!/bin/bash

set -e


if [ "$EUID" -ne 0 ]; then
  ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  /usr/bin/osascript -e 'do shell script "'$ABSOLUTE_PATH'" with administrator privileges'
  exit
fi

killall racoon
echo "Racoon killed..."
