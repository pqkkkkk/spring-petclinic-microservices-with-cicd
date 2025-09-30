#!/bin/bash

# Test deployment script to verify service communication
# This script deploys services in the correct order and tests connectivity

echo "=== Testing Petclinic Microservices Deployment ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if pod is ready
check_pod_ready() {
    local service=$1
    local timeout=300
    local counter=0
    
    echo -e "${YELLOW}Waiting for ${service} to be ready...${NC}"
    
    while [ $counter -lt $timeout ]; do
        if kubectl get pods -l app.kubernetes.io/name=${service} -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
            if kubectl get pods -l app.kubernetes.io/name=${service} -o jsonpath='{.items[0].status.containerStatuses[0].ready}' | grep -q "true"; then
                echo -e "${GREEN}✅ ${service} is ready!${NC}"
                return 0
            fi
        fi
        sleep 5
        counter=$((counter + 5))
        echo -n "."
    done
    
    echo -e "${RED}❌ ${service} failed to start within ${timeout} seconds${NC}"
    return 1
}

# Function to test service endpoint
test_service() {
    local service=$1
    local port=$2
    local path=$3
    
    echo -e "${YELLOW}Testing ${service} endpoint...${NC}"
    
    # Port forward in background
    kubectl port-forward service/${service} ${port}:${port} &
    local pf_pid=$!
    sleep 5
    
    # Test endpoint
    if curl -s -f http://localhost:${port}${path} > /dev/null; then
        echo -e "${GREEN}✅ ${service} endpoint is responding${NC}"
        kill $pf_pid 2>/dev/null
        return 0
    else
        echo -e "${RED}❌ ${service} endpoint is not responding${NC}"
        kill $pf_pid 2>/dev/null
        return 1
    fi
}

# Deploy and test core services
echo -e "${YELLOW}=== Deploying Core Services ===${NC}"

# Config Server
helm upgrade --install config-server ./petclinic-cd/k8s/helm \
    -f ./petclinic-cd/k8s/helm/values-config-server.yaml \
    --set image.tag=latest \
    --namespace default \
    --create-namespace \
    --wait --timeout=300s

check_pod_ready "config-server"

# Discovery Server
helm upgrade --install discovery-server ./petclinic-cd/k8s/helm \
    -f ./petclinic-cd/k8s/helm/values-discovery-server.yaml \
    --set image.tag=latest \
    --namespace default \
    --create-namespace \
    --wait --timeout=300s

check_pod_ready "discovery-server"

echo -e "${YELLOW}=== Deploying Business Services ===${NC}"

# Deploy business services in parallel
services=("customers-service" "vets-service" "visits-service" "genai-service")

for service in "${services[@]}"; do
    {
        helm upgrade --install ${service} ./petclinic-cd/k8s/helm \
            -f ./petclinic-cd/k8s/helm/values-${service}.yaml \
            --set image.tag=latest \
            --namespace default \
            --create-namespace \
            --wait --timeout=300s
        
        check_pod_ready "${service}"
    } &
done

# Wait for all background jobs to complete
wait

echo -e "${YELLOW}=== Deploying Gateway Services ===${NC}"

# API Gateway
helm upgrade --install api-gateway ./petclinic-cd/k8s/helm \
    -f ./petclinic-cd/k8s/helm/values-api-gateway.yaml \
    --set image.tag=latest \
    --namespace default \
    --create-namespace \
    --wait --timeout=300s

check_pod_ready "api-gateway"

# Admin Server
helm upgrade --install admin-server ./petclinic-cd/k8s/helm \
    -f ./petclinic-cd/k8s/helm/values-admin-server.yaml \
    --set image.tag=latest \
    --namespace default \
    --create-namespace \
    --wait --timeout=300s

check_pod_ready "admin-server"

echo -e "${YELLOW}=== Testing Service Connectivity ===${NC}"

# Test service endpoints
test_service "discovery-server" 8761 "/actuator/health"
test_service "config-server" 8888 "/actuator/health"
test_service "api-gateway" 8080 "/actuator/health"

# Check service registration in Eureka
echo -e "${YELLOW}Checking service registration in Eureka...${NC}"
kubectl port-forward service/discovery-server 8761:8761 &
local eureka_pf_pid=$!
sleep 5

if curl -s http://localhost:8761/eureka/apps | grep -q "customers-service\|vets-service\|visits-service"; then
    echo -e "${GREEN}✅ Services are registered with Eureka${NC}"
else
    echo -e "${RED}❌ Services are not properly registered with Eureka${NC}"
fi

kill $eureka_pf_pid 2>/dev/null

echo -e "${GREEN}=== Deployment Test Complete ===${NC}"

# Display service information
echo -e "${YELLOW}=== Service Information ===${NC}"
kubectl get pods,services -l "app.kubernetes.io/name in (config-server,discovery-server,customers-service,vets-service,visits-service,genai-service,api-gateway,admin-server)"

echo -e "${YELLOW}=== Access URLs ===${NC}"
echo "API Gateway: kubectl port-forward service/api-gateway 8080:8080"
echo "Eureka Dashboard: kubectl port-forward service/discovery-server 8761:8761"
echo "Admin Server: kubectl port-forward service/admin-server 9090:9090"
