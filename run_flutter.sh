#!/bin/bash
# Flutter runner script with proper PATH for CocoaPods
export PATH="$HOME/.rbenv/shims:$PATH"
flutter "$@"

