package config

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoad_Defaults(t *testing.T) {
	// Clear all relevant environment variables
	clearEnv(t)

	cfg, err := Load()
	require.NoError(t, err)
	require.NotNil(t, cfg)

	// Verify defaults
	assert.Equal(t, DefaultPort, cfg.Port)
	assert.Equal(t, DefaultMetricsPort, cfg.MetricsPort)
	assert.Equal(t, DefaultLogLevel, cfg.LogLevel)
	assert.Equal(t, DefaultNamespace, cfg.Namespace)
	assert.Equal(t, DefaultMLServiceURL, cfg.MLServiceURL)
	assert.Equal(t, DefaultHTTPTimeout, cfg.HTTPTimeout)
	assert.Equal(t, float32(DefaultKubernetesQPS), cfg.KubernetesQPS)
	assert.Equal(t, DefaultKubernetesBurst, cfg.KubernetesBurst)
	assert.Equal(t, DefaultEnableCORS, cfg.EnableCORS)
	assert.Equal(t, []string{"*"}, cfg.CORSAllowOrigin)
}

func TestLoad_FromEnvironment(t *testing.T) {
	clearEnv(t)

	// Set environment variables
	os.Setenv("PORT", "9000")
	os.Setenv("METRICS_PORT", "9091")
	os.Setenv("LOG_LEVEL", "debug")
	os.Setenv("NAMESPACE", "test-namespace")
	os.Setenv("ML_SERVICE_URL", "http://test-ml:8080")
	os.Setenv("ARGOCD_API_URL", "https://argocd:8080")
	os.Setenv("HTTP_TIMEOUT", "60s")
	os.Setenv("KUBERNETES_QPS", "100.0")
	os.Setenv("KUBERNETES_BURST", "200")
	os.Setenv("ENABLE_CORS", "true")
	os.Setenv("CORS_ALLOW_ORIGIN", "http://localhost:3000,https://example.com")
	defer clearEnv(t)

	cfg, err := Load()
	require.NoError(t, err)
	require.NotNil(t, cfg)

	assert.Equal(t, 9000, cfg.Port)
	assert.Equal(t, 9091, cfg.MetricsPort)
	assert.Equal(t, "debug", cfg.LogLevel)
	assert.Equal(t, "test-namespace", cfg.Namespace)
	assert.Equal(t, "http://test-ml:8080", cfg.MLServiceURL)
	assert.Equal(t, "https://argocd:8080", cfg.ArgocdAPIURL)
	assert.Equal(t, 60*time.Second, cfg.HTTPTimeout)
	assert.Equal(t, float32(100.0), cfg.KubernetesQPS)
	assert.Equal(t, 200, cfg.KubernetesBurst)
	assert.Equal(t, true, cfg.EnableCORS)
	assert.Equal(t, []string{"http://localhost:3000", "https://example.com"}, cfg.CORSAllowOrigin)
}

func TestValidate_ValidConfig(t *testing.T) {
	cfg := &Config{
		Port:            8080,
		MetricsPort:     9090,
		LogLevel:        "info",
		Namespace:       "default",
		MLServiceURL:    "http://ml-service:8080",
		HTTPTimeout:     30 * time.Second,
		KubernetesQPS:   50.0,
		KubernetesBurst: 100,
	}

	err := cfg.Validate()
	assert.NoError(t, err)
}

func TestValidate_InvalidPort(t *testing.T) {
	tests := []struct {
		name        string
		port        int
		metricsPort int
		wantError   bool
	}{
		{"port too low", 0, 9090, true},
		{"port too high", 70000, 9090, true},
		{"metrics port too low", 8080, 0, true},
		{"metrics port too high", 8080, 70000, true},
		{"same ports", 8080, 8080, true},
		{"valid ports", 8080, 9090, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				Port:            tt.port,
				MetricsPort:     tt.metricsPort,
				LogLevel:        "info",
				Namespace:       "default",
				MLServiceURL:    "http://ml:8080",
				HTTPTimeout:     30 * time.Second,
				KubernetesQPS:   50.0,
				KubernetesBurst: 100,
			}
			err := cfg.Validate()
			if tt.wantError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestValidate_InvalidLogLevel(t *testing.T) {
	cfg := &Config{
		Port:            8080,
		MetricsPort:     9090,
		LogLevel:        "invalid",
		Namespace:       "default",
		MLServiceURL:    "http://ml:8080",
		HTTPTimeout:     30 * time.Second,
		KubernetesQPS:   50.0,
		KubernetesBurst: 100,
	}

	err := cfg.Validate()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid log_level")
}

func TestValidate_EmptyNamespace(t *testing.T) {
	cfg := &Config{
		Port:            8080,
		MetricsPort:     9090,
		LogLevel:        "info",
		Namespace:       "",
		MLServiceURL:    "http://ml:8080",
		HTTPTimeout:     30 * time.Second,
		KubernetesQPS:   50.0,
		KubernetesBurst: 100,
	}

	err := cfg.Validate()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "namespace cannot be empty")
}

func TestValidate_InvalidMLServiceURL(t *testing.T) {
	tests := []struct {
		name      string
		url       string
		wantError bool
	}{
		{"empty url", "", true},
		{"no protocol", "ml-service:8080", true},
		{"ftp protocol", "ftp://ml-service:8080", true},
		{"http valid", "http://ml-service:8080", false},
		{"https valid", "https://ml-service:8080", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				Port:            8080,
				MetricsPort:     9090,
				LogLevel:        "info",
				Namespace:       "default",
				MLServiceURL:    tt.url,
				HTTPTimeout:     30 * time.Second,
				KubernetesQPS:   50.0,
				KubernetesBurst: 100,
			}
			err := cfg.Validate()
			if tt.wantError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestValidate_InvalidArgocdURL(t *testing.T) {
	tests := []struct {
		name      string
		url       string
		wantError bool
	}{
		{"empty url (optional)", "", false},
		{"no protocol", "argocd:8080", true},
		{"http valid", "http://argocd:8080", false},
		{"https valid", "https://argocd:8080", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				Port:            8080,
				MetricsPort:     9090,
				LogLevel:        "info",
				Namespace:       "default",
				MLServiceURL:    "http://ml:8080",
				ArgocdAPIURL:    tt.url,
				HTTPTimeout:     30 * time.Second,
				KubernetesQPS:   50.0,
				KubernetesBurst: 100,
			}
			err := cfg.Validate()
			if tt.wantError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestValidate_InvalidHTTPTimeout(t *testing.T) {
	tests := []struct {
		name      string
		timeout   time.Duration
		wantError bool
	}{
		{"too short", 500 * time.Millisecond, true},
		{"minimum valid", 1 * time.Second, false},
		{"normal", 30 * time.Second, false},
		{"maximum valid", 5 * time.Minute, false},
		{"too long", 10 * time.Minute, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				Port:            8080,
				MetricsPort:     9090,
				LogLevel:        "info",
				Namespace:       "default",
				MLServiceURL:    "http://ml:8080",
				HTTPTimeout:     tt.timeout,
				KubernetesQPS:   50.0,
				KubernetesBurst: 100,
			}
			err := cfg.Validate()
			if tt.wantError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestValidate_InvalidKubernetesSettings(t *testing.T) {
	tests := []struct {
		name      string
		qps       float32
		burst     int
		wantError bool
	}{
		{"negative qps", -1.0, 100, true},
		{"zero qps", 0.0, 100, true},
		{"negative burst", 50.0, -1, true},
		{"zero burst", 50.0, 0, true},
		{"valid settings", 50.0, 100, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				Port:            8080,
				MetricsPort:     9090,
				LogLevel:        "info",
				Namespace:       "default",
				MLServiceURL:    "http://ml:8080",
				HTTPTimeout:     30 * time.Second,
				KubernetesQPS:   tt.qps,
				KubernetesBurst: tt.burst,
			}
			err := cfg.Validate()
			if tt.wantError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestGetEnvAsSlice(t *testing.T) {
	tests := []struct {
		name     string
		envValue string
		expected []string
	}{
		{"single value", "http://localhost:3000", []string{"http://localhost:3000"}},
		{"multiple values", "http://localhost:3000,https://example.com", []string{"http://localhost:3000", "https://example.com"}},
		{"with spaces", "http://localhost:3000 , https://example.com", []string{"http://localhost:3000", "https://example.com"}},
		{"empty string", "", []string{"*"}},
		{"only commas", ",,,", []string{"*"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("TEST_SLICE", tt.envValue)
			defer os.Unsetenv("TEST_SLICE")

			result := getEnvAsSlice("TEST_SLICE", []string{"*"})
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetEnvAsInt(t *testing.T) {
	tests := []struct {
		name     string
		envValue string
		expected int
	}{
		{"valid int", "9000", 9000},
		{"invalid int", "abc", 8080},
		{"empty string", "", 8080},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envValue != "" {
				os.Setenv("TEST_INT", tt.envValue)
				defer os.Unsetenv("TEST_INT")
			}

			result := getEnvAsInt("TEST_INT", 8080)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetEnvAsBool(t *testing.T) {
	tests := []struct {
		name     string
		envValue string
		expected bool
	}{
		{"true lowercase", "true", true},
		{"true uppercase", "TRUE", true},
		{"true number", "1", true},
		{"false lowercase", "false", false},
		{"false uppercase", "FALSE", false},
		{"false number", "0", false},
		{"invalid", "abc", false},
		{"empty", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envValue != "" {
				os.Setenv("TEST_BOOL", tt.envValue)
				defer os.Unsetenv("TEST_BOOL")
			}

			result := getEnvAsBool("TEST_BOOL", false)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetEnvAsDuration(t *testing.T) {
	tests := []struct {
		name     string
		envValue string
		expected time.Duration
	}{
		{"seconds", "30s", 30 * time.Second},
		{"minutes", "2m", 2 * time.Minute},
		{"complex", "1m30s", 90 * time.Second},
		{"invalid", "abc", 30 * time.Second},
		{"empty", "", 30 * time.Second},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envValue != "" {
				os.Setenv("TEST_DURATION", tt.envValue)
				defer os.Unsetenv("TEST_DURATION")
			}

			result := getEnvAsDuration("TEST_DURATION", 30*time.Second)
			assert.Equal(t, tt.expected, result)
		})
	}
}

// clearEnv removes all environment variables used by the config package
func clearEnv(t *testing.T) {
	t.Helper()
	envVars := []string{
		"PORT", "METRICS_PORT", "LOG_LEVEL", "KUBECONFIG", "NAMESPACE",
		"ML_SERVICE_URL", "ARGOCD_API_URL", "HTTP_TIMEOUT",
		"ENABLE_CORS", "CORS_ALLOW_ORIGIN",
		"KUBERNETES_QPS", "KUBERNETES_BURST",
	}
	for _, key := range envVars {
		os.Unsetenv(key)
	}
}
