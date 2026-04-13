# Domain and Ingress Troubleshooting Runbook

## Scenario: Subdomain Not Resolving

1. **Check Route53 records:**
   ```bash
   aws route53 list-resource-record-sets \
     --hosted-zone-id <ZONE_ID> \
     --query "ResourceRecordSets[?contains(Name, 'jenkins') || contains(Name, 'sonar')]"
   ```

2. **Check ExternalDNS logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=50
   ```

3. **Check Ingress resources:**
   ```bash
   kubectl get ingress -A
   kubectl describe ingress -n jenkins
   kubectl describe ingress -n sonarqube
   ```

4. **Verify ExternalDNS has permissions** (IRSA role should allow Route53 changes).

## Scenario: ALB Not Created

1. **Check AWS Load Balancer Controller logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
   ```

2. **Common issues:**
   - Missing subnet tags: `kubernetes.io/role/elb: 1` on public subnets
   - Missing cluster tag: `kubernetes.io/cluster/<name>: shared`
   - IRSA role not properly configured
   - Ingress annotations incorrect

3. **Verify ALB exists:**
   ```bash
   aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `platform`)]'
   ```

## Scenario: TLS Certificate Issues

1. **Check ACM certificate status:**
   ```bash
   aws acm describe-certificate --certificate-arn <CERT_ARN> \
     --query 'Certificate.{Status:Status,DomainValidationOptions:DomainValidationOptions}'
   ```

2. **If status is PENDING_VALIDATION:**
   - Ensure DNS validation records exist in Route53
   - Run `terraform apply` to recreate validation records

3. **If HTTPS returns wrong cert:**
   - Verify `alb.ingress.kubernetes.io/certificate-arn` annotation matches ACM cert ARN
   - Redeploy Ingress resource

## Scenario: Host-Based Routing Not Working

1. **Verify Ingress rules:**
   ```bash
   kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.rules[*].host}{"\n"}{end}'
   ```

2. **Check ALB listener rules:**
   ```bash
   LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> --query 'Listeners[?Port==`443`].ListenerArn' --output text)
   aws elbv2 describe-rules --listener-arn "$LISTENER_ARN"
   ```

3. **Test directly with Host header:**
   ```bash
   curl -sk -H "Host: jenkins.manoj-tech-solutions.site" https://<ALB_DNS>/login
   ```
