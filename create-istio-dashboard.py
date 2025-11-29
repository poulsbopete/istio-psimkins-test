#!/usr/bin/env python3
"""
Create an Istio-focused dashboard in Elastic Cloud using the Kibana Saved Objects API.
Uses the Prometheus metrics from metrics-apm.app.istio_gateways-default
"""

import json
import requests
import sys
from datetime import datetime

# Configuration
ELASTIC_ENDPOINT = "https://otel-demo-a5630c.kb.us-east-1.aws.elastic.cloud"
ELASTIC_API_KEY = "X3JMeTZKa0JqTzZCYWgtaGY5YzI6X3UwY01hZ0tXaEplRExkVHoxeE1XQQ=="

def create_dashboard():
    """Create the Istio Gateway Metrics Dashboard"""
    
    # Dashboard definition
    dashboard = {
        "attributes": {
            "title": "Istio Gateway Metrics Dashboard",
            "description": "Comprehensive dashboard for Istio Gateway Prometheus metrics from OpenTelemetry Collector",
            "version": "1.0.0",
            "panelsJSON": json.dumps([
                {
                    "version": "8.0.0",
                    "gridData": {"x": 0, "y": 0, "w": 24, "h": 15, "i": "1"},
                    "panelIndex": "1",
                    "embeddableConfig": {
                        "title": "Request Rate",
                        "savedVis": {
                            "title": "Request Rate",
                            "type": "timeseries",
                            "params": {
                                "axis_formatter": "number",
                                "axis_position": "left",
                                "id": "1",
                                "series": [{
                                    "id": "1",
                                    "split_mode": "everything",
                                    "metrics": [{"id": "1", "type": "count"}],
                                    "label": "Requests/sec",
                                    "value_template": "{{value}}",
                                    "formatter": "number",
                                    "chart_type": "line",
                                    "line_width": 2,
                                    "point_size": 1,
                                    "fill": 0.5,
                                    "stacked": "none"
                                }],
                                "grid": {"categoryLines": False, "style": {"color": "#eee"}},
                                "categoryAxes": [{
                                    "id": "CategoryAxis-1",
                                    "type": "category",
                                    "position": "bottom",
                                    "show": True,
                                    "style": {},
                                    "scale": {"type": "linear"},
                                    "labels": {"show": True, "truncate": 100}
                                }],
                                "valueAxes": [{
                                    "id": "ValueAxis-1",
                                    "name": "LeftAxis-1",
                                    "type": "value",
                                    "position": "left",
                                    "show": True,
                                    "style": {},
                                    "scale": {"type": "linear", "mode": "normal"},
                                    "labels": {"show": True, "rotate": 0, "filter": False, "truncate": 100}
                                }],
                                "addTooltip": True,
                                "addLegend": True,
                                "legendPosition": "right",
                                "times": [],
                                "addTimeMarker": False
                            },
                            "aggs": [{
                                "id": "1",
                                "enabled": True,
                                "type": "count",
                                "schema": "metric",
                                "params": {}
                            }, {
                                "id": "2",
                                "enabled": True,
                                "type": "date_histogram",
                                "schema": "segment",
                                "params": {
                                    "field": "@timestamp",
                                    "interval": "auto",
                                    "customInterval": "2h",
                                    "min_doc_count": 1,
                                    "extended_bounds": {}
                                }
                            }]
                        }
                    },
                    "title": "Request Rate",
                    "id": "1"
                }
            ]),
            "optionsJSON": json.dumps({
                "darkTheme": False,
                "useMargins": True,
                "syncColors": False,
                "hidePanelTitles": False
            }),
            "timeRestore": True,
            "timeTo": "now",
            "timeFrom": "now-1h",
            "refreshInterval": {
                "pause": False,
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
        "updated_at": datetime.utcnow().isoformat() + "Z"
    }
    
    # Create dashboard via Kibana Saved Objects API
    url = f"{ELASTIC_ENDPOINT}/api/saved_objects/dashboard/istio-gateway-metrics-dashboard"
    headers = {
        "Authorization": f"ApiKey {ELASTIC_API_KEY}",
        "kbn-xsrf": "true",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(url, headers=headers, json=dashboard, timeout=30)
        response.raise_for_status()
        print(f"✅ Dashboard created successfully!")
        print(f"Access it at: {ELASTIC_ENDPOINT}/app/dashboards#/view/istio-gateway-metrics-dashboard")
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Error creating dashboard: {e}")
        if hasattr(e.response, 'text'):
            print(f"Response: {e.response.text}")
        return False

if __name__ == "__main__":
    success = create_dashboard()
    sys.exit(0 if success else 1)

