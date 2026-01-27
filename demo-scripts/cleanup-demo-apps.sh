#!/bin/bash
# cleanup-demo-apps.sh
# Self-Healing Platform Demo - Red Hat One 2026

echo "🧹 Cleaning up demo applications..."
echo ""

# Delete demo namespace
echo "Deleting demo-app namespace..."
oc delete namespace demo-app --ignore-not-found --wait=true

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "To redeploy demo apps, run: ./deploy-demo-apps.sh"
