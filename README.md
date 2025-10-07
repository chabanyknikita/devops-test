# 🧩 DevOps Testing Task
## 📘 Опис проєкту

Цей репозиторій містить NestJS додаток, а також повну DevOps-інфраструктуру для його контейнеризації, деплою та безпеки в Kubernetes.
Мета — продемонструвати повний CI/CD цикл, інтеграцію з Vault, Kyverno, Redis, автоматичне масштабування, політики безпеки, моніторинг та підписування імеджів.

## 📂 Структура проєкту
```
├── Dockerfile
├── docs
│   ├── ci-cd.md
│   ├── configuration.md
│   ├── docker.md
│   ├── manifests.md
│   └── summary.md
├── eslint.config.mjs
├── infrastructure
│   ├── helm
│   │   ├── Chart.yaml
│   │   ├── templates/
│   │   └── values.yaml
│   └── manifests/
│       ├── auto-scaler.yaml
│       ├── kyverno.yaml
│       ├── network-policy.yaml
│       └── vault.yaml
├── src/
│   ├── app.controller.ts
│   ├── app.module.ts
│   ├── app.service.ts
│   ├── main.ts
│   └── redis/
│       ├── redis.service.ts
│       └── redis.service.spec.ts
├── test/
│   ├── app.e2e-spec.ts
│   └── jest-e2e.json
├── package.json
├── nest-cli.json
├── tsconfig.json
└── README.md
```

## 📦 Основні частини репозиторію
### 🧠 src/
Тут розміщений NestJS застосунок, який виконує основну бізнес-логіку.
Включає базову інтеграцію з Redis та тестовий endpoint /redis для health-check.


### 🛠 infrastructure/helm/

Helm Chart для деплою застосунку в Kubernetes.
Містить:
- Deployment, Service, Ingress для NestJS
- Init контейнер, який очікує доступність Redis
- Secrets
- Resource limits/requests
- SecurityContext (runAsNonRoot, drop capabilities)
- HPA, ServiceMonitor, PodDisruptionBudget
- TLS через cert-manager

Цей чарт дозволяє швидко розгорнути додаток у будь-якому кластері за допомогою helm upgrade -i.

### 🧾 infrastructure/manifests/

Додаткові Kubernetes маніфести:
- auto-scaler.yaml – Horizontal Pod Autoscaler
- network-policy.yaml – обмежує трафік, дозволяючи доступ лише між апкою та Redis
- kyverno.yaml – політика перевірки підписаних контейнерів за допомогою Cosign
- vault.yaml – інтеграція з HashiCorp Vault (Vault Secrets Operator, policy, auth, secrets)


### 📚 docs/

Тут зібрана вся документація по проєкту:
- ci-cd.md – GitHub Actions
- configuration.md – інструкції по розгортаню всієї апки
- docker.md – опис побудови імеджу через Buildah
- manifests.md – опис усіх маніфестів
- summary.md – загальна архітектура, стек, вибір технологій

## 🚀 Основні технології

| Компонент                   | Використано                                                  | Причина                                                                |
| --------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| **Container Builder**       | **Buildah**                                                  | Без root доступу, кешування шарів, швидше за Docker, зручний для CI/CD |
| **Security Policy Engine**  | **Kyverno**                                                  | Автоматичне застосування політик безпеки, валідація підписів імеджів   |
| **Image Signing**           | **Cosign**                                                   | Перевірка цілісності та походження контейнерів                         |
| **Secret Management**       | **HashiCorp Vault + Vault Secrets Operator**                 | Безпечне управління секретами через Kubernetes інтеграцію              |
| **Redis**                   | **Redis Cluster**                                            | Використовується як кеш і механізм тимчасового зберігання даних        |
| **Ingress Controller**      | **NGINX Ingress + cert-manager**                             | TLS сертифікати Let's Encrypt, маршрутизація HTTP/S                    |
| **Monitoring**              | **Victoria Metrics Stack, Grafana, Falco, Kyverno Exporter** | Безпека, логування, алерти, метрики                                    |
| **Scaling**                 | **HPA (Horizontal Pod Autoscaler)**                          | Автоматичне масштабування додатку                                      |
| **Network Security**        | **NetworkPolicy**                                            | Обмеження доступу між подами                                           |
| **Image Registry Security** | **Cosign Key Validation (Kyverno Policy)**                   | Забезпечення підпису контейнерів                                       |
| **Vault Policy**            | **Fine-grained RBAC**                                        | Доступ лише до потрібних секретів у конкретному namespace              |
| **Build pipeline**          | **GitHub Actions + Helm Deploy**                             | Повністю автоматизований деплой у кластер                              |


## 🧩 Архітектура

![architecture](./docs/test-devops.jpg)