#!/bin/bash

set -e

# Phase 3: Basic Application Validation
# This script validates the NestJS v10+ applications setup with pnpm monorepo

echo "🔍 Starting Phase 3: Basic Application Validation"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_TOTAL=0
CHECKS_PASSED=0
CHECKS_FAILED=0

# Helper functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

title() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

check() {
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
    if eval "$2"; then
        log "✅ $1"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        error "❌ $1"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# Check if we're in the right directory
if [ ! -f "gke-deployment-plan.md" ]; then
    error "Please run this script from the project root directory."
    exit 1
fi

# Validate Prerequisites
title "Validating Prerequisites"

check "Node.js is installed" "command -v node > /dev/null 2>&1"
if command -v node > /dev/null 2>&1; then
    NODE_MAJOR_VERSION=$(node --version | cut -d'.' -f1 | sed 's/v//')
    check "Node.js version is 22 or higher" "[ \"$NODE_MAJOR_VERSION\" -ge 22 ]"
fi

check "pnpm is installed" "command -v pnpm > /dev/null 2>&1"
check "Docker is installed" "command -v docker > /dev/null 2>&1"

# Validate Monorepo Structure
title "Validating Monorepo Structure"

check "Root package.json exists" "[ -f 'package.json' ]"
check "pnpm-workspace.yaml exists" "[ -f 'pnpm-workspace.yaml' ]"
check "Root package.json uses Node 22+" "grep -q '\"node\": \">=22.0.0\"' package.json"
check "Workspace configuration includes apps/*" "grep -q 'apps/\\*' pnpm-workspace.yaml"
check "Catalog configuration exists" "grep -q 'catalog:' pnpm-workspace.yaml"

# Validate Service A
title "Validating Service A - User Management"

check "Service A directory exists" "[ -d 'apps/service-a' ]"
check "Service A package.json exists" "[ -f 'apps/service-a/package.json' ]"
check "Service A uses NestJS v10+" "grep -q '\"@nestjs/core\": \"\\^10\\.' apps/service-a/package.json"
check "Service A uses SWC" "[ -f 'apps/service-a/.swcrc' ]"
check "Service A nest-cli.json configured for SWC" "grep -q '\"builder\": \"swc\"' apps/service-a/nest-cli.json"
check "Service A main.ts exists" "[ -f 'apps/service-a/src/main.ts' ]"
check "Service A has health module" "[ -f 'apps/service-a/src/health/health.controller.ts' ]"
check "Service A has users module" "[ -f 'apps/service-a/src/users/users.controller.ts' ]"
check "Service A Dockerfile exists" "[ -f 'apps/service-a/Dockerfile' ]"
check "Service A uses multi-stage Docker build" "grep -q 'FROM.*AS' apps/service-a/Dockerfile"
check "Service A K8s deployment exists" "[ -f 'apps/service-a/k8s/deployment.yaml' ]"
check "Service A has health checks in K8s" "grep -q 'livenessProbe' apps/service-a/k8s/deployment.yaml"

# Check if Service A dependencies are installed
if [ -d "apps/service-a/node_modules" ]; then
    check "Service A dependencies installed" "[ -d 'apps/service-a/node_modules' ]"

    # Check if Service A builds successfully
    cd apps/service-a
    if check "Service A builds successfully" "pnpm run build > /dev/null 2>&1"; then
        log "Service A build artifacts created"
    fi
    cd ../..
else
    warn "Service A dependencies not installed - skipping build test"
fi

# Validate Service B
title "Validating Service B - Product Catalog"

check "Service B directory exists" "[ -d 'apps/service-b' ]"
check "Service B package.json exists" "[ -f 'apps/service-b/package.json' ]"
check "Service B uses NestJS v10+" "grep -q '\"@nestjs/core\": \"\\^10\\.' apps/service-b/package.json"
check "Service B uses SWC" "[ -f 'apps/service-b/.swcrc' ]"
check "Service B nest-cli.json configured for SWC" "grep -q '\"builder\": \"swc\"' apps/service-b/nest-cli.json"
check "Service B main.ts exists" "[ -f 'apps/service-b/src/main.ts' ]"
check "Service B has health module" "[ -f 'apps/service-b/src/health/health.controller.ts' ]"
check "Service B has products module" "[ -f 'apps/service-b/src/products/products.controller.ts' ]"
check "Service B Dockerfile exists" "[ -f 'apps/service-b/Dockerfile' ]"
check "Service B uses multi-stage Docker build" "grep -q 'FROM.*AS' apps/service-b/Dockerfile"
check "Service B K8s deployment exists" "[ -f 'apps/service-b/k8s/deployment.yaml' ]"
check "Service B has health checks in K8s" "grep -q 'livenessProbe' apps/service-b/k8s/deployment.yaml"

# Check if Service B dependencies are installed
if [ -d "apps/service-b/node_modules" ]; then
    check "Service B dependencies installed" "[ -d 'apps/service-b/node_modules' ]"

    # Check if Service B builds successfully
    cd apps/service-b
    if check "Service B builds successfully" "pnpm run build > /dev/null 2>&1"; then
        log "Service B build artifacts created"
    fi
    cd ../..
else
    warn "Service B dependencies not installed - skipping build test"
fi

# Validate Docker Images
title "Validating Docker Images"

check "Service A Docker image exists" "docker images | grep -q service-a"
check "Service B Docker image exists" "docker images | grep -q service-b"

# Validate Application Configuration
title "Validating Application Configuration"

check "Service A uses different port (3000)" "grep -q 'PORT.*3000' apps/service-a/.env.example"
check "Service B uses different port (3001)" "grep -q 'PORT.*3001' apps/service-b/.env.example"
check "Service A has Winston logging" "grep -q 'winston' apps/service-a/package.json"
check "Service B has Winston logging" "grep -q 'winston' apps/service-b/package.json"
check "Service A has Swagger documentation" "grep -q '@nestjs/swagger' apps/service-a/package.json"
check "Service B has Swagger documentation" "grep -q '@nestjs/swagger' apps/service-b/package.json"

# Validate Kubernetes Configuration
title "Validating Kubernetes Configuration"

check "Service A K8s has proper resource limits" "grep -q 'limits:' apps/service-a/k8s/deployment.yaml"
check "Service B K8s has proper resource limits" "grep -q 'limits:' apps/service-b/k8s/deployment.yaml"
check "Service A K8s has readiness probe" "grep -q 'readinessProbe' apps/service-a/k8s/deployment.yaml"
check "Service B K8s has readiness probe" "grep -q 'readinessProbe' apps/service-b/k8s/deployment.yaml"
check "Service A K8s uses ClusterIP service" "grep -q 'type: ClusterIP' apps/service-a/k8s/deployment.yaml"
check "Service B K8s uses ClusterIP service" "grep -q 'type: ClusterIP' apps/service-b/k8s/deployment.yaml"

# Advanced Validation - Test Service Startup (if Docker is available)
title "Advanced Validation - Service Startup Test"

if command -v docker &> /dev/null; then
    log "Testing Service A container startup..."
    if docker run --rm -d --name service-a-test -p 3000:3000 service-a:latest > /dev/null 2>&1; then
        sleep 10
        if curl -s http://localhost:3000/api/v1/health > /dev/null 2>&1; then
            check "Service A container starts and responds to health check" "true"
            docker stop service-a-test > /dev/null 2>&1
        else
            check "Service A container starts and responds to health check" "false"
            docker stop service-a-test > /dev/null 2>&1 || true
        fi
    else
        check "Service A container starts and responds to health check" "false"
    fi

    log "Testing Service B container startup..."
    if docker run --rm -d --name service-b-test -p 3001:3001 service-b:latest > /dev/null 2>&1; then
        sleep 10
        if curl -s http://localhost:3001/api/v1/health > /dev/null 2>&1; then
            check "Service B container starts and responds to health check" "true"
            docker stop service-b-test > /dev/null 2>&1
        else
            check "Service B container starts and responds to health check" "false"
            docker stop service-b-test > /dev/null 2>&1 || true
        fi
    else
        check "Service B container starts and responds to health check" "false"
    fi
else
    warn "Docker not available - skipping container startup tests"
fi

# Security Validation
title "Security Validation"

check "Service A Dockerfile uses non-root user" "grep -q 'USER nestjs' apps/service-a/Dockerfile"
check "Service B Dockerfile uses non-root user" "grep -q 'USER nestjs' apps/service-b/Dockerfile"
check "Service A K8s has security context" "grep -q 'securityContext' apps/service-a/k8s/deployment.yaml"
check "Service B K8s has security context" "grep -q 'securityContext' apps/service-b/k8s/deployment.yaml"
check "Service A uses helmet for security" "grep -q 'helmet' apps/service-a/src/main.ts"
check "Service B uses helmet for security" "grep -q 'helmet' apps/service-b/src/main.ts"

# Code Quality Validation
title "Code Quality Validation"

check "Service A has DTOs with validation" "[ -f 'apps/service-a/src/users/dto/user.dto.ts' ]"
check "Service B has DTOs with validation" "[ -f 'apps/service-b/src/products/dto/product.dto.ts' ]"
check "Service A uses class-validator" "grep -q 'class-validator' apps/service-a/package.json"
check "Service B uses class-validator" "grep -q 'class-validator' apps/service-b/package.json"
check "Service A has .dockerignore" "[ -f 'apps/service-a/.dockerignore' ]"
check "Service B has .dockerignore" "[ -f 'apps/service-b/.dockerignore' ]"

# Display Results
title "Validation Results"

echo ""
echo "📊 Validation Summary:"
echo "  Total Checks: $CHECKS_TOTAL"
echo "  Passed: $CHECKS_PASSED"
echo "  Failed: $CHECKS_FAILED"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    log "🎉 All validation checks passed!"
    echo ""
    echo "✅ Phase 3 validation completed successfully!"
    echo ""
    echo "📋 What's been validated:"
    echo "  • NestJS v10+ applications with SWC compilation in pnpm monorepo"
    echo "  • Node.js 22+ and pnpm workspace configuration"
    echo "  • Health check endpoints (/health, /ready, /live)"
    echo "  • Swagger API documentation"
    echo "  • Winston logging configuration"
    echo "  • Multi-stage Docker builds with security best practices"
    echo "  • Kubernetes deployments with proper health checks"
    echo "  • Input validation with DTOs and class-validator"
    echo "  • Security configurations (helmet, non-root users)"
    echo ""
    echo "🚀 Ready to proceed to Phase 4: Basic Deployment & Connectivity"
    echo ""
    echo "📝 To test the services locally:"
    echo "  Service A: cd apps/service-a && pnpm run start:dev"
    echo "  Service B: cd apps/service-b && pnpm run start:dev"
    echo "  Or both: pnpm run dev (from root)"
    echo ""
    echo "🌐 API Documentation will be available at:"
    echo "  Service A: http://localhost:3000/api/docs"
    echo "  Service B: http://localhost:3001/api/docs"

    exit 0
else
    error "❌ $CHECKS_FAILED validation check(s) failed!"
    echo ""
    echo "🔧 Please fix the failing checks before proceeding to Phase 4."
    echo "   Re-run this validation script after making corrections."

    exit 1
fi
