#!/bin/bash
# Deploy saunasto-site to Cloudflare Pages production.
# Run from the repo root: bash deploy.sh
# Requires: wrangler authenticated as mrjohndoe32@gmail.com (run `wrangler login` if needed)
set -e
echo "=== Deploying saunasto-site to Cloudflare Pages ==="
wrangler pages deploy . --project-name=saunasto-site --branch=main
echo "=== Done ==="
