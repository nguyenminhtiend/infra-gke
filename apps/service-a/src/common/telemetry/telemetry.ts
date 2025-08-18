import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { TraceExporter } from '@google-cloud/opentelemetry-cloud-trace-exporter';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

export function setupTelemetry() {
  const serviceName = process.env.OTEL_SERVICE_NAME || 'service-a';
  const serviceVersion = '1.0.0';
  const nodeEnv = process.env.NODE_ENV || 'development';

  // Create resource with service information
  const resource = new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: serviceName,
    [SemanticResourceAttributes.SERVICE_VERSION]: serviceVersion,
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: nodeEnv,
  });

  let traceExporter;

  if (nodeEnv === 'production') {
    // Use Google Cloud Trace in production
    traceExporter = new TraceExporter({
      projectId: process.env.GOOGLE_CLOUD_PROJECT,
      keyFilename: process.env.GOOGLE_APPLICATION_CREDENTIALS,
    });
  } else {
    // Console exporter for development
    const { ConsoleSpanExporter } = require('@opentelemetry/sdk-tracing-base');
    traceExporter = new ConsoleSpanExporter();
  }

  // Initialize the SDK with auto-instrumentations
  const sdk = new NodeSDK({
    resource,
    traceExporter,
    instrumentations: [
      getNodeAutoInstrumentations({
        // Disable fs instrumentation to reduce noise
        '@opentelemetry/instrumentation-fs': {
          enabled: false,
        },
        // Configure HTTP instrumentation
        '@opentelemetry/instrumentation-http': {
          enabled: true,
          ignoreIncomingRequestHook: (req) => {
            // Ignore health check endpoints from tracing
            return req.url?.includes('/health') ||
                   req.url?.includes('/ready') ||
                   req.url?.includes('/live');
          },
        },
        // Configure Express instrumentation
        '@opentelemetry/instrumentation-express': {
          enabled: true,
        },
        // Configure NestJS instrumentation
        '@opentelemetry/instrumentation-nestjs-core': {
          enabled: true,
        },
      }),
    ],
  });

  // Start the SDK
  sdk.start();

  console.log('OpenTelemetry initialized successfully');

  // Graceful shutdown
  process.on('SIGTERM', () => {
    sdk.shutdown()
      .then(() => console.log('OpenTelemetry terminated'))
      .catch((error) => console.log('Error terminating OpenTelemetry', error))
      .finally(() => process.exit(0));
  });
}
