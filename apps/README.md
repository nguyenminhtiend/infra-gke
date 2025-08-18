# Applications - Phase 3 Implementation

This directory contains the application implementations for Phase 3 of the GKE deployment plan.

## 🏗️ Architecture

```
apps/
├── service-a/               # Core business logic service
│   ├── src/
│   │   ├── main.ts         # Application entrypoint with telemetry
│   │   ├── app.module.ts   # Main application module
│   │   ├── health/         # Health check endpoints (/health, /ready, /live)
│   │   ├── common/
│   │   │   ├── logger/     # Structured logging with Cloud Logging
│   │   │   └── telemetry/  # OpenTelemetry instrumentation
│   │   └── config/         # Environment-based configuration
│   ├── k8s/               # Kubernetes manifests with Kustomize
│   │   ├── base/          # Base manifests
│   │   └── overlays/      # Environment-specific overlays
│   ├── Dockerfile         # Multi-stage build with distroless
│   └── package.json
├── service-b/               # Data processing service
│   ├── src/
│   │   ├── main.ts         # Application entrypoint
│   │   ├── processing/     # Data processing endpoints and logic
│   │   ├── health/         # Health check endpoints
│   │   └── common/         # Shared utilities
│   ├── k8s/               # Kubernetes manifests
│   ├── Dockerfile         # Production-ready container
│   └── package.json
└── shared/
    └── libs/
        └── common/         # Shared libraries and utilities
            ├── src/
            │   ├── types/      # Common TypeScript types
            │   ├── utils/      # Utility functions
            │   ├── constants/  # Application constants
            │   ├── decorators/ # Custom NestJS decorators
            │   ├── interceptors/ # Response transformation
            │   └── middleware/   # Request middleware
            └── package.json
```

## 🚀 Features Implemented

### Service A (Core Business Logic)

- **Health Checks**: `/api/v1/health`, `/api/v1/health/ready`, `/api/v1/health/live`
- **Structured Logging**: Winston with Google Cloud Logging format
- **OpenTelemetry**: Auto-instrumentation for tracing and metrics
- **Graceful Shutdown**: Proper SIGTERM/SIGINT handling
- **Environment Configuration**: Joi validation for config
- **Security**: Helmet, compression, CORS, input validation
- **API Documentation**: Swagger/OpenAPI integration

### Service B (Data Processing)

- **All Service A features plus:**
- **Processing Endpoints**: Batch data processing with different types
- **Job Management**: Track processing jobs with status and progress
- **Processing Types**: Transform, validate, aggregate, filter operations
- **Statistics**: Processing metrics and performance tracking
- **Error Handling**: Comprehensive error handling and logging

### Shared Libraries

- **Common Types**: Standardized interfaces and enums
- **Utilities**: Helper functions for correlation IDs, API responses, retry logic
- **Constants**: HTTP status codes, headers, cache keys
- **Decorators**: Custom NestJS decorators for common functionality
- **Interceptors**: Response transformation and standardization
- **Middleware**: Correlation ID injection

## 🐳 Containerization

Both services use multi-stage Dockerfiles with:

- **Base Image**: `node:20-alpine` for building
- **Production Image**: `gcr.io/distroless/nodejs20-debian12:nonroot`
- **Security**: Non-root user, read-only filesystem, minimal attack surface
- **Health Checks**: Built-in container health checking
- **Optimized Layers**: Efficient layer caching and size optimization

## ☸️ Kubernetes Manifests

### Base Resources

- **Deployment**: Multi-replica with rolling updates
- **Service**: ClusterIP with Network Endpoint Group annotations
- **ConfigMap**: Environment-specific configuration
- **HPA**: Horizontal Pod Autoscaler with CPU/memory metrics
- **PDB**: Pod Disruption Budget for availability
- **ServiceMonitor**: Prometheus metrics collection

### Environment Overlays

- **Dev**: Single replica, debug logging, relaxed resources
- **Staging**: Production-like with monitoring
- **Production**: Multi-replica, optimized resources, strict policies

## 🔧 Development Setup

### Prerequisites

```bash
# Install pnpm globally
npm install -g pnpm@latest

# Install dependencies
pnpm install
```

### Service A

```bash
cd apps/service-a
pnpm run start:dev    # Development mode
pnpm run build        # Production build
pnpm run test         # Run tests
```

### Service B

```bash
cd apps/service-b
pnpm run start:dev    # Development mode (port 3001)
pnpm run build        # Production build
pnpm run test         # Run tests
```

### Shared Libraries

```bash
cd apps/shared/libs/common
pnpm run build        # Build shared library
```

## 🔍 API Endpoints

### Service A (Port 3000)

- `GET /` - Service information
- `GET /api/v1/health` - Comprehensive health check
- `GET /api/v1/health/ready` - Readiness probe
- `GET /api/v1/health/live` - Liveness probe
- `GET /api/docs` - Swagger documentation

### Service B (Port 3001)

- `GET /` - Service information
- `GET /api/v1/health/*` - Health endpoints
- `POST /api/v1/processing/batch` - Process data batch
- `GET /api/v1/processing/jobs` - List processing jobs
- `GET /api/v1/processing/jobs/:id` - Get job details
- `GET /api/v1/processing/stats` - Processing statistics
- `GET /api/docs` - API documentation

## 🏃‍♂️ Next Steps

After completing Phase 3, proceed to:

1. **Phase 4**: Implement CI/CD pipelines with GitHub Actions
2. **Phase 5**: Set up load balancing and ingress
3. **Phase 6**: Deploy observability stack

## 📋 Environment Variables

### Common Variables

```env
NODE_ENV=development|staging|production
PORT=3000|3001
LOG_LEVEL=debug|info|warn|error
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_REGION=asia-southeast1
OTEL_SERVICE_NAME=service-a|service-b
```

### Service-Specific

```env
# Service B only
BATCH_SIZE=100
MAX_PROCESSING_TIME=30000
```

This implementation provides a solid foundation for modern, cloud-native NestJS applications running on GKE with comprehensive observability, security, and operational best practices.
