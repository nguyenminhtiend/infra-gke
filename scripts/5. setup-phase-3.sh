#!/bin/bash

set -e

# Phase 3: Basic Application Setup
# This script sets up NestJS v10+ applications with SWC in a pnpm monorepo for both services

echo "🚀 Starting Phase 3: Basic Application Setup"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check prerequisites
title "Checking Prerequisites"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    error "Node.js is not installed. Please install Node.js 22.x or later."
    exit 1
fi

NODE_VERSION=$(node --version)
log "Node.js version: $NODE_VERSION"

# Check Node.js version (should be 22 or higher)
NODE_MAJOR_VERSION=$(node --version | cut -d'.' -f1 | sed 's/v//')
if [ "$NODE_MAJOR_VERSION" -lt 22 ]; then
    error "Node.js version 22.x or higher is required. Current version: $NODE_VERSION"
    exit 1
fi

# Check if pnpm is installed
if ! command -v pnpm &> /dev/null; then
    error "pnpm is not installed. Please install pnpm: npm install -g pnpm"
    exit 1
fi

PNPM_VERSION=$(pnpm --version)
log "pnpm version: $PNPM_VERSION"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker."
    exit 1
fi

DOCKER_VERSION=$(docker --version)
log "Docker version: $DOCKER_VERSION"

# Check if we're in the right directory
if [ ! -f "gke-deployment-plan.md" ]; then
    error "Please run this script from the project root directory."
    exit 1
fi

log "✅ All prerequisites met"

# Install root dependencies first
title "Installing Root Dependencies"

log "Installing pnpm workspace dependencies..."
pnpm install

log "✅ Root dependencies installed"

# Setup Service A (User Management)
title "Setting up Service A - User Management"

cd apps/service-a

log "Creating .env file from example..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    log "Created .env file from .env.example"
else
    warn ".env file already exists, skipping..."
fi

log "Building Service A..."
pnpm run build

log "Running linting and formatting..."
pnpm run lint
pnpm run format

log "Running tests..."
pnpm test

log "✅ Service A setup complete"

cd ../..

# Setup Service B (Product Catalog)
title "Setting up Service B - Product Catalog"

cd apps/service-b

log "Creating .env file from example..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    log "Created .env file from .env.example"
else
    warn ".env file already exists, skipping..."
fi

log "Building Service B..."
pnpm run build

log "Running linting and formatting..."
pnpm run lint
pnpm run format

log "Running tests..."
pnpm test

log "✅ Service B setup complete"

cd ../..

# Build Docker images
title "Building Docker Images"

log "Building Service A Docker image..."
cd apps/service-a
docker build -t service-a:latest .
log "✅ Service A Docker image built"

cd ../service-b
log "Building Service B Docker image..."
docker build -t service-b:latest .
log "✅ Service B Docker image built"

cd ../..

# Create logs directories
title "Creating Log Directories"

mkdir -p apps/service-a/logs
mkdir -p apps/service-b/logs
log "✅ Log directories created"

# Display service information
title "Service Information"

echo ""
echo "📋 Services Created:"
echo "  • Service A (User Management):"
echo "    - Port: 3000"
echo "    - API: http://localhost:3000/api/v1"
echo "    - Docs: http://localhost:3000/api/docs"
echo "    - Health: http://localhost:3000/api/v1/health"
echo ""
echo "  • Service B (Product Catalog):"
echo "    - Port: 3001"
echo "    - API: http://localhost:3001/api/v1"
echo "    - Docs: http://localhost:3001/api/docs"
echo "    - Health: http://localhost:3001/api/v1/health"
echo ""

# Display next steps
title "Next Steps"

echo "To start the services locally:"
echo ""
echo "Service A:"
echo "  cd apps/service-a"
echo "  pnpm run start:dev"
echo ""
echo "Service B:"
echo "  cd apps/service-b"
echo "  pnpm run start:dev"
echo ""
echo "Or start both services from root:"
echo "  pnpm run dev"
echo ""
echo "To run validation:"
echo "  ./scripts/6.\\ validate-phase-3.sh"
echo ""
echo "To proceed to Phase 4 (Basic Deployment & Connectivity):"
echo "  Ensure Phase 2 (Basic Infrastructure) is completed first"
echo "  Then run the Phase 4 setup script when available"
echo ""

log "🎉 Phase 3 setup completed successfully!"
log "Run the validation script to verify everything is working correctly."
