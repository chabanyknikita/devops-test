# ⚙️ CI/CD Pipeline Documentation

## 🎯 Objective

This document describes the setup of a complete **CI/CD pipeline** using **GitHub Actions** for a **NestJS application**.  
The pipeline performs the following key stages:

1. **Build a Docker image**
2. **Push the image to GitHub Container Registry (GHCR)**
3. **Perform security scanning**
4. **Sign the image with Cosign**
5. **Deploy to Kubernetes using Helm Charts**
6. **Use environment variables and secrets stored in Vault**

The deployment uses **Redis Operator** for managing Redis clusters within Kubernetes.

---

## 🧰 Technologies Used

- **GitHub Actions** — CI/CD automation  
- **Docker / Buildah** — container image building and pushing  
- **Cosign** — image signing for supply-chain security  
- **Trivy** — image vulnerability scanning  
- **Helm** — Kubernetes deployment  
- **Vault (HashiCorp)** — secure secrets management  
- **Redis Operator** — scalable Redis deployment in Kubernetes  

---

## 🔐 Secrets and Environment Variables

Sensitive data such as Kubernetes credentials, signing keys, and database secrets are **stored in HashiCorp Vault**.  
The CI pipeline **references the location of each secret** instead of embedding actual values.

Example of secret mapping:

| Secret Name | Description | Source |
|--------------|-------------|--------|
| `KUBE_CONFIG` | Base64-encoded kubeconfig for cluster access | GitHub |
| `COSIGN_PRIVATE_KEY` | Base64-encoded private key for image signing | GitHub |
| `GITHUB_TOKEN` | GitHub Actions default token | GitHub |
| `devops-db-secret` | Redis credentials secret | Vault |

---

## 🚀 GitHub Actions Workflow File

```yaml
on:
  push:
    branches:
      - 'main'
      - 'master'
      - 'feat/*'

jobs:
  converge:
    name: Build To Github
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Install Buildah
        run: |
          sudo apt-get update
          sudo apt-get -y install buildah

      - name: Build and Push Image
        env:
          IMAGE: ghcr.io/${{ github.repository }}:${{ github.sha }}
          CACHE_REPO: ghcr.io/${{ github.repository }}/cache
        run: |
          buildah bud \
            --format docker \
            -f Dockerfile \
            --layers \
            --cache-from $CACHE_REPO \
            --cache-to $CACHE_REPO \
            -t $IMAGE \
            .

      - name: Push Image
        env:
          IMAGE: ghcr.io/${{ github.repository }}:${{ github.sha }}
        run: buildah push $IMAGE

  security_scan:
    name: Security Scan
    needs: converge
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0  

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@0.28.0
        with:
          image-ref: 'ghcr.io/${{ github.repository }}:${{ github.sha }}'
          format: 'table'
          exit-code: '0'
          ignore-unfixed: true
          vuln-type: 'os,library'
          severity: 'CRITICAL,HIGH'

  sign-image:
    name: Sign Image
    needs: [converge, security_scan]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.10.0

      - name: Sign image with a key
        run: |
          echo $COSIGN_PRIVATE_KEY | base64 -d > cosign.key
          cosign sign --yes --key cosign.key ${IMAGE}
        env:
          IMAGE: ghcr.io/${{ github.repository }}:${{ github.sha }}
          COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}

  deploy:
    name: Deploy
    needs: sign-image
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Install Helm
        uses: azure/setup-helm@v3
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
        id: install

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Set up Kubeconfig
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.KUBE_CONFIG }}" | base64 --decode > $HOME/.kube/config

      - name: Add Helm Repo
        run: |
          helm repo add ot-helm https://ot-container-kit.github.io/helm-charts/
          helm repo update

      - name: Create Namespace
        run: |
          kubectl create namespace test || echo "Namespace test already exists"

      - name: Deploy Auto-Scaler
        run: |
          kubectl apply -f infrastructure/manifests/auto-scaler.yaml

      - name: Deploy Kyverno Policies
        run: |
          kubectl apply -f infrastructure/manifests/kyverno.yaml

      - name: Deploy Network Policies
        run: |
          kubectl apply -f infrastructure/manifests/network-policy.yaml

      - name: Configure Vault Secret Operator
        run: |
          kubectl apply -f infrastructure/manifests/vault.yaml

      - name: Deploy Redis
        run: |
          helm upgrade --install redis-cluster ot-helm/redis-cluster \
            --set "redisCluster.clusterSize=1" \
            --set "redisCluster.leader.replicas=1" \
            --set "redisCluster.follower.replicas=1" \
            --set "redisCluster.redisSecret.secretName=devops-db-secret" \
            --set "redisCluster.redisSecret.secretKey=pass" \
            --set "redisCluster.resources.requests.cpu=100m" \
            --set "redisCluster.resources.requests.memory=128Mi" \
            --set "redisCluster.resources.limits.cpu=200m" \
            --set "redisCluster.resources.limits.memory=256Mi" \
            --set-string "redisCluster.leader.nodeSelector.service=true" \
            --set-string "redisCluster.follower.nodeSelector.service=true" \
            --namespace test

      - name: Deploy Application
        run: |
          helm upgrade -i devops infrastructure/helm \
            --values infrastructure/helm/values.yaml \
            --set-string "defaultImage=ghcr.io/${GITHUB_REPOSITORY}" \
            --set-string "defaultImageTag=${GITHUB_SHA}" \
            --namespace test \
            --create-namespace
```

---


## 🧩 Pipeline Overview
| Stage                 | Description                                | Tools                  |
| --------------------- | ------------------------------------------ | ---------------------- |
| **Build**             | Builds Docker image using Buildah          | Buildah        |
| **Push**              | Pushes image to GHCR                       | GitHub Registry        |
| **Scan**              | Scans image for vulnerabilities            | Trivy                  |
| **Sign**              | Digitally signs image                      | Cosign                 |
| **Deploy**            | Deploys app + Redis using Helm             | Helm, Kubernetes       |
| **Security Policies** | Applies Kyverno and network restrictions   | Kyverno, NetworkPolicy |
| **Secrets**           | Pulled from HashiCorp Vault during runtime | Vault                  |

## ✅ Result
- Fully automated CI/CD pipeline for NestJS
- Secure build and deployment using Vault, Cosign, and Trivy
- Efficient Redis management via Redis Operator
- Deployment handled through Helm Charts
- Safe Kubernetes rollout with Kyverno and network policies

### Outcome:

The pipeline ensures secure, automated, and reproducible delivery of your NestJS application into a Kubernetes cluster, following DevSecOps best practices