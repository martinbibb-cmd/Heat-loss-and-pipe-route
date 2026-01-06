#!/bin/bash

################################################################################
# Heating Design Application - Build and Deploy Script for Unraid
################################################################################
# This script automates building Docker images and deploying to Unraid
#
# Usage:
#   ./build-and-deploy.sh [OPTIONS]
#
# Options:
#   --build-only    Build images only, don't deploy
#   --deploy-only   Deploy existing images, don't rebuild
#   --unraid-ip     Unraid server IP (default: prompt)
#   --push-registry Push to Docker registry instead of direct transfer
#   --help          Show this help message
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BUILD_ONLY=false
DEPLOY_ONLY=false
UNRAID_IP=""
PUSH_REGISTRY=false
PROJECT_NAME="heating-design"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        --unraid-ip)
            UNRAID_IP="$2"
            shift 2
            ;;
        --push-registry)
            PUSH_REGISTRY=true
            shift
            ;;
        --help)
            head -n 20 "$0" | tail -n 15
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_dependencies() {
    print_header "Checking Dependencies"

    local missing_deps=()

    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    if [ "$DEPLOY_ONLY" = false ]; then
        if ! docker info &> /dev/null; then
            print_error "Docker daemon is not running"
            exit 1
        fi
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi

    print_success "All dependencies satisfied"
}

get_unraid_ip() {
    if [ -z "$UNRAID_IP" ]; then
        print_info "Enter your Unraid server IP address:"
        read -r UNRAID_IP
    fi

    # Validate IP address format
    if ! [[ $UNRAID_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "Invalid IP address format"
        exit 1
    fi

    print_success "Using Unraid IP: $UNRAID_IP"
}

build_images() {
    print_header "Building Docker Images"

    local repo_root=$(git rev-parse --show-toplevel)
    cd "$repo_root"

    # Build API image
    print_info "Building API image..."
    docker build \
        -f deployment/docker/api/Dockerfile \
        -t ${PROJECT_NAME}-api:latest \
        -t ${PROJECT_NAME}-api:$(git rev-parse --short HEAD) \
        . || {
            print_error "Failed to build API image"
            exit 1
        }
    print_success "API image built successfully"

    # Build Web UI image
    print_info "Building Web UI image..."
    docker build \
        -f deployment/docker/web/Dockerfile \
        --build-arg VITE_API_URL=http://${UNRAID_IP}:3001 \
        -t ${PROJECT_NAME}-web:latest \
        -t ${PROJECT_NAME}-web:$(git rev-parse --short HEAD) \
        . || {
            print_error "Failed to build Web UI image"
            exit 1
        }
    print_success "Web UI image built successfully"

    # Show image sizes
    print_info "Image sizes:"
    docker images | grep "${PROJECT_NAME}" | head -2
}

save_images() {
    print_header "Saving Docker Images"

    local output_dir="./deployment/images"
    mkdir -p "$output_dir"

    print_info "Saving API image..."
    docker save ${PROJECT_NAME}-api:latest | gzip > "$output_dir/${PROJECT_NAME}-api.tar.gz"
    print_success "API image saved"

    print_info "Saving Web UI image..."
    docker save ${PROJECT_NAME}-web:latest | gzip > "$output_dir/${PROJECT_NAME}-web.tar.gz"
    print_success "Web UI image saved"

    print_success "Images saved to $output_dir"
}

transfer_to_unraid() {
    print_header "Transferring to Unraid"

    local images_dir="./deployment/images"
    local deployment_dir="/mnt/user/appdata/${PROJECT_NAME}"

    # Check SSH connectivity
    print_info "Testing SSH connection to Unraid..."
    if ! ssh -o ConnectTimeout=5 "root@${UNRAID_IP}" "echo 'Connected'" &> /dev/null; then
        print_error "Cannot connect to Unraid via SSH"
        print_warning "Make sure SSH is enabled in Unraid Settings"
        exit 1
    fi
    print_success "SSH connection successful"

    # Create directory on Unraid
    print_info "Creating deployment directory on Unraid..."
    ssh "root@${UNRAID_IP}" "mkdir -p ${deployment_dir}" || {
        print_error "Failed to create directory on Unraid"
        exit 1
    }

    # Transfer Docker images
    print_info "Transferring Docker images..."
    scp -r "$images_dir"/*.tar.gz "root@${UNRAID_IP}:${deployment_dir}/" || {
        print_error "Failed to transfer images"
        exit 1
    }
    print_success "Images transferred successfully"

    # Transfer deployment files
    print_info "Transferring deployment configuration..."
    scp -r deployment/unraid/* "root@${UNRAID_IP}:${deployment_dir}/" || {
        print_error "Failed to transfer deployment files"
        exit 1
    }
    print_success "Configuration files transferred"
}

load_images_on_unraid() {
    print_header "Loading Images on Unraid"

    local deployment_dir="/mnt/user/appdata/${PROJECT_NAME}"

    print_info "Loading API image..."
    ssh "root@${UNRAID_IP}" \
        "docker load < ${deployment_dir}/${PROJECT_NAME}-api.tar.gz" || {
        print_error "Failed to load API image"
        exit 1
    }
    print_success "API image loaded"

    print_info "Loading Web UI image..."
    ssh "root@${UNRAID_IP}" \
        "docker load < ${deployment_dir}/${PROJECT_NAME}-web.tar.gz" || {
        print_error "Failed to load Web UI image"
        exit 1
    }
    print_success "Web UI image loaded"

    # Clean up tar files to save space
    print_info "Cleaning up tar files..."
    ssh "root@${UNRAID_IP}" \
        "rm ${deployment_dir}/*.tar.gz"
}

deploy_on_unraid() {
    print_header "Deploying on Unraid"

    local deployment_dir="/mnt/user/appdata/${PROJECT_NAME}"

    # Check if .env exists
    print_info "Checking environment configuration..."
    if ! ssh "root@${UNRAID_IP}" "test -f ${deployment_dir}/.env"; then
        print_warning ".env file not found on Unraid"
        print_info "Copying .env.example to .env..."
        ssh "root@${UNRAID_IP}" \
            "cp ${deployment_dir}/.env.example ${deployment_dir}/.env"
        print_warning "Please edit ${deployment_dir}/.env on Unraid before starting services!"
        print_info "SSH command: ssh root@${UNRAID_IP}"
        print_info "Edit: nano ${deployment_dir}/.env"
        return
    fi

    # Deploy with docker compose
    print_info "Starting services with Docker Compose..."
    ssh "root@${UNRAID_IP}" \
        "cd ${deployment_dir} && docker compose up -d" || {
        print_error "Failed to start services"
        exit 1
    }
    print_success "Services started successfully"

    # Show status
    print_info "Container status:"
    ssh "root@${UNRAID_IP}" \
        "docker ps | grep ${PROJECT_NAME}"
}

verify_deployment() {
    print_header "Verifying Deployment"

    sleep 5  # Give containers time to start

    print_info "Checking API health..."
    if curl -s "http://${UNRAID_IP}:3001/health" | grep -q "ok"; then
        print_success "API is responding"
    else
        print_warning "API health check failed (may still be starting)"
    fi

    print_info "Checking Web UI..."
    if curl -s -o /dev/null -w "%{http_code}" "http://${UNRAID_IP}:3000" | grep -q "200"; then
        print_success "Web UI is accessible"
    else
        print_warning "Web UI not yet accessible (may still be starting)"
    fi

    print_info "\nAccess your application:"
    echo -e "  Web UI:  ${GREEN}http://${UNRAID_IP}:3000${NC}"
    echo -e "  API:     ${GREEN}http://${UNRAID_IP}:3001${NC}"
    echo -e "  Health:  ${GREEN}http://${UNRAID_IP}:3001/health${NC}"
}

################################################################################
# Main Script
################################################################################

print_header "Heating Design - Build & Deploy"

check_dependencies

if [ "$DEPLOY_ONLY" = false ]; then
    get_unraid_ip
    build_images
    save_images
fi

if [ "$BUILD_ONLY" = false ]; then
    if [ -z "$UNRAID_IP" ]; then
        get_unraid_ip
    fi
    transfer_to_unraid
    load_images_on_unraid
    deploy_on_unraid
    verify_deployment
fi

print_header "Deployment Complete!"

print_success "Your Heating Design application is now running on Unraid"
print_info "\nNext steps:"
echo "  1. Configure environment: ssh root@${UNRAID_IP} 'nano /mnt/user/appdata/${PROJECT_NAME}/.env'"
echo "  2. Restart services: ssh root@${UNRAID_IP} 'cd /mnt/user/appdata/${PROJECT_NAME} && docker compose restart'"
echo "  3. View logs: ssh root@${UNRAID_IP} 'cd /mnt/user/appdata/${PROJECT_NAME} && docker compose logs -f'"
echo ""
