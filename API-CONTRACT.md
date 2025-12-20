# API Contract: Go Coordination Engine

This document defines the **two critical integration boundaries** for the Go Coordination Engine.

## 1. Upstream API (Consumed by MCP Server)

The Go engine exposes the same REST API as the current Python coordination engine so that the MCP server does not need code changes.

### Base URL
- `http://coordination-engine:8080/api/v1`

### Endpoints

#### `GET /health`
Health check endpoint.

**Response** (200 OK):
```json
{
  "status": "healthy",
  "timestamp": "2025-12-18T10:00:00Z",
  "version": "1.0.0",
  "dependencies": {
    "kubernetes": "ok",
    "ml_service": "ok",
    "argocd": "ok"
  }
}
```

#### `POST /remediation/trigger`
Trigger a remediation workflow.

**Request Body**:
```json
{
  "incident_id": "inc-12345",
  "namespace": "production",
  "resource": {
    "kind": "Deployment",
    "name": "payment-service"
  },
  "issue": {
    "type": "pod_crash_loop",
    "description": "Pods in CrashLoopBackOff",
    "severity": "high"
  }
}
```

**Response** (202 Accepted):
```json
{
  "workflow_id": "wf-67890",
  "status": "in_progress",
  "deployment_method": "argocd",
  "estimated_duration": "5m"
}
```

#### `GET /incidents`
List recent incidents and their remediation status.

**Query Parameters**:
- `namespace` (optional): Filter by namespace
- `severity` (optional): Filter by severity (low, medium, high, critical)
- `limit` (optional, default: 50): Max results

**Response** (200 OK):
```json
{
  "incidents": [
    {
      "id": "inc-12345",
      "namespace": "production",
      "resource": "Deployment/payment-service",
      "issue_type": "pod_crash_loop",
      "severity": "high",
      "created_at": "2025-12-18T09:45:00Z",
      "status": "remediated",
      "workflow_id": "wf-67890"
    }
  ],
  "total": 1
}
```

#### `GET /workflows/{id}`
Get workflow execution details.

**Response** (200 OK):
```json
{
  "id": "wf-67890",
  "incident_id": "inc-12345",
  "status": "completed",
  "deployment_method": "argocd",
  "layers": ["application"],
  "steps": [
    {
      "order": 0,
      "layer": "application",
      "description": "Trigger ArgoCD sync for payment-service",
      "status": "completed",
      "started_at": "2025-12-18T09:50:00Z",
      "completed_at": "2025-12-18T09:52:00Z"
    }
  ],
  "checkpoints": [
    {
      "layer": "application",
      "after_step": 0,
      "status": "passed",
      "checks": ["pods_running", "endpoints_healthy"]
    }
  ],
  "created_at": "2025-12-18T09:50:00Z",
  "completed_at": "2025-12-18T09:52:00Z"
}
```

For details, see:
- MCP ADR-006: Integration Architecture
- MCP ADR-014: Go Coordination Engine Integration (to be created)

## 2. Downstream API (Python ML Service)

The Go engine calls the existing Python ML service for anomaly detection and predictions.

### Base URL
- `http://aiops-ml-service:8080`

### Endpoints

#### `POST /api/v1/anomaly/detect`
Detect anomalies in metrics data.

**Request Body**:
```json
{
  "metrics": [
    {
      "timestamp": "2025-12-18T10:00:00Z",
      "metric_name": "pod_cpu_usage",
      "value": 0.85,
      "labels": {
        "namespace": "production",
        "pod": "payment-service-abc123"
      }
    }
  ],
  "model": "isolation_forest",
  "threshold": 0.7
}
```

**Response** (200 OK):
```json
{
  "anomalies": [
    {
      "timestamp": "2025-12-18T10:00:00Z",
      "metric_name": "pod_cpu_usage",
      "score": 0.92,
      "is_anomaly": true,
      "severity": "high"
    }
  ],
  "overall_score": 0.92,
  "confidence": 0.88
}
```

#### `POST /api/v1/prediction/predict`
Predict future issues based on current state.

**Request Body**:
```json
{
  "namespace": "production",
  "resource": "Deployment/payment-service",
  "current_state": {
    "replicas": 3,
    "cpu_usage": 0.75,
    "memory_usage": 0.80,
    "error_rate": 0.02
  },
  "prediction_horizon": "1h"
}
```

**Response** (200 OK):
```json
{
  "predictions": [
    {
      "issue_type": "memory_pressure",
      "probability": 0.85,
      "expected_time": "45m",
      "severity": "high",
      "recommended_actions": [
        "increase_memory_limit",
        "add_horizontal_scaling"
      ]
    }
  ],
  "confidence": 0.82
}
```

#### `POST /api/v1/pattern/analyze`
Analyze patterns in historical data.

**Request Body**:
```json
{
  "namespace": "production",
  "time_range": {
    "start": "2025-12-18T00:00:00Z",
    "end": "2025-12-18T10:00:00Z"
  },
  "resource_types": ["Deployment", "StatefulSet"]
}
```

**Response** (200 OK):
```json
{
  "patterns": [
    {
      "pattern_type": "recurring_crash",
      "frequency": "every 2h",
      "affected_resources": ["Deployment/payment-service"],
      "confidence": 0.88,
      "root_cause_hints": ["memory_leak", "connection_timeout"]
    }
  ]
}
```

### Go Client Implementation

```go
// internal/integrations/ml_service_client.go
package integrations

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"
)

type MLServiceClient struct {
    baseURL    string
    httpClient *http.Client
}

func NewMLServiceClient(baseURL string) *MLServiceClient {
    return &MLServiceClient{
        baseURL: baseURL,
        httpClient: &http.Client{
            Timeout: 30 * time.Second,
        },
    }
}

// DetectAnomaly calls Python ML service to detect anomalies
func (c *MLServiceClient) DetectAnomaly(
    ctx context.Context,
    req *AnomalyDetectionRequest,
) (*AnomalyDetectionResponse, error) {
    url := fmt.Sprintf("%s/api/v1/anomaly/detect", c.baseURL)
    
    body, err := json.Marshal(req)
    if err != nil {
        return nil, fmt.Errorf("marshal request: %w", err)
    }
    
    httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
    if err != nil {
        return nil, fmt.Errorf("create request: %w", err)
    }
    httpReq.Header.Set("Content-Type", "application/json")
    
    resp, err := c.httpClient.Do(httpReq)
    if err != nil {
        return nil, fmt.Errorf("send request: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
    }
    
    var result AnomalyDetectionResponse
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, fmt.Errorf("decode response: %w", err)
    }
    
    return &result, nil
}

// Predict calls Python ML service for predictions
func (c *MLServiceClient) Predict(
    ctx context.Context,
    req *PredictionRequest,
) (*PredictionResponse, error) {
    url := fmt.Sprintf("%s/api/v1/prediction/predict", c.baseURL)
    // Similar implementation to DetectAnomaly
    // ...
}
```

## Compatibility Guarantees

- MCP server continues to work unchanged
- Python ML service interface remains stable
- Only the orchestration implementation changes (Python → Go)


