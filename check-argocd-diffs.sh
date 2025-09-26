#!/bin/bash

# ArgoCD Applications Diff Script
# Shows actual differences between current and desired state

OUTPUT_FILE="argocd-diff-results.txt"

echo "Checking ArgoCD application diffs..."
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
echo "Checking diffs for each..."

# Process each application
echo "$APPS" | while read app; do
    if [ -n "$app" ]; then
        echo "Checking diff: $app"
        echo "=================================================" >> "$OUTPUT_FILE"
        echo "APPLICATION DIFF: $app" >> "$OUTPUT_FILE"
        echo "=================================================" >> "$OUTPUT_FILE"
        
        # Run diff command
        DIFF_OUTPUT=$(argocd app diff "$app" --local --grpc-web 2>&1)
        
        # Check if there are differences
        if echo "$DIFF_OUTPUT" | grep -q "===== "; then
            echo "HAS DIFFERENCES" >> "$OUTPUT_FILE"
            echo "$DIFF_OUTPUT" >> "$OUTPUT_FILE"
        elif echo "$DIFF_OUTPUT" | grep -q "no changes"; then
            echo "NO DIFFERENCES" >> "$OUTPUT_FILE"
        else
            echo "DIFF CHECK RESULT:" >> "$OUTPUT_FILE"
            echo "$DIFF_OUTPUT" >> "$OUTPUT_FILE"
        fi
        
        echo "" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
done

echo "Done! Diff results saved to: $OUTPUT_FILE"

# Summary
echo ""
echo "SUMMARY:"
echo "========"
APPS_WITH_DIFFS=$(grep -c "HAS DIFFERENCES" "$OUTPUT_FILE" 2>/dev/null || echo "0")
APPS_NO_DIFFS=$(grep -c "NO DIFFERENCES" "$OUTPUT_FILE" 2>/dev/null || echo "0")

echo "Applications with differences: $APPS_WITH_DIFFS"
echo "Applications with no differences: $APPS_NO_DIFFS"

if [ "$APPS_WITH_DIFFS" -gt 0 ]; then
    echo ""
    echo "⚠️  Applications with differences:"
    grep -B1 "HAS DIFFERENCES" "$OUTPUT_FILE" | grep "APPLICATION DIFF:" | sed 's/APPLICATION DIFF: /  - /'
fi
