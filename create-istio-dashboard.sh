#!/bin/bash
# Script to create an Istio-focused dashboard in Elastic Cloud
# Uses the Kibana Saved Objects API

set -e

ELASTIC_ENDPOINT="${ELASTIC_ENDPOINT:-https://otel-demo-a5630c.kb.us-east-1.aws.elastic.cloud}"
ELASTIC_API_KEY="${ELASTIC_API_KEY:-X3JMeTZKa0JqTzZCYWgtaGY5YzI6X3UwY01hZ0tXaEplRExkVHoxeE1XQQ==}"

echo "Creating Istio Dashboard in Elastic Cloud..."

# Dashboard JSON definition
DASHBOARD_JSON=$(cat <<'EOF'
{
  "attributes": {
    "title": "Istio Gateway Metrics Dashboard",
    "description": "Comprehensive dashboard for Istio Gateway Prometheus metrics",
    "version": "1.0.0",
    "panelsJSON": "[{\"version\":\"8.0.0\",\"gridData\":{\"x\":0,\"y\":0,\"w\":24,\"h\":15,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{\"title\":\"Request Rate\",\"vis\":{\"type\":\"timeseries\",\"params\":{\"axis_formatter\":\"number\",\"axis_position\":\"left\",\"id\":\"1\",\"series\":[{\"id\":\"1\",\"split_mode\":\"everything\",\"metrics\":[{\"id\":\"1\",\"type\":\"count\"}],\"label\":\"Requests\",\"value_template\":\"{{value}}\",\"formatter\":\"number\",\"chart_type\":\"line\",\"line_width\":2,\"point_size\":1,\"fill\":0.5,\"stacked\":\"none\"}],\"grid\":{\"categoryLines\":false,\"style\":{\"color\":\"#eee\"}},\"categoryAxes\":[{\"id\":\"CategoryAxis-1\",\"type\":\"category\",\"position\":\"bottom\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\"},\"labels\":{\"show\":true,\"truncate\":100}}],\"valueAxes\":[{\"id\":\"ValueAxis-1\",\"name\":\"LeftAxis-1\",\"type\":\"value\",\"position\":\"left\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\",\"mode\":\"normal\"},\"labels\":{\"show\":true,\"rotate\":0,\"filter\":false,\"truncate\":100}}],\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"times\":[],\"addTimeMarker\":false}}},\"title\":\"Request Rate\",\"id\":\"1\"},{\"version\":\"8.0.0\",\"gridData\":{\"x\":24,\"y\":0,\"w\":24,\"h\":15,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{\"title\":\"Error Rate\",\"vis\":{\"type\":\"timeseries\",\"params\":{\"axis_formatter\":\"number\",\"axis_position\":\"left\",\"id\":\"1\",\"series\":[{\"id\":\"1\",\"split_mode\":\"everything\",\"metrics\":[{\"id\":\"1\",\"type\":\"count\",\"field\":\"envoy_cluster_upstream_rq_rx_reset\"}],\"label\":\"Errors\",\"value_template\":\"{{value}}\",\"formatter\":\"number\",\"chart_type\":\"line\",\"line_width\":2,\"point_size\":1,\"fill\":0.5,\"stacked\":\"none\"}],\"grid\":{\"categoryLines\":false,\"style\":{\"color\":\"#eee\"}},\"categoryAxes\":[{\"id\":\"CategoryAxis-1\",\"type\":\"category\",\"position\":\"bottom\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\"},\"labels\":{\"show\":true,\"truncate\":100}}],\"valueAxes\":[{\"id\":\"ValueAxis-1\",\"name\":\"LeftAxis-1\",\"type\":\"value\",\"position\":\"left\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\",\"mode\":\"normal\"},\"labels\":{\"show\":true,\"rotate\":0,\"filter\":false,\"truncate\":100}}],\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"times\":[],\"addTimeMarker\":false}}},\"title\":\"Error Rate\",\"id\":\"2\"},{\"version\":\"8.0.0\",\"gridData\":{\"x\":0,\"y\":15,\"w\":24,\"h\":15,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{\"title\":\"Active Connections\",\"vis\":{\"type\":\"metric\",\"params\":{\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\",\"metric\":{\"percentageMode\":false,\"useRanges\":false,\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"None\",\"colorsRange\":[{\"from\":0,\"to\":10000}],\"invertColors\":false,\"labels\":{\"show\":true},\"style\":{\"bgFill\":\"#000\",\"bgColor\":false,\"labelColor\":false,\"subText\":\"\",\"fontSize\":60}}},\"title\":\"Active Connections\",\"id\":\"3\"}},{\"version\":\"8.0.0\",\"gridData\":{\"x\":24,\"y\":15,\"w\":24,\"h\":15,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{\"title\":\"Cluster Health\",\"vis\":{\"type\":\"pie\",\"params\":{\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"isDonut\":true,\"labels\":{\"show\":true,\"values\":true,\"last_level\":true,\"truncate\":100}}},\"title\":\"Cluster Health\",\"id\":\"4\"}}]",
    "optionsJSON": "{\"darkTheme\":false,\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
    "timeRestore": true,
    "timeTo": "now",
    "timeFrom": "now-1h",
    "refreshInterval": {
      "pause": false,
      "value": 30000
    },
    "controlGroupInput": {
      "controlStyle": "oneLine",
      "chainingSystem": "HIERARCHICAL",
      "panelsJSON": "[]"
    }
  },
  "references": [],
  "migrationVersion": {
    "dashboard": "8.0.0"
  },
  "coreMigrationVersion": "8.0.0",
  "type": "dashboard",
  "updated_at": "2025-11-26T18:00:00.000Z"
}
EOF
)

# Create the dashboard using Kibana Saved Objects API
curl -X POST "${ELASTIC_ENDPOINT}/api/saved_objects/dashboard/istio-gateway-metrics-dashboard" \
  -H "Authorization: ApiKey ${ELASTIC_API_KEY}" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d "${DASHBOARD_JSON}"

echo ""
echo "Dashboard created successfully!"
echo "Access it at: ${ELASTIC_ENDPOINT}/app/dashboards#/view/istio-gateway-metrics-dashboard"

