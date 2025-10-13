#!/bin/bash

echo "=== Test Script Execution ==="
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Current date: $(date)"
echo "System info: $(uname -a)"
echo "Disk usage:"
df -h | head -5
echo "Memory usage:"
free -h
echo "=== Test Script Completed ==="
ls
