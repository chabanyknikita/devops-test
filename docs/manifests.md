# Kubernetes Deployment Documentation

This document describes the deployment setup for the **NestJS application** and **Redis** using a **Helm Chart**. It includes configuration for Deployments, Services, Ingress, ConfigMaps, Secrets, Security, Probes, Resource Limits, and supporting Kubernetes components like Kyverno, HPA, and Network Policies.

---

## 1. Overview

The Helm chart provides a modular and configurable deployment for the NestJS application (`test`) and its Redis backend.  
The configuration ensures **security**, **scalability**, and **maintainability** of the system in a Kubernetes environment.

---

## 2. Components

### 2.1. NestJS Application

The main application is deployed via a **Deployment** object with:
- **1 replica** by default (scalable with HPA).
- Security context enforcing non-root user.
- Readiness and liveness probes.
- Environment variables for Redis configuration.
- Resource requests and limits for predictable scheduling.

### 2.2. Redis

Redis is deployed as a cluster with **leader** and **follower** instances.  
The NestJS app connects only to the **follower headless service** to ensure read scalability and connection stability.

### 2.3. Ingress

Ingress is configured to route external traffic to the NestJS service with automatic TLS provisioning through **Let’s Encrypt (cert-manager)**.

---

## 3. Helm Chart Configuration

### 3.1. Example Values (`values.yaml`)

```yaml
ingresses: 
  test.passwdsec.online:
    ingressClassName: nginx
    annotations:
      kubernetes.io/tls-acme: "true"
    certManager:
      issuerType: cluster-issuer
      issuerName: letsencrypt
    hosts:
    - paths:
      - serviceName: test
        servicePort: http

services:
  test:
    clusterIP: None
    ports:
    - name: http
      protocol: TCP
      port: 3000
    extraSelectorLabels:
      app: test

deployments:
  test:
    replicas: 1
    extraSelectorLabels:
      app: test
    podAnnotations:
      checksum/api-key: '{{ include "helpers.workload.checksum" $.Values.secrets.webadmin }}'
    initContainers:
      - name: wait-for-redis
        image: busybox:1.36
        command:
          - sh
          - -c
          - |
            echo "Waiting for Redis at redis:6379..."
            until nc -z redis-cluster-follower-headless 6379; do
              echo "Redis not ready yet, sleeping 2s..."
              sleep 2
            done
            echo "Redis is up!"
    containers:
      - name: test
        env:
          - name: PORT
            value: "3000"
          - name: REDIS_HOST
            value: redis-cluster-follower-headless
          - name: REDIS_PORT
            value: "6379"
          - name: REDIS_DB
            value: "0"
        envsFromSecret:
          db-secret:
          - REDIS_PASSWORD: pass
        ports:
          - name: http
            containerPort: 3000
        securityContext:
          allowPrivilegeEscalation: false
          privileged: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
          seccompProfile:
            type: RuntimeDefault
          runAsNonRoot: true
          runAsUser: 1001
          runAsGroup: 1001
        livenessProbe:
          httpGet:
            path: /redis
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /redis
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: "10m"
            memory: "12Mi"
          limits:
            cpu: "60m"
            memory: "64Mi"

securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  fsGroup: 1001
  seccompProfile:
    type: RuntimeDefault
  supplementalGroups: [1001]

nodeSelector:
  service: "true"
```

## 4. Configuration Components
### 4.1. Secrets

Sensitive information such as Redis credentials are stored as Kubernetes Secrets.
They are mounted as environment variables in the NestJS deployment.

### 4.2. Security Context

All containers:
- Run as non-root (runAsUser: 1001).
- Drop all Linux capabilities.
- Have read-only root filesystems.
- Use the RuntimeDefault seccomp profile.

## 5. Resource Management
| Resource | Requests | Limits |
| -------- | -------- | ------ |
| CPU      | 10m      | 60m    |
| Memory   | 12Mi     | 64Mi   |

## 6. Probes 
| Probe Type    | Endpoint | Delay | Period |
| ------------- | -------- | ----- | ------ |
| **Liveness**  | `/redis` | 10s   | 10s    |
| **Readiness** | `/redis` | 5s    | 5s     |

## 7. Supporting Kubernetes Components
### 7.1. Kyverno Policy

A Kyverno policy is applied to ensure that all deployed container images are signed with the correct cryptographic key before running.
This enforces supply-chain integrity.

### 7.2. Horizontal Pod Autoscaler (HPA)

Automatically scales the NestJS Deployment based on CPU/memory metrics to handle traffic spikes efficiently.

### 7.3. Network Policy

Restricts network access:
- The NestJS app can connect to Redis.
- Redis cannot initiate connections back to the app.
- Other pods cannot reach Redis unless explicitly allowed.

### 7.4. Vault Integration

A manifest is used to:
- Deploy Vault Agent Injector or related sidecar.
- Automatically sync and inject static secrets (Redis password, etc.) into the namespace for usage by both NestJS and Redis.

## 8. Best Practices

- Use Helm values for all environment-specific parameters.
- Ensure TLS is enforced for all Ingresses.
- Regularly rotate Secrets and Certificates.
- Monitor resource usage and adjust HPA thresholds accordingly.
- Apply Kyverno and Network Policies to maintain compliance and reduce attack surface.


## 9. Deployment Commands

To install or upgrade the chart:
```bash
helm upgrade -i devops infrastructure/helm \
  --namespace test \
  --values infrastructure/helm/values.yaml
```

To verify the deployment:
```bash
kubectl get pods -n test
kubectl get ingress -n test
kubectl describe hpa -n test
```

## 10. Summary

This Helm-based setup provides:
- A secure, scalable, and efficient NestJS + Redis deployment.
- Automated verification (Kyverno), scaling (HPA), and access control (NetworkPolicy).
- Minimal privileges and optimized resources for production environments.