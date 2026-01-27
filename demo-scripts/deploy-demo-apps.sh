#!/bin/bash
# deploy-demo-apps.sh
# Self-Healing Platform Demo - Red Hat One 2026

set -e

echo "🚀 Deploying demo applications..."
echo "================================="

# Create namespace
echo "📁 Creating demo-app namespace..."
oc create namespace demo-app 2>/dev/null || true
oc label namespace demo-app demo=self-healing --overwrite

# Payment Service (CrashLoopBackOff)
echo ""
echo "📦 Deploying payment-service (will CrashLoopBackOff)..."
cat <<'EOF' | oc apply -f -
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
        command: ['sh', '-c', 'echo "Payment Service v2.1.0 Starting..." && echo "Initializing payment gateway..." && sleep 3 && echo "Connecting to database at db.payments.svc..." && sleep 2 && echo "ERROR: Connection refused - database not responding" && exit 1']
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF

# Order Service (OOMKilled)
echo ""
echo "📦 Deploying order-service (will OOMKilled)..."
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
        command: ['python', '-c', 'import time; print("Order Service Starting..."); print("Loading order cache..."); data = []; [data.extend([0]*10000000) or time.sleep(0.5) for _ in range(100)]']
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

# Inventory Service (High CPU)
echo ""
echo "📦 Deploying inventory-service (high CPU)..."
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
  replicas: 1
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
        command: ['sh', '-c', 'echo "Inventory Service Starting..." && echo "Starting inventory sync loop..." && while true; do :; done']
        resources:
          requests:
            cpu: "100m"
            memory: "32Mi"
          limits:
            cpu: "200m"
            memory: "64Mi"
EOF

# Frontend (Healthy)
echo ""
echo "📦 Deploying frontend (healthy control)..."
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
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: demo-app
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
EOF

echo ""
echo "⏳ Waiting for pods to initialize..."
sleep 15

echo ""
echo "📊 Current pod status:"
echo "======================"
oc get pods -n demo-app -o wide

echo ""
echo "✅ Demo apps deployed!"
echo ""
echo "Expected behavior:"
echo "  - payment-service: CrashLoopBackOff (database connection error)"
echo "  - order-service: OOMKilled (memory leak simulation)"  
echo "  - inventory-service: Running but high CPU"
echo "  - frontend: Running (healthy)"
echo ""
echo "Wait ~2 minutes for CrashLoopBackOff to appear, then run demo!"
