#!/bin/bash

# ArgoCD Applications Verification Script
# Runs 'argocd app sync --dry-run' for all deployed applications

OUTPUT_FILE="argocd-dry-run-results.txt"

echo "Running ArgoCD dry-run verification..."
echo "Output will be saved to: $OUTPUT_FILE"

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
    echo "Error: argocd CLI not found. Please install it first."
    exit 1
fi

# Check if we're logged in to ArgoCD
if ! argocd account get &> /dev/null; then
    echo "Error: Not logged in to ArgoCD. Please run 'argocd login' first."
    exit 1
fi

# Get all applications
APPS=$(argocd app list -o name | grep -v "NAME" | grep -v "^$" || true)

if [ -z "$APPS" ]; then
    echo "No applications found"
    exit 1
fi

# Clear output file
> "$OUTPUT_FILE"

echo "Found $(echo "$APPS" | wc -l) applications"
echo "Running dry-run for each..."

# Process each application
echo "$APPS" | while read app; do
    if [ -n "$app" ]; then
        echo "Checking: $app"
        echo "=================================================" >> "$OUTPUT_FILE"
        echo "APPLICATION: $app" >> "$OUTPUT_FILE"
        echo "=================================================" >> "$OUTPUT_FILE"
        argocd app sync "$app" --dry-run --grpc-web >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
done

echo "Done! Results saved to: $OUTPUT_FILE"
