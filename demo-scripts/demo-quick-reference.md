# Self-Healing Platform Demo - Quick Reference Card
## Red Hat One 2026 | Sangz & Tosin Akinosho

---

## 🎯 Lightspeed Prompts (Copy-Paste Ready)

### Cluster Health (Direct K8s API)
```
What's the health status of demo-app namespace?
```
```
Show me all pods that are not running in demo-app
```
```
Why is payment-service crashing in demo-app?
```
```
Show me recent warning events in demo-app namespace
```

### Predictions (ML via Coordination Engine)
```
Predict CPU usage for openshift-monitoring namespace
```
```
Predict memory usage for self-healing-platform namespace
```

### Anomaly Detection (ML via Coordination Engine)
```
Detect anomalies in openshift-monitoring namespace
```
```
Are there any unusual patterns in demo-app?
```

---

## 🎬 Demo Flow (7 minutes)

| Time | Action | Expected Result |
|------|--------|-----------------|
| 0:00 | "What's the health of demo-app?" | Shows CrashLoopBackOff pods |
| 1:00 | "Why is payment-service crashing?" | Shows logs with database error |
| 2:00 | "Predict CPU usage for openshift-monitoring" | Shows ~56% prediction |
| 3:30 | "Detect anomalies in demo-app" | Shows anomaly detected |
| 5:00 | Show architecture slide | Explain MCP → CE → KServe flow |
| 6:00 | Q&A | |

---

## 🔧 Emergency Commands

### If predictions show 100%:
```bash
# Model output format wrong - restart predictor
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=predictive-analytics --force
```

### If Lightspeed not connecting:
```bash
oc rollout restart deployment/mcp-server -n self-healing-platform
```

### If demo apps gone:
```bash
./deploy-demo-apps.sh
```

### Full reset:
```bash
./reset-demo.sh
```

---

## 📊 Expected Demo App States

| App | Status | Why |
|-----|--------|-----|
| payment-service | 🔴 CrashLoopBackOff | Simulated DB connection failure |
| order-service | 🟠 OOMKilled | Memory leak simulation |
| frontend | 🟢 Running | Healthy control |

---

## 💬 Key Talking Points

1. **"Real data, not synthetic"** - Models trained on actual Prometheus metrics
2. **"Hybrid approach"** - Deterministic rules + ML predictions  
3. **"Simple stays simple"** - Health queries bypass ML, go direct to K8s
4. **"Predictions go through the brain"** - CE orchestrates ML inference

---

## 🏗️ Architecture One-Liner

> Lightspeed → MCP (interface) → Coordination Engine (brain) → KServe (ML) + Prometheus (metrics)

---

## ✅ Pre-Demo Checklist

```bash
./pre-demo-check.sh
```

All green? You're ready! 🚀
