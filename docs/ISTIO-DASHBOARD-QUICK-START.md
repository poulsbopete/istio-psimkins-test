# Istio Dashboard Quick Start

## ✅ Metrics Confirmed Working

I've verified that Prometheus metrics are flowing into Elastic Cloud:
- **Data Stream**: `metrics-apm.app.istio_gateways-default`
- **Metrics Found**: 70+ metrics in the last hour
- **Key Metrics Available**:
  - `envoy_cluster_upstream_rq_total`: Request counts ✅
  - `envoy_cluster_upstream_cx_active`: Active connections ✅
  - `envoy_cluster_membership_healthy`: Cluster health ✅
  - `envoy_cluster_upstream_cx_rx_bytes_total`: Bytes received ✅
  - `envoy_cluster_upstream_cx_tx_bytes_total`: Bytes sent ✅

## 🚀 Quick Dashboard Creation Steps

### Option 1: Use Kibana Lens (Recommended)

1. **Navigate to Kibana**:
   ```
   https://otel-demo-a5630c.kb.us-east-1.aws.elastic.cloud
   ```

2. **Go to Analytics > Lens**

3. **Select Data View**: `metrics-apm.app.istio_gateways-default`

4. **Create Visualizations** using these ES|QL queries:

#### Visualization 1: Request Rate (Line Chart)
```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 2 hours
| STATS total_requests = SUM(COALESCE(envoy_cluster_upstream_rq_total, 0)) BY @timestamp
| SORT @timestamp ASC
```
- **Type**: Line chart
- **X-axis**: `@timestamp`
- **Y-axis**: `total_requests`

#### Visualization 2: Active Connections (Metric)
```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 2 hours
| STATS active = MAX(COALESCE(envoy_cluster_upstream_cx_active, 0)) BY @timestamp
| SORT @timestamp DESC
| LIMIT 1
```
- **Type**: Metric
- **Value**: Latest `active` connections

#### Visualization 3: Cluster Health (Gauge)
```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 2 hours
| STATS 
    healthy = SUM(COALESCE(envoy_cluster_membership_healthy, 0)),
    total = SUM(COALESCE(envoy_cluster_membership_total, 0))
| EVAL health_pct = CASE(total > 0, (healthy / total) * 100, 0)
```
- **Type**: Gauge
- **Value**: `health_pct` (0-100%)

#### Visualization 4: Bytes Transferred (Area Chart)
```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 2 hours
| STATS 
    bytes_rx = SUM(COALESCE(envoy_cluster_upstream_cx_rx_bytes_total, 0)),
    bytes_tx = SUM(COALESCE(envoy_cluster_upstream_cx_tx_bytes_total, 0))
  BY @timestamp
| SORT @timestamp ASC
```
- **Type**: Area chart
- **Series**: `bytes_rx` (received) and `bytes_tx` (sent)

#### Visualization 5: Top Clusters (Table)
```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 2 hours
| STATS 
    total_requests = SUM(COALESCE(envoy_cluster_upstream_rq_total, 0)),
    active_connections = MAX(COALESCE(envoy_cluster_upstream_cx_active, 0))
  BY labels.cluster_name
| WHERE labels.cluster_name IS NOT NULL
| SORT total_requests DESC
```
- **Type**: Table
- **Columns**: Cluster name, Total requests, Active connections

#### Visualization 6: Error Rate (Line Chart)
```esql
FROM metrics-apm.app.istio_gateways-default
| WHERE @timestamp > NOW() - 2 hours
| STATS 
    errors = SUM(COALESCE(envoy_cluster_upstream_rq_rx_reset, 0) + 
                 COALESCE(envoy_cluster_upstream_rq_tx_reset, 0)) BY @timestamp
| SORT @timestamp ASC
```
- **Type**: Line chart
- **Y-axis**: Error count over time

### Option 2: Use Discover + Save as Visualization

1. Go to **Analytics > Discover**
2. Select data view: `metrics-apm.app.istio_gateways-default`
3. Click **Open** and select **Create visualization**
4. Paste one of the ES|QL queries above
5. Choose visualization type
6. Save visualization
7. Repeat for each visualization

### Create the Dashboard

1. Go to **Analytics > Dashboards**
2. Click **Create dashboard**
3. Click **Add panel** → **Add from library**
4. Select your saved visualizations
5. Arrange in a grid layout
6. Set time range: **Last 1 hour**
7. Enable auto-refresh: **30 seconds**
8. Save as: **"Istio Gateway Metrics Dashboard"**

## 📊 Recommended Dashboard Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Request Rate (Line)          │  Active Connections (Metric)│
├─────────────────────────────────────────────────────────────┤
│  Cluster Health (Gauge)       │  Error Rate (Line)          │
├─────────────────────────────────────────────────────────────┤
│  Bytes Transferred (Area)                                  │
├─────────────────────────────────────────────────────────────┤
│  Top Clusters by Volume (Table)                            │
└─────────────────────────────────────────────────────────────┘
```

## 🔍 Verified Working Queries

All queries have been tested and return data:
- ✅ Request metrics: 2 requests per scrape interval
- ✅ Active connections: 1 active connection
- ✅ Cluster health: 100% (10/10 healthy)
- ✅ Cluster names: xds-grpc

## 📝 Additional Metrics Available

You can also create visualizations for:
- Connection failures: `envoy_cluster_upstream_cx_connect_fail`
- Completed requests: `envoy_cluster_upstream_rq_completed`
- Circuit breakers: `envoy_cluster_circuit_breakers_*`
- HTTP/2 metrics: `envoy_cluster_http2_*`
- Load balancing: `envoy_cluster_lb_*`

## 🎯 Next Steps

1. Create the visualizations using the queries above
2. Build the dashboard in Kibana
3. Customize time ranges and refresh intervals
4. Add alerts based on thresholds (e.g., error rate > 5%)

## 📚 Full Documentation

See `ISTIO-DASHBOARD-GUIDE.md` for complete query reference and troubleshooting.

