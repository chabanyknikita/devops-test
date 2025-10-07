# 🚀 Full Deployment Guide for NestJS + Redis + Security Monitoring Stack on Kubernetes

This document provides a **complete step-by-step guide** for deploying your NestJS application with Redis, Vault integration, Kyverno policy enforcement, and the extended **Security Monitoring Stack** on Kubernetes.

---

## ⚙️ 1. Prerequisites

Before deployment, ensure you have:

- A running **Kubernetes cluster**
- Installed **kubectl** and **helm**
- Access to **Cloudflare DNS** (for domain setup)
- **Vault**, **Kyverno**, and **Nginx**, **Cert-Manager**, **Metrics-Server** and **Redis-Operator**
- A valid **GitHub repository** with Actions enabled

---

## 🧩 2. Deploy Cluster Core Components

### 2.1. Metrics Server

The **Metrics Server** provides metrics for autoscaling and monitoring.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/high-availability-1.21+.yaml
```
✅ This enables resource metrics collection required for the Horizontal Pod Autoscaler (HPA).

### 2.2. Ingress Controller (NGINX)

Install the NGINX Ingress Controller to route external HTTP/HTTPS traffic.
```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```
✅ After deployment, the controller will expose an external IP for ingress routing.

### 2.3. Cert-Manager

Deploy cert-manager to automate TLS certificate issuance (e.g., via Let’s Encrypt).
```bash
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true
```
✅ Cert-manager will handle HTTPS certificates for your application ingress.

## 🧱 3. Redis Operator

The Redis Operator manages Redis clusters and automates leader-follower replication.
```bash
helm repo add ot-helm https://ot-container-kit.github.io/helm-charts/
helm upgrade redis-operator ot-helm/redis-operator \
  --install --create-namespace --namespace ot-operators
```
✅ This ensures Redis clusters are deployed and maintained automatically.

## 🔐 4. Kyverno Policy Engine

Kyverno validates Kubernetes resources against security and compliance policies.
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```
✅ Kyverno will be used to verify container image signatures (Cosign).

## 🧭 5. HashiCorp Vault Setup

Vault is used for secure secret management in the cluster.
### 5.1. Install Vault
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "injector.enabled=true" \
  --set "ui.enabled=true" \
  --namespace vault --create-namespace
```
✅ Vault runs in development mode with a root token for testing.

### 5.2. Vault Configuration

Create the test namespace:
```bash
kubectl create ns test
```

Enable Kubernetes authentication and configure Vault for the cluster, exec inside vault pod and run:
```bash
vault auth enable -path test kubernetes

vault write auth/test/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
```

Enable a KVv2 secrets engine:
```bash
vault secrets enable -path=kvv2 kv-v2
```

Create a Vault policy:
```bash
vault policy write test - <<EOF
path "kvv2/data/test/secret" {
  capabilities = ["read", "list"]
}
EOF
```

Create a role bound to a Kubernetes ServiceAccount:
```bash
vault write auth/test/role/role1 \
  bound_service_account_names=demo-static-app \
  bound_service_account_namespaces=test \
  policies=test \
  audience=vault \
  ttl=24h
```

Store Redis password securely:
```bash
vault kv put kvv2/test/secret pass="soSecure"
```
✅ Your application and Redis will fetch this password dynamically via Vault.

### 5.3. Vault Secrets Operator

Install the Vault Secrets Operator to sync secrets into Kubernetes.
```bash
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --set defaultVaultConnection.enabled="true" \
  --set defaultVaultConnection.address="http://vault.vault.svc.cluster.local:8200" \
  --set defaultVaultConnection.skipTLSVerify="false" \
  -n vault-secrets-operator-system --create-namespace
```
✅ The operator keeps Kubernetes secrets synchronized with Vault in real-time.

## 🏷️ 6. Node Labeling for Scheduling

Label a specific node to run your application and Redis:
```bash
kubectl label node your_node_name service=true
```
✅ This ensures pods are scheduled on nodes with the correct purpose.

## 🌐 7. DNS and Cloudflare Setup

Get the external IP of your NGINX Ingress Controller:
```bash
kubectl get svc -n ingress-nginx
```

Copy the EXTERNAL-IP value and add it to your Cloudflare DNS as:
- Type: A
- Name: test.passwdsec.online
- Value: <EXTERNAL-IP>
✅ This allows traffic to your application via HTTPS.

## 🧾 8. GitHub Secrets Configuration
### 8.1. Kubernetes Configuration

Encode your kubeconfig in Base64:
```bash
cat ~/.kube/config | base64 | pbcopy
```

Then add it as a GitHub Secret:
`KUBE_CONFIG=<encoded_content>`
✅ Used by GitHub Actions to deploy Helm charts to your cluster.

## 8.2. Cosign Signing Keys

Generate signing keys for container image verification:
```bash
cosign generate-key-pair
```

Update the Kyverno policy manifest with your Cosign public key
and encode your private key to Base64:
```bash
cat cosign.key | base64 | pbcopy
```

Then add to GitHub Secrets:
`COSIGN_PRIVATE_KEY=<encoded_private_key>`
✅ Ensures all container images deployed are verified and signed.

## 🧠 9. (Optional) Security Monitoring Stack

You can optionally deploy the full monitoring and security suite from your custom Helm chart:

Repository: [security-monitoring-template](https://github.com/chabanyknikita/security-monitoring-template)

This stack includes:
- 🟢 Promtail – Log collector
- 📊 Grafana – Dashboards and visualization
- 📈 VictoriaMetrics Stack – Metrics storage
- 📚 Victoria Logs – Centralized log management
- 🔐 Victoria Auth – Authentication for Grafana and Metrics
- 🚨 Alertmanager – Alert routing
- 🧱 Kube-Bench Exporter – CIS Benchmark scanner
- 🕵️ Falco Exporter – Runtime security detection
- 🧩 Trivy-Operator – Vulnerability and misconfiguration scanner
- ⚙️ Kyverno – Policy enforcement

✅ Provides complete observability, vulnerability detection, and compliance checks.

## 📦 10. Deploy the Application

Finally, deploy your Helm chart for the NestJS application and Redis:
- Run CI/CD pipeline in your repo

To verify the deployment:
```bash
kubectl get pods -n test
kubectl get svc -n test
kubectl get ingress -n test
```

## 🧩 11. Summary
| Component                     | Purpose                         |
| ----------------------------- | ------------------------------- |
| **Metrics Server**            | Enables autoscaling metrics     |
| **Ingress-NGINX**             | Routes external traffic         |
| **Cert-Manager**              | Manages HTTPS certificates      |
| **Redis Operator**            | Automates Redis cluster         |
| **Kyverno**                   | Enforces signed image policy    |
| **Vault + Operator**          | Secret management               |
| **HPA**                       | Autoscaling application         |
| **NetworkPolicy**             | Secure pod-to-pod communication |
| **Security Monitoring Stack (optional)** | Observability & protection      |


## ✅ 12. Deployment Flow Summary

- Deploy base infrastructure (Metrics, Ingress, Cert-Manager)
- Install Redis Operator
- Deploy Kyverno and Vault
- Configure Vault authentication & policies
- Setup Vault Secrets Operator
- Label nodes for targeted scheduling
- Configure Cloudflare DNS
- Add GitHub Secrets (KUBE_CONFIG, COSIGN_PRIVATE_KEY)
- Deploy optional monitoring stack
- Deploy NestJS + Redis via CI/CD

---

# 🎯 Final Notes

- Ensure all services are in the Running state before deploying the app.
- Confirm certificate issuance via kubectl describe certificate -n test.
- Validate signed image verification in Kyverno logs.
- Access your app securely at:
    👉 https://test.passwdsec.online
