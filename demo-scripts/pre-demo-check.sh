#!/bin/bash
# pre-demo-check.sh
# Self-Healing Platform Demo - Red Hat One 2026

echo ""
echo "🔍 Self-Healing Platform Demo Checklist"
echo "========================================"
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    echo -n "$name: "
    if eval "$cmd" &>/dev/null; then
        echo "✅"
        ((PASS++))
    else
        echo "❌"
        ((FAIL++))
    fi
}

check_output() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    echo -n "$name: "
    if eval "$cmd" 2>/dev/null | grep -q "$expected"; then
        echo "✅"
        ((PASS++))
    else
        echo "❌"
        ((FAIL++))
    fi
}

echo "📦 Platform Components"
echo "----------------------"
check "1. self-healing-platform namespace" "oc get ns self-healing-platform"
check_output "2. MCP Server running" "oc get pods -n self-healing-platform -l app=mcp-server --no-headers" "Running"
check_output "3. Coordination Engine running" "oc get pods -n self-healing-platform -l app=coordination-engine --no-headers" "Running"
check_output "4. Predictive Analytics model" "oc get pods -n self-healing-platform -l serving.kserve.io/inferenceservice=predictive-analytics --no-headers" "Running"
check_output "5. Anomaly Detector model" "oc get pods -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector --no-headers" "Running"
check_output "6. Jupyter Workbench" "oc get pods -n self-healing-platform -l app=self-healing-workbench --no-headers" "Running"

echo ""
echo "🔌 Connectivity Tests"
echo "---------------------"

# Test Coordination Engine health
echo -n "7. Coordination Engine API: "
CE_HEALTH=$(oc exec -n self-healing-platform deployment/mcp-server -- curl -s http://coordination-engine:8080/health 2>/dev/null)
if echo "$CE_HEALTH" | grep -qi "ok\|healthy\|alive"; then
    echo "✅"
    ((PASS++))
else
    echo "❌"
    ((FAIL++))
fi

# Test KServe prediction
echo -n "8. Prediction API (returns decimals): "
PRED=$(oc exec -n self-healing-platform self-healing-workbench-0 -- curl -s -X POST http://predictive-analytics-predictor:8080/v1/models/model:predict -H "Content-Type: application/json" -d '{"instances":[[15,1,0.01,0.036]]}' 2>/dev/null)
if echo "$PRED" | grep -q '"predictions":\[\[0\.' ; then
    echo "✅ (outputs decimals correctly)"
    ((PASS++))
elif echo "$PRED" | grep -q '"predictions"'; then
    echo "⚠️ (working but check output format)"
    ((PASS++))
else
    echo "❌"
    ((FAIL++))
fi

# Test Anomaly Detector
echo -n "9. Anomaly Detector API: "
ANOM=$(oc exec -n self-healing-platform self-healing-workbench-0 -- curl -s -X POST http://anomaly-detector-predictor:8080/v1/models/model:predict -H "Content-Type: application/json" -d '{"instances":[[0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5,0.6,0.3,0.4,0.5]]}' 2>/dev/null)
if echo "$ANOM" | grep -q '"predictions"'; then
    echo "✅"
    ((PASS++))
else
    echo "❌"
    ((FAIL++))
fi

echo ""
echo "🎭 Demo Applications"
echo "--------------------"
check "10. demo-app namespace exists" "oc get ns demo-app"

if oc get ns demo-app &>/dev/null; then
    echo ""
    echo "    Pod Status in demo-app:"
    oc get pods -n demo-app --no-headers 2>/dev/null | while read line; do
        name=$(echo $line | awk '{print $1}')
        status=$(echo $line | awk '{print $3}')
        if [[ "$status" == "Running" ]]; then
            echo "    - $name: ✅ $status"
        elif [[ "$status" == "CrashLoopBackOff" ]]; then
            echo "    - $name: 🔴 $status (expected for demo)"
        elif [[ "$status" == "OOMKilled" ]]; then
            echo "    - $name: 🟠 $status (expected for demo)"
        else
            echo "    - $name: ⚠️ $status"
        fi
    done
else
    echo "    ⚠️ Run ./deploy-demo-apps.sh to deploy demo applications"
fi

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✅ All checks passed! Ready for demo."
else
    echo "⚠️ Some checks failed. Review above and fix before demo."
    echo ""
    echo "Quick fixes:"
    echo "  - MCP/CE not running: oc rollout restart deployment/{name} -n self-healing-platform"
    echo "  - Models not running: oc delete pod -l serving.kserve.io/inferenceservice={name} -n self-healing-platform"
    echo "  - Demo apps missing: ./deploy-demo-apps.sh"
fi
echo ""
