# Istio Gateway Metrics Dashboard Guide

This guide provides ES|QL queries and instructions for creating an Istio-focused dashboard in Elastic Cloud using the Prometheus metrics from `metrics-apm.app.istio_gateways-default`.

## Dashboard Overview

The dashboard will include visualizations for:
1. **Request Rate** - Total requests per second
2. **Error Rate** - Failed requests and error rates
3. **Active Connections** - Current active connections
4. **Cluster Health** - Cluster membership and health status
5. **Request Duration** - Latency metrics
6. **Bytes Transferred** - Network throughput

## ES|QL Queries for Visualizations

### 1. Request Rate (Requests per Second)

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour
| STATS 
    requests_per_sec = RATE(envoy_cluster_upstream_rq_total) BY @timestamp
| SORT @timestamp ASC
```

### 2. Total Requests Over Time

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour AND envoy_cluster_upstream_rq_total IS NOT NULL
| STATS 
    total_requests = SUM(envoy_cluster_upstream_rq_total) BY @timestamp
| SORT @timestamp ASC
```

### 3. Error Rate (Failed Requests)

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour 
  AND (envoy_cluster_upstream_rq_rx_reset IS NOT NULL 
       OR envoy_cluster_upstream_rq_tx_reset IS NOT NULL)
| STATS 
    errors = SUM(COALESCE(envoy_cluster_upstream_rq_rx_reset, 0) + 
                 COALESCE(envoy_cluster_upstream_rq_tx_reset, 0)) BY @timestamp
| SORT @timestamp ASC
```

### 4. Active Connections

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour AND envoy_cluster_upstream_cx_active IS NOT NULL
| STATS 
    active_connections = MAX(envoy_cluster_upstream_cx_active) BY @timestamp
| SORT @timestamp ASC
```

### 5. Cluster Health Status

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour
| STATS 
    healthy = SUM(COALESCE(envoy_cluster_membership_healthy, 0)),
    degraded = SUM(COALESCE(envoy_cluster_membership_degraded, 0)),
    excluded = SUM(COALESCE(envoy_cluster_membership_excluded, 0)),
    total = SUM(COALESCE(envoy_cluster_membership_total, 0))
| EVAL health_percentage = (healthy / total) * 100
```

### 6. Completed Requests

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour AND envoy_cluster_upstream_rq_completed IS NOT NULL
| STATS 
    completed = SUM(envoy_cluster_upstream_rq_completed) BY @timestamp
| SORT @timestamp ASC
```

### 7. Bytes Transferred

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour
| STATS 
    bytes_rx = SUM(COALESCE(envoy_cluster_upstream_cx_rx_bytes_total, 0)),
    bytes_tx = SUM(COALESCE(envoy_cluster_upstream_cx_tx_bytes_total, 0))
  BY @timestamp
| SORT @timestamp ASC
```

### 8. Connection Metrics by Cluster

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour AND labels.cluster_name IS NOT NULL
| STATS 
    total_connections = SUM(COALESCE(envoy_cluster_upstream_cx_total, 0)),
    active_connections = MAX(COALESCE(envoy_cluster_upstream_cx_active, 0)),
    failed_connections = SUM(COALESCE(envoy_cluster_upstream_cx_connect_fail, 0))
  BY labels.cluster_name
| SORT total_connections DESC
```

### 9. Request Status Codes

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour AND labels.response_code IS NOT NULL
| STATS 
    request_count = COUNT(*) BY labels.response_code, labels.response_code_class
| SORT request_count DESC
```

### 10. Top Clusters by Request Volume

```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 1 hour AND labels.cluster_name IS NOT NULL
| STATS 
    total_requests = SUM(COALESCE(envoy_cluster_upstream_rq_total, 0))
  BY labels.cluster_name
| SORT total_requests DESC
| LIMIT 10
```

## Creating the Dashboard in Kibana

### Step 1: Access Kibana
1. Navigate to: `https://otel-demo-a5630c.kb.us-east-1.aws.elastic.cloud`
2. Log in with your credentials

### Step 2: Create Visualizations
1. Go to **Analytics > Discover**
2. Select the data view: `metrics-apm.app.istio_gateways-default`
3. For each query above:
   - Click **Create visualization**
   - Choose visualization type (Line chart, Bar chart, Metric, etc.)
   - Paste the ES|QL query
   - Save the visualization with a descriptive name

### Step 3: Create Dashboard
1. Go to **Analytics > Dashboards**
2. Click **Create dashboard**
3. Click **Add panel** and select your saved visualizations
4. Arrange panels in a grid layout
5. Set dashboard time range to "Last 1 hour" with auto-refresh
6. Save as "Istio Gateway Metrics Dashboard"

## Recommended Panel Layout

```
┌─────────────────────────────────────────────────────────┐
│  Request Rate (Line Chart)        │  Error Rate (Line)  │
├─────────────────────────────────────────────────────────┤
│  Active Connections (Metric)      │  Cluster Health (%) │
├─────────────────────────────────────────────────────────┤
│  Bytes Transferred (Area Chart)                        │
├─────────────────────────────────────────────────────────┤
│  Top Clusters by Volume (Table)                         │
├─────────────────────────────────────────────────────────┤
│  Connection Metrics by Cluster (Bar Chart)              │
└─────────────────────────────────────────────────────────┘
```

## Quick Start: Using Discover

You can also use Discover to explore the metrics:

1. Go to **Analytics > Discover**
2. Select data view: `metrics-apm.app.istio_gateways-default`
3. Use the ES|QL queries above in the query bar
4. Create visualizations directly from Discover results

## Key Metrics to Monitor

- **envoy_cluster_upstream_rq_total**: Total upstream requests
- **envoy_cluster_upstream_rq_completed**: Completed requests
- **envoy_cluster_upstream_cx_active**: Active connections
- **envoy_cluster_upstream_cx_total**: Total connections
- **envoy_cluster_membership_healthy**: Healthy cluster members
- **envoy_cluster_upstream_cx_rx_bytes_total**: Bytes received
- **envoy_cluster_upstream_cx_tx_bytes_total**: Bytes sent
- **envoy_cluster_upstream_rq_rx_reset**: Request resets (errors)

## Troubleshooting

If metrics don't appear:
1. Verify the data stream: `metrics-apm.app.istio_gateways-default`
2. Check time range (metrics are from the last hour)
3. Verify OpenTelemetry Collector is running and scraping
4. Check that Istio ingress gateway is accessible at `192.168.23.0:15090`

