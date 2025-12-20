# ADR-009: Python ML Service Integration

## Status
ACCEPTED - 2025-12-18

## Context

The Go Coordination Engine is responsible for orchestration and remediation. The existing Python ML/AI stack already provides:

- Anomaly detection
- Predictive analytics
- Pattern recognition

Rewriting ML code in Go would be costly and unnecessary. Instead, the Go engine should **consume** the existing Python ML service via REST APIs.

This ADR defines how the Go coordination engine integrates with the Python ML service following the hybrid architecture established in platform ADR-042.

## Decision

- Keep **Python ML service** as a separate deployment (`aiops-ml-service`).
- Implement a **Go HTTP client** in `internal/integrations/ml_service_client.go` to call Python ML endpoints.
- Treat Python ML as a required downstream dependency for the Go engine.
- Use circuit breakers and graceful degradation when ML service is unavailable.

## Python ML Service API Contract

### Base URL
- Development: `http://aiops-ml-service:8080`
- Production: Configured via `ML_SERVICE_URL` environment variable

### Endpoints

#### Anomaly Detection
```http
POST /api/v1/anomaly/detect
Content-Type: application/json

{
  "metrics": [
    {"name": "cpu_usage", "value": 85.5, "timestamp": "2025-12-18T10:00:00Z"},
    {"name": "memory_usage", "value": 92.3, "timestamp": "2025-12-18T10:00:00Z"}
  ],
  "context": {
    "namespace": "production",
    "resource": "payment-service"
  }
}

Response 200 OK:
{
  "anomaly_detected": true,
  "confidence": 0.95,
  "anomaly_score": 8.7,
  "recommendations": ["Scale up replicas", "Check for memory leak"]
}
```

#### Prediction
```http
POST /api/v1/prediction/predict
Content-Type: application/json

{
  "issue_context": {
    "current_state": "degraded",
    "recent_events": ["pod_restart", "high_cpu"],
    "metrics": [...]
  }
}

Response 200 OK:
{
  "predicted_issues": [
    {"issue": "pod_oom", "probability": 0.85, "time_to_occurrence": "5m"}
  ],
  "suggested_actions": ["increase_memory_limit", "add_hpa"]
}
```

#### Pattern Analysis
```http
POST /api/v1/pattern/analyze
Content-Type: application/json

{
  "historical_data": {
    "time_range": "24h",
    "events": [...]
  }
}

Response 200 OK:
{
  "patterns": [
    {"pattern": "daily_spike", "confidence": 0.88}
  ],
  "correlations": [...]
}
```

## Go Implementation

### ML Service Client

Package: `internal/integrations/ml_service_client.go`

```go
package integrations

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"
)

type MLServiceClient struct {
    baseURL    string
    httpClient *http.Client
    circuitBreaker *CircuitBreaker
}

type AnomalyRequest struct {
    Metrics []Metric `json:"metrics"`
    Context RequestContext `json:"context"`
}

type AnomalyResponse struct {
    AnomalyDetected bool     `json:"anomaly_detected"`
    Confidence      float64  `json:"confidence"`
    AnomalyScore    float64  `json:"anomaly_score"`
    Recommendations []string `json:"recommendations"`
}

func NewMLServiceClient(baseURL string) *MLServiceClient {
    return &MLServiceClient{
        baseURL: baseURL,
        httpClient: &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                MaxIdleConns:        100,
                MaxIdleConnsPerHost: 10,
                IdleConnTimeout:     90 * time.Second,
            },
        },
        circuitBreaker: NewCircuitBreaker(3, 30*time.Second),
    }
}

func (c *MLServiceClient) DetectAnomaly(ctx context.Context, req *AnomalyRequest) (*AnomalyResponse, error) {
    // Circuit breaker check
    if !c.circuitBreaker.Allow() {
        return nil, fmt.Errorf("ML service circuit breaker open")
    }

    url := fmt.Sprintf("%s/api/v1/anomaly/detect", c.baseURL)

    // Make HTTP request with context
    // ... implementation

    return &AnomalyResponse{}, nil
}
```

### Circuit Breaker Pattern

```go
type CircuitBreaker struct {
    maxFailures int
    resetTimeout time.Duration
    failures int
    lastFailTime time.Time
    state string // "closed", "open", "half-open"
}

func (cb *CircuitBreaker) Allow() bool {
    // Circuit breaker logic
    if cb.state == "open" {
        if time.Since(cb.lastFailTime) > cb.resetTimeout {
            cb.state = "half-open"
            return true
        }
        return false
    }
    return true
}
```

### Graceful Degradation

When ML service is unavailable:
- Log warning and continue with rule-based remediation
- Use cached ML predictions if available
- Emit metrics for monitoring
- Return degraded status in health endpoint

## Consequences

### Positive
- ✅ Go engine leverages Python's ML ecosystem without reimplementing
- ✅ Independent deployment and scaling of ML service
- ✅ Clear separation of concerns (orchestration vs ML/AI)
- ✅ Circuit breaker prevents cascading failures
- ✅ Connection pooling optimizes network usage

### Negative
- ⚠️ Network latency for ML predictions
- ⚠️ ML service is a single point of failure (mitigated by circuit breaker)
- ⚠️ Must maintain API contract between Go and Python
- ⚠️ Additional complexity in testing (requires mock ML service)

### Mitigation Strategies
- **Latency**: Cache ML predictions, use async calls where possible
- **Reliability**: Circuit breaker, graceful degradation, health checks
- **Contract**: OpenAPI spec, contract tests, versioned API
- **Testing**: Comprehensive mock server, integration test suite

## Configuration

Environment variables:
```bash
ML_SERVICE_URL=http://aiops-ml-service:8080  # ML service base URL
ML_SERVICE_TIMEOUT=30s                        # HTTP request timeout
ML_CIRCUIT_BREAKER_THRESHOLD=3                # Failures before circuit opens
ML_CIRCUIT_BREAKER_TIMEOUT=30s                # Time before retry
```

## Testing Strategy

1. **Unit Tests**: Mock HTTP client, test error handling
2. **Integration Tests**: Mock ML service server, test full request/response cycle
3. **Contract Tests**: Validate API compatibility with Python service
4. **Performance Tests**: Measure latency, connection pooling efficiency

## References

- Platform ADR-042: Go-Based Coordination Engine (Section 3: Python AI/ML Service)
- Python ML service repository: `/home/lab-user/openshift-aiops-platform` (to be extracted)
- Go HTTP client best practices: https://github.com/hashicorp/go-cleanhttp
- Circuit breaker pattern: https://martinfowler.com/bliki/CircuitBreaker.html

## Related ADRs

- ADR-001: Go Project Architecture (package organization)
- Platform ADR-042: Go-Based Coordination Engine (overall hybrid architecture)


