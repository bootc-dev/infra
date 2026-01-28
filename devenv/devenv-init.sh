#!/bin/bash
# Thin wrapper that calls the Python implementation
exec python3 /usr/lib/devenv/userns-setup "$@"
