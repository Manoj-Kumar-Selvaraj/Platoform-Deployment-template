#!/usr/bin/env bash
set -euo pipefail

# End-to-end validation script for Platform MVP

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ERRORS=0
WARNINGS=0

DOMAIN="${DOMAIN:-manoj-tech-solutions.site}"
CLUSTER_NAME="${CLUSTER_NAME:-platform-mvp-dev}"
REGION="${AWS_REGION:-us-east-1}"

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }

echo "=== Platform MVP Validation ==="
echo "Domain: $DOMAIN"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

# --- Infrastructure ---
echo "--- Infrastructure ---"

if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &>/dev/null; then
    pass "EKS cluster '$CLUSTER_NAME' exists"
else
    fail "EKS cluster '$CLUSTER_NAME' not found"
fi

if kubectl cluster-info &>/dev/null; then
    pass "kubectl connected to cluster"
else
    fail "kubectl cannot connect to cluster"
fi

# --- Namespaces ---
echo ""
echo "--- Kubernetes Namespaces ---"
for NS in jenkins sonarqube apps; do
    if kubectl get namespace "$NS" &>/dev/null; then
        pass "Namespace '$NS' exists"
    else
        fail "Namespace '$NS' missing"
    fi
done

# --- Helm Releases ---
echo ""
echo "--- Helm Releases ---"
for RELEASE in jenkins sonarqube aws-load-balancer-controller external-dns; do
    if helm list -A | grep -q "$RELEASE"; then
        pass "Helm release '$RELEASE' deployed"
    else
        warn "Helm release '$RELEASE' not found"
    fi
done

# --- DNS Resolution ---
echo ""
echo "--- DNS & TLS ---"
for SUBDOMAIN in jenkins sonar; do
    FQDN="${SUBDOMAIN}.${DOMAIN}"
    if host "$FQDN" &>/dev/null 2>&1 || nslookup "$FQDN" &>/dev/null 2>&1; then
        pass "DNS resolves: $FQDN"
    else
        fail "DNS not resolving: $FQDN"
    fi
done

# --- HTTPS Endpoints ---
for SUBDOMAIN in jenkins sonar; do
    FQDN="${SUBDOMAIN}.${DOMAIN}"
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${FQDN}" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
        pass "HTTPS reachable: https://${FQDN} (HTTP $HTTP_CODE)"
    else
        fail "HTTPS unreachable: https://${FQDN} (HTTP $HTTP_CODE)"
    fi
done

# --- Jenkins Specific ---
echo ""
echo "--- Jenkins ---"
JENKINS_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://jenkins.${DOMAIN}/login" 2>/dev/null || echo "000")
if [ "$JENKINS_STATUS" = "200" ]; then
    pass "Jenkins login page accessible"
else
    warn "Jenkins login page returned HTTP $JENKINS_STATUS"
fi

# --- SonarQube Specific ---
echo ""
echo "--- SonarQube ---"
SONAR_STATUS=$(curl -sk "https://sonar.${DOMAIN}/api/system/status" 2>/dev/null | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
if [ "$SONAR_STATUS" = "UP" ]; then
    pass "SonarQube API reports UP"
else
    warn "SonarQube API status: $SONAR_STATUS"
fi

# --- ECR ---
echo ""
echo "--- ECR ---"
ECR_REPOS=$(aws ecr describe-repositories --region "$REGION" --query 'repositories[].repositoryName' --output text 2>/dev/null || echo "")
if [ -n "$ECR_REPOS" ]; then
    pass "ECR repositories: $ECR_REPOS"
else
    warn "No ECR repositories found"
fi

# --- Ansible Runner ---
echo ""
echo "--- Ansible Runner ---"
RUNNER_ID=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=*ansible-runner*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || echo "")
if [ -n "$RUNNER_ID" ]; then
    pass "Ansible runner instance: $RUNNER_ID"
    if aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$RUNNER_ID" \
        --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null | grep -q "Online"; then
        pass "Ansible runner SSM online"
    else
        warn "Ansible runner SSM not responding"
    fi
else
    warn "Ansible runner instance not found"
fi

# --- Summary ---
echo ""
echo "=== Validation Summary ==="
echo -e "Passed checks. Errors: ${RED}${ERRORS}${NC}, Warnings: ${YELLOW}${WARNINGS}${NC}"
[ "$ERRORS" -gt 0 ] && exit 1 || exit 0
