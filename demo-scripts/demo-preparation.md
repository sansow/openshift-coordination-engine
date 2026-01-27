# Self-Healing Platform Demo - Red Hat One 2026
## Prepared by: Sangz & Tosin Akinosho

---

# Part 1: Pre-Demo Setup

## 1.1 Verify Platform Components are Running

```bash
# Check all self-healing platform components
oc get pods -n self-healing-platform

# Expected output - all should be Running:
# - coordination-engine-xxx
# - mcp-server-xxx
# - self-healing-workbench-0
# - predictive-analytics-predictor-xxx
# - anomaly-detector-predictor-xxx
```

## 1.2 Verify Lightspeed MCP Connection

```bash
# Check MCP server logs for Lightspeed connection
oc logs -n self-healing-platform deployment/mcp-server --tail=20 | grep -i "connect\|lightspeed"
```

## 1.3 Quick Health Check

```bash
# Test Coordination Engine
oc exec -n self-healing-platform deployment/mcp-server -- curl -s http://coordination-engine:8080/health

# Test KServe models
oc exec -n self-healing-platform self-healing-workbench-0 -- curl -s http://predictive-analytics-predictor:8080/v1/models/model
oc exec -n self-healing-platform self-healing-workbench-0 -- curl -s http://anomaly-detector-predictor:8080/v1/models/model
```

---

# Part 2: Demo Applications

## 2.1 Payment Service (CrashLoopBackOff Demo)

```yaml
# payment-service-crashloop.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
  labels:
    demo: self-healing
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: demo-app
  labels:
    app: payment-service
    tier: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
        tier: backend
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo "Payment Service Starting..." && echo "Connecting to database..." && sleep 5 && echo "ERROR: Database connection failed!" && exit 1']
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: demo-app
spec:
  selector:
    app: payment-service
  ports:
  - port: 8080
    targetPort: 8080
```

**Deploy:**
```bash
cat <<'EOF' | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
  labels:
    demo: self-healing
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: demo-app
  labels:
    app: payment-service
    tier: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
        tier: backend
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo "Payment Service Starting..." && echo "Connecting to database..." && sleep 5 && echo "ERROR: Database connection failed!" && exit 1']
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
```

## 2.2 Order Service (OOMKilled Demo)

```bash
cat <<'EOF' | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: demo-app
  labels:
    app: order-service
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        tier: backend
    spec:
      containers:
      - name: app
        image: python:3.9-slim
        command: ['python', '-c', 'import time; data = []; [data.extend([0]*10000000) or time.sleep(1) for _ in range(100)]']
        resources:
          requests:
            memory: "64Mi"
          limits:
            memory: "128Mi"
EOF
```

## 2.3 Inventory Service (High CPU Demo)

```bash
cat <<'EOF' | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
  namespace: demo-app
  labels:
    app: inventory-service
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: inventory-service
  template:
    metadata:
      labels:
        app: inventory-service
        tier: backend
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo "Inventory sync starting..." && while true; do echo "Processing inventory batch..."; done']
        resources:
          requests:
            cpu: "100m"
          limits:
            cpu: "200m"
EOF
```

## 2.4 Healthy Frontend Service (Control)

```bash
cat <<'EOF' | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: demo-app
  labels:
    app: frontend
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
```

## 2.5 Deploy All Demo Apps Script

```bash
#!/bin/bash
# deploy-demo-apps.sh

echo "🚀 Deploying demo applications..."

# Create namespace
oc create namespace demo-app 2>/dev/null || true
oc label namespace demo-app demo=self-healing --overwrite

# Payment Service (CrashLoopBackOff)
echo "📦 Deploying payment-service (will crash)..."
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

# Order Service (OOMKilled)
echo "📦 Deploying order-service (will OOM)..."
cat <<'EOF' | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: app
        image: python:3.9-slim
        command: ['python', '-c', 'data = []; [data.extend([0]*10000000) for _ in range(100)]']
        resources:
          limits:
            memory: "128Mi"
EOF

# Frontend (Healthy)
echo "📦 Deploying frontend (healthy)..."
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

echo "⏳ Waiting for pods to start..."
sleep 10

echo "📊 Pod status:"
oc get pods -n demo-app

echo "✅ Demo apps deployed!"
```

## 2.6 Cleanup Script

```bash
#!/bin/bash
# cleanup-demo-apps.sh

echo "🧹 Cleaning up demo applications..."
oc delete namespace demo-app --ignore-not-found
echo "✅ Cleanup complete!"
```

---

# Part 3: Lightspeed Demo Prompts

## 3.1 Cluster Health Queries (Simple - Direct K8s API)

### Basic Health Check
```
What's the health status of the demo-app namespace?
```

### List Failing Pods
```
Show me all pods that are not running in demo-app namespace
```

```
Are there any CrashLoopBackOff pods in the cluster?
```

### Pod Details
```
Why is the payment-service pod crashing in demo-app?
```

```
Get the logs from payment-service in demo-app namespace
```

### Events
```
Show me recent warning events in demo-app namespace
```

---

## 3.2 Predictive Analytics (ML-Powered via Coordination Engine)

### CPU Prediction
```
Predict CPU usage for openshift-monitoring namespace
```

```
What will the CPU usage be for self-healing-platform in the next hour?
```

### Memory Prediction
```
Predict memory usage for demo-app namespace
```

```
Will openshift-monitoring namespace need more memory resources?
```

### Combined Prediction
```
Give me a resource forecast for the self-healing-platform namespace
```

---

## 3.3 Anomaly Detection (ML-Powered via Coordination Engine)

### Detect Anomalies
```
Detect anomalies in openshift-monitoring namespace
```

```
Are there any unusual patterns in demo-app namespace?
```

```
Check for anomalies in CPU usage across the cluster
```

### Anomaly Investigation
```
What's causing the anomaly in demo-app?
```

---

## 3.4 Remediation Queries

### Get Recommendations
```
What should I do to fix the payment-service issues?
```

```
How can I resolve the CrashLoopBackOff in demo-app?
```

### Scaling
```
Should I scale up the frontend deployment in demo-app?
```

---

## 3.5 Demo Flow Script (Recommended Order)

### Act 1: The Problem (2 min)
```
# First, show the broken state
1. "What's the health of demo-app namespace?"
   → Shows CrashLoopBackOff, OOMKilled pods

2. "Show me all failing pods in demo-app"
   → Lists payment-service, order-service issues

3. "Why is payment-service crashing?"
   → Shows logs, exit codes
```

### Act 2: Intelligence Layer (3 min)
```
# Now show the ML-powered features
4. "Predict CPU usage for openshift-monitoring"
   → Shows 56% prediction (realistic, not 100%!)
   → Explain: "This uses real Prometheus data, not synthetic"

5. "Detect anomalies in demo-app"
   → Shows anomaly detection working
   → Explain: "IsolationForest model trained on real cluster patterns"

6. "Are there any unusual patterns across the cluster?"
   → Broader anomaly scan
```

### Act 3: The Architecture (2 min)
```
# Explain what just happened
7. Show architecture slide
   → "Simple queries like 'get health' go directly to K8s API"
   → "Prediction queries go through Coordination Engine → KServe"
   → "Models trained on REAL Prometheus data"
```

---

# Part 4: Demo Environment Verification

## 4.1 Pre-Demo Checklist

```bash
#!/bin/bash
# pre-demo-check.sh

echo "🔍 Self-Healing Platform Demo Checklist"
echo "========================================"

# Check namespace
echo -n "1. self-healing-platform namespace: "
oc get ns self-healing-platform &>/dev/null && echo "✅" || echo "❌"

# Check MCP Server
echo -n "2. MCP Server: "
oc get pods -n self-healing-platform -l app=mcp-server --no-headers 2>/dev/null | grep -q Running && echo "✅ Running" || echo "❌ Not Running"

# Check Coordination Engine
echo -n "3. Coordination Engine: "
oc get pods -n self-healing-platform -l app=coordination-engine --no-headers 2>/dev/null | grep -q Running && echo "✅ Running" || echo "❌ Not Running"

# Check KServe Models
echo -n "4. Predictive Analytics Model: "
oc get pods -n self-healing-platform -l serving.kserve.io/inferenceservice=predictive-analytics --no-headers 2>/dev/null | grep -q Running && echo "✅ Running" || echo "❌ Not Running"

echo -n "5. Anomaly Detector Model: "
oc get pods -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector --no-headers 2>/dev/null | grep -q Running && echo "✅ Running" || echo "❌ Not Running"

# Check Workbench
echo -n "6. Jupyter Workbench: "
oc get pods -n self-healing-platform -l app=self-healing-workbench --no-headers 2>/dev/null | grep -q Running && echo "✅ Running" || echo "❌ Not Running"

# Test Predictions
echo -n "7. Prediction API: "
PRED=$(oc exec -n self-healing-platform self-healing-workbench-0 -- curl -s -X POST http://predictive-analytics-predictor:8080/v1/models/model:predict -H "Content-Type: application/json" -d '{"instances":[[15,1,0.01,0.036]]}' 2>/dev/null)
echo $PRED | grep -q "predictions" && echo "✅ Working" || echo "❌ Failed"

# Check demo-app
echo -n "8. Demo app namespace: "
oc get ns demo-app &>/dev/null && echo "✅ Exists" || echo "⚠️ Not deployed (run deploy-demo-apps.sh)"

echo ""
echo "========================================"
echo "Run 'deploy-demo-apps.sh' if demo apps not deployed"
```

## 4.2 Quick Reset Script

```bash
#!/bin/bash
# reset-demo.sh

echo "🔄 Resetting demo environment..."

# Delete and recreate demo apps
oc delete namespace demo-app --ignore-not-found --wait=false
sleep 5
oc create namespace demo-app
oc label namespace demo-app demo=self-healing

# Redeploy apps
./deploy-demo-apps.sh

# Restart KServe predictors (in case of issues)
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=predictive-analytics --force --grace-period=0
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector --force --grace-period=0

echo "⏳ Waiting for pods to stabilize..."
sleep 30

echo "✅ Demo environment reset!"
oc get pods -n demo-app
oc get pods -n self-healing-platform | grep -E "predictor|coordination|mcp"
```

---

# Part 5: Backup Commands (If Things Go Wrong)

## 5.1 MCP Server Not Responding
```bash
oc rollout restart deployment/mcp-server -n self-healing-platform
oc logs -f deployment/mcp-server -n self-healing-platform
```

## 5.2 Coordination Engine Not Responding
```bash
oc rollout restart deployment/coordination-engine -n self-healing-platform
oc logs -f deployment/coordination-engine -n self-healing-platform
```

## 5.3 KServe Models Not Working
```bash
# Check model status
oc get inferenceservice -n self-healing-platform

# Restart predictors
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=predictive-analytics --force --grace-period=0
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector --force --grace-period=0

# Wait and verify
sleep 40
oc get pods -n self-healing-platform | grep predictor
```

## 5.4 Predictions Showing 100%
```bash
# This means model output format is wrong - needs decimals not percentages
# Re-run the predictive-scaling-capacity-planning.ipynb notebook in Jupyter
# Make sure training data divides by 100
```

## 5.5 NetworkPolicy Issues
```bash
# Check NetworkPolicy
oc get networkpolicy -n self-healing-platform

# Verify Lightspeed can reach MCP
oc get networkpolicy allow-lightspeed -n self-healing-platform -o yaml
```

---

# Part 6: Key Talking Points

## Why This Matters
- "Traditional monitoring tells you what happened. This platform tells you what WILL happen."
- "We're not just alerting - we're predicting and recommending."
- "Models trained on YOUR cluster's real data, not generic patterns."

## Technical Differentiators
- "Hybrid approach: deterministic rules for known issues, ML for pattern detection"
- "Real Prometheus metrics, not synthetic data"
- "KServe for scalable model serving, not embedded models"

## Architecture Highlights
- "MCP is the interface - it doesn't make decisions"
- "Coordination Engine is the brain - hybrid logic + ML"
- "Simple queries stay simple, complex queries get intelligence"

---

# Quick Reference Card

| What You Want | Lightspeed Prompt |
|---------------|-------------------|
| Cluster health | "What's the health of {namespace}?" |
| Failing pods | "Show me failing pods in {namespace}" |
| Pod logs | "Get logs from {pod} in {namespace}" |
| CPU prediction | "Predict CPU usage for {namespace}" |
| Memory prediction | "Predict memory usage for {namespace}" |
| Anomaly detection | "Detect anomalies in {namespace}" |
| Fix recommendations | "How do I fix {issue}?" |

---

**Demo Duration:** ~7 minutes
**Prep Time:** ~5 minutes (deploy demo apps, verify components)
**Reset Time:** ~2 minutes (if needed)
