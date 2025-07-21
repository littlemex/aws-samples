#!/bin/bash
set -e

# data ディレクトリの作成
echo "Creating data directory..."
mkdir -p data

# .env.example.dev を .env にコピー
echo "Copying .env.example.dev to .env..."
cp .env.example.dev .env