# NestJS Monorepo Setup Guide

## Quick Start Commands

```bash
# Initialize monorepo
npx create-nx-workspace@latest gke-app --preset=nest --packageManager=pnpm --nxCloud=skip
cd gke-app

# Add second service
nx g @nx/nest:app service-b

# Install additional dependencies
pnpm add @nestjs/terminus @nestjs/config winston winston-transport
pnpm add -D @types/node
```

## Service Structure

### Service A - Order Service

```typescript
// apps/service-a/src/app/app.controller.ts
import { Controller, Get, Logger, Req } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Request } from 'express';

@ApiTags('orders')
@Controller()
export class AppController {
  private readonly logger = new Logger(AppController.name);

  @Get('/')
  @ApiOperation({ summary: 'Get service info' })
  getInfo(@Req() request: Request) {
    this.logger.log(`Request received from ${request.ip} to ${request.url}`);
    return {
      service: 'service-a',
      type: 'order-service',
      version: process.env.VERSION || '1.0.0',
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      pod: process.env.HOSTNAME || 'local'
    };
  }

  @Get('/orders')
  @ApiOperation({ summary: 'Get orders' })
  getOrders(@Req() request: Request) {
    this.logger.log(`Fetching orders - Request from ${request.ip}`);
    return {
      orders: [
        { id: 1, customer: 'Customer A', total: 100 },
        { id: 2, customer: 'Customer B', total: 200 }
      ],
      timestamp: new Date().toISOString()
    };
  }
}
```

### Service B - Customer Service

```typescript
// apps/service-b/src/app/app.controller.ts
import { Controller, Get, Logger, Req } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Request } from 'express';

@ApiTags('customers')
@Controller()
export class AppController {
  private readonly logger = new Logger(AppController.name);

  @Get('/')
  @ApiOperation({ summary: 'Get service info' })
  getInfo(@Req() request: Request) {
    this.logger.log(`Request received from ${request.ip} to ${request.url}`);
    return {
      service: 'service-b',
      type: 'customer-service',
      version: process.env.VERSION || '1.0.0',
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      pod: process.env.HOSTNAME || 'local'
    };
  }

  @Get('/customers')
  @ApiOperation({ summary: 'Get customers' })
  getCustomers(@Req() request: Request) {
    this.logger.log(`Fetching customers - Request from ${request.ip}`);
    return {
      customers: [
        { id: 1, name: 'Customer A', tier: 'gold' },
        { id: 2, name: 'Customer B', tier: 'silver' }
      ],
      timestamp: new Date().toISOString()
    };
  }
}
```

### Health Check Module (Shared)

```typescript
// libs/health/src/health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import {
  HealthCheckService,
  HttpHealthIndicator,
  HealthCheck,
  MemoryHealthIndicator
} from '@nestjs/terminus';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private http: HttpHealthIndicator,
    private memory: MemoryHealthIndicator
  ) {}

  @Get()
  @HealthCheck()
  @ApiOperation({ summary: 'Health check endpoint' })
  check() {
    return this.health.check([
      () => this.memory.checkHeap('memory_heap', 150 * 1024 * 1024),
      () => this.memory.checkRSS('memory_rss', 150 * 1024 * 1024)
    ]);
  }

  @Get('/ready')
  @ApiOperation({ summary: 'Readiness probe' })
  ready() {
    return { status: 'ready', timestamp: new Date().toISOString() };
  }

  @Get('/live')
  @ApiOperation({ summary: 'Liveness probe' })
  live() {
    return { status: 'alive', timestamp: new Date().toISOString() };
  }
}
```

### Cloud Logging Configuration

```typescript
// libs/logging/src/cloud-logger.ts
import { LoggerService } from '@nestjs/common';
import * as winston from 'winston';

export class CloudLogger implements LoggerService {
  private logger: winston.Logger;

  constructor(service: string) {
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: {
        service,
        environment: process.env.NODE_ENV || 'development',
        version: process.env.VERSION || '1.0.0',
        pod: process.env.HOSTNAME || 'local'
      },
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(winston.format.colorize(), winston.format.simple())
        })
      ]
    });
  }

  log(message: string, context?: string) {
    this.logger.info(message, { context });
  }

  error(message: string, trace?: string, context?: string) {
    this.logger.error(message, { trace, context });
  }

  warn(message: string, context?: string) {
    this.logger.warn(message, { context });
  }

  debug(message: string, context?: string) {
    this.logger.debug(message, { context });
  }

  verbose(message: string, context?: string) {
    this.logger.verbose(message, { context });
  }
}
```

## Dockerfiles

### Multi-stage Dockerfile

```dockerfile
# Dockerfile for each service
FROM node:20-alpine AS base
RUN apk add --no-cache libc6-compat
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# Dependencies stage
FROM base AS deps
COPY package.json pnpm-lock.yaml ./
COPY apps/service-a/package.json ./apps/service-a/
RUN pnpm install --frozen-lockfile

# Builder stage
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm nx build service-a --prod

# Production stage
FROM node:20-alpine AS runner
RUN apk add --no-cache dumb-init
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/dist/apps/service-a ./
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

USER nodejs
EXPOSE 3000

ENV NODE_ENV=production
ENV PORT=3000

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "main.js"]
```

## Kubernetes Manifests

### Base Deployment

```yaml
# k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-a
  labels:
    app: service-a
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: service-a
  template:
    metadata:
      labels:
        app: service-a
        version: v1
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '3000'
        prometheus.io/path: '/metrics'
    spec:
      serviceAccountName: service-a
      containers:
        - name: service-a
          image: asia-southeast1-docker.pkg.dev/PROJECT_ID/apps/service-a:latest
          ports:
            - containerPort: 3000
              name: http
              protocol: TCP
          env:
            - name: NODE_ENV
              value: 'production'
            - name: PORT
              value: '3000'
            - name: VERSION
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['version']
            - name: HOSTNAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
          resources:
            requests:
              memory: '128Mi'
              cpu: '100m'
            limits:
              memory: '256Mi'
              cpu: '200m'
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          lifecycle:
            preStop:
              exec:
                command: ['/bin/sh', '-c', 'sleep 15']
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - service-a
                topologyKey: kubernetes.io/hostname
```

### Service with NEG

```yaml
# k8s/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: service-a
  labels:
    app: service-a
  annotations:
    cloud.google.com/neg: '{"ingress": true}'
    cloud.google.com/backend-config: '{"default": "service-a-backend-config"}'
spec:
  type: ClusterIP
  selector:
    app: service-a
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP
      name: http
```

### Backend Configuration

```yaml
# k8s/base/backend-config.yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: service-a-backend-config
spec:
  healthCheck:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 3
    type: HTTP
    requestPath: /health/ready
    port: 3000
  connectionDraining:
    drainingTimeoutSec: 30
  timeoutSec: 30
  logging:
    enable: true
    sampleRate: 1.0
```

### Ingress with Google Load Balancer

```yaml
# k8s/base/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
  annotations:
    kubernetes.io/ingress.class: 'gce'
    kubernetes.io/ingress.global-static-ip-name: 'main-ip'
    networking.gke.io/managed-certificates: 'main-cert'
    cloud.google.com/backend-config: '{"default": "default-backend-config"}'
spec:
  rules:
    - host: api.yourdomain.com
      http:
        paths:
          - path: /orders/*
            pathType: ImplementationSpecific
            backend:
              service:
                name: service-a
                port:
                  number: 80
          - path: /customers/*
            pathType: ImplementationSpecific
            backend:
              service:
                name: service-b
                port:
                  number: 80
  defaultBackend:
    service:
      name: default-backend
      port:
        number: 80
```

## GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yaml
name: Build and Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: asia-southeast1
  REGISTRY: asia-southeast1-docker.pkg.dev

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [service-a, service-b]

    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v3
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run tests
        run: pnpm nx test ${{ matrix.service }}

      - name: Build application
        run: pnpm nx build ${{ matrix.service }} --prod

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: gcloud auth configure-docker ${{ env.REGISTRY }}

      - name: Build and Push Docker image
        run: |
          IMAGE_TAG=${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/apps/${{ matrix.service }}:${{ github.sha }}
          docker build -t $IMAGE_TAG -f apps/${{ matrix.service }}/Dockerfile .
          docker push $IMAGE_TAG

          # Also tag as latest for main branch
          if [ "${{ github.ref }}" = "refs/heads/main" ]; then
            docker tag $IMAGE_TAG ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/apps/${{ matrix.service }}:latest
            docker push ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/apps/${{ matrix.service }}:latest
          fi

      - name: Update Kubernetes manifest
        if: github.ref == 'refs/heads/main'
        run: |
          sed -i "s|IMAGE_TAG|${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/apps/${{ matrix.service }}:${{ github.sha }}|g" k8s/overlays/production/kustomization.yaml

      - name: Commit and push manifest changes
        if: github.ref == 'refs/heads/main'
        run: |
          git config --global user.name 'GitHub Actions'
          git config --global user.email 'actions@github.com'
          git add k8s/overlays/production/
          git commit -m "Update ${{ matrix.service }} image to ${{ github.sha }}"
          git push
```

## ArgoCD Application

```yaml
# argocd/applications/service-a.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: service-a
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gke-app
    targetRevision: HEAD
    path: k8s/overlays/production/service-a
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## pnpm Workspace Configuration

```yaml
# pnpm-workspace.yaml
packages:
  - 'apps/*'
  - 'libs/*'
  - 'tools/*'
```

## package.json Scripts

```json
{
  "name": "gke-app",
  "version": "1.0.0",
  "scripts": {
    "dev:service-a": "nx serve service-a",
    "dev:service-b": "nx serve service-b",
    "build:all": "nx run-many --target=build --all --prod",
    "test:all": "nx run-many --target=test --all",
    "lint:all": "nx run-many --target=lint --all",
    "docker:build:service-a": "docker build -t service-a:local -f apps/service-a/Dockerfile .",
    "docker:build:service-b": "docker build -t service-b:local -f apps/service-b/Dockerfile .",
    "docker:run:service-a": "docker run -p 3001:3000 service-a:local",
    "docker:run:service-b": "docker run -p 3002:3000 service-b:local"
  }
}
```

## Testing the Services Locally

```bash
# Start services locally
pnpm dev:service-a  # Runs on port 3000
pnpm dev:service-b  # Runs on port 3001

# Test endpoints
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/orders

curl http://localhost:3001/
curl http://localhost:3001/health
curl http://localhost:3001/customers

# Build and test Docker images
pnpm docker:build:service-a
pnpm docker:build:service-b
docker-compose up
```

## docker-compose.yaml for Local Testing

```yaml
version: '3.8'
services:
  service-a:
    build:
      context: .
      dockerfile: apps/service-a/Dockerfile
    ports:
      - '3001:3000'
    environment:
      - NODE_ENV=development
      - PORT=3000
    networks:
      - app-network

  service-b:
    build:
      context: .
      dockerfile: apps/service-b/Dockerfile
    ports:
      - '3002:3000'
    environment:
      - NODE_ENV=development
      - PORT=3000
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

This setup provides a complete monorepo structure with two NestJS services that include health checks, structured logging for Google Cloud Logging, and are ready for deployment to GKE with proper CI/CD pipelines.
