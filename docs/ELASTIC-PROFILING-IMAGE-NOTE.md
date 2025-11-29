# Elastic Universal Profiling Agent Image Configuration

## Important Note

The Elastic Universal Profiling agent image in `elastic-profiling-agent.yaml` may need to be updated based on your Elastic deployment.

## Options

### Option 1: Elastic Agent with Profiling Enabled (Recommended)

If you're using Elastic Agent, enable Universal Profiling through the agent configuration:

```yaml
image: docker.elastic.co/beats/elastic-agent:8.15.0
```

Then configure profiling in your Elastic Agent policy in Elastic Cloud.

### Option 2: OpenTelemetry Profiling Agent

Since Elastic contributed the profiling agent to OpenTelemetry, you may be able to use:

```yaml
image: otel/profiling-agent:latest
```

(Note: Verify this image exists and is maintained)

### Option 3: Elastic Cloud Managed Agent

The easiest approach is to use Elastic Cloud's managed agent deployment, which handles the profiling agent automatically.

## Current Configuration

The manifest currently uses:
```yaml
image: docker.elastic.co/beats/elastic-agent:8.15.0
```

This requires additional configuration in Elastic Cloud to enable profiling.

## Next Steps

1. **Check your Elastic Cloud deployment** for the recommended profiling agent setup
2. **Review Elastic documentation**: https://www.elastic.co/guide/en/observability/current/universal-profiling.html
3. **Update the image** in `elastic-profiling-agent.yaml` if needed
4. **Configure profiling** in your Elastic Cloud deployment

## Alternative: Use Elastic Agent Integration

Instead of a standalone DaemonSet, consider using Elastic Agent with the Universal Profiling integration enabled through Elastic Cloud's agent management interface.

