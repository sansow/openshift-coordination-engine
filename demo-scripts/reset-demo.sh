#!/bin/bash
# reset-demo.sh
# Self-Healing Platform Demo - Red Hat One 2026

echo "🔄 Resetting demo environment..."
echo "================================="
echo ""

# Step 1: Clean up demo apps
echo "Step 1: Cleaning up demo apps..."
oc delete namespace demo-app --ignore-not-found --wait=false 2>/dev/null
sleep 3

# Step 2: Restart KServe predictors
echo "Step 2: Restarting ML model predictors..."
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=predictive-analytics --force --grace-period=0 2>/dev/null
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector --force --grace-period=0 2>/dev/null

# Step 3: Restart Coordination Engine (clear any cached state)
echo "Step 3: Restarting Coordination Engine..."
oc rollout restart deployment/coordination-engine -n self-healing-platform 2>/dev/null

# Step 4: Wait for namespace deletion
echo "Step 4: Waiting for cleanup..."
sleep 10

# Step 5: Redeploy demo apps
echo "Step 5: Redeploying demo applications..."
oc create namespace demo-app 2>/dev/null || true
oc label namespace demo-app demo=self-healing --overwrite

# Payment Service
cat <<'EOF' | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: demo-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo "Payment Service Starting..." && sleep 5 && exit 1']
        resources:
          limits:
            memory: "64Mi"
EOF

# Frontend (healthy)
cat <<'EOF' | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "64Mi"
EOF

# Step 6: Wait for pods and predictors
echo "Step 6: Waiting for components to stabilize (45 seconds)..."
sleep 45

echo ""
echo "📊 Platform Status:"
echo "==================="
oc get pods -n self-healing-platform | grep -E "predictor|coordination|mcp"

echo ""
echo "📊 Demo App Status:"
echo "==================="
oc get pods -n demo-app

echo ""
echo "✅ Demo environment reset complete!"
echo ""
echo "Wait ~1-2 minutes for CrashLoopBackOff to appear on payment-service"
