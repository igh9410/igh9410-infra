# igh9410-infra

Infrastructure repository for geonhyuk's cloud-native applications using GitOps methodology.

## 🏗️ Architecture Overview

This repository implements a modern cloud-native infrastructure using GitOps principles with ArgoCD for continuous deployment. The architecture consists of:

- **Kubernetes Cluster**: Self-managed Kubernetes cluster
- **GitOps**: ArgoCD for declarative application deployment
- **Infrastructure as Code**: Terraform for cloud resource management
- **Application Packaging**: Kustomize for Kubernetes manifest management
- **Networking**: Traefik as ingress controller with Cloudflare integration
- **Observability**: Prometheus, Grafana, and Loki stack
- **Database**: CloudNative-PG for PostgreSQL management

## 📁 Repository Structure

```
igh9410-infra/
├── apps/                           # Application definitions
│   ├── artskorner/                 # Production application
│   │   ├── base/                   # Base Kubernetes manifests
│   │   ├── overlays/prod/          # Production-specific patches
│   │   └── terraform/prod/         # App-specific infrastructure
│   └── gramnuri/                   # Development application
│       ├── base/                   # Base Kubernetes manifests
│       ├── overlays/dev/           # Development-specific patches
│       └── terraform/dev/          # App-specific infrastructure
├── argocd/                         # ArgoCD configuration
│   ├── apps/                       # Application definitions
│   ├── infra-apps/                 # Infrastructure application definitions
│   └── values/                     # Helm values for infrastructure
├── infrastructure/                 # Core infrastructure
│   └── terraform/                  # Main infrastructure code
├── diagram/                        # Architecture diagrams
└── Makefile                        # Automation scripts
```

## 🛠️ Technologies Used

### Core Infrastructure

- **Kubernetes**: Container orchestration platform
- **ArgoCD**: GitOps continuous delivery tool
- **Terraform**: Infrastructure as Code
- **Kustomize**: Kubernetes native configuration management

### Networking & Security

- **Traefik**: Modern reverse proxy and load balancer
- **Cloudflare**: DNS management and tunneling
- **Sealed Secrets**: Kubernetes secret management

### Observability

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Metrics visualization and dashboards
- **Loki**: Log aggregation system
- **Alloy**: Telemetry data collection

### Database

- **CloudNative-PG**: PostgreSQL operator for Kubernetes

## 🚀 Getting Started

### Prerequisites

1. **Kubernetes Cluster**: Running Kubernetes cluster with kubectl access
2. **Terraform**: v1.0+ installed
3. **Helm**: v3.0+ installed
4. **ArgoCD CLI**: For ArgoCD management
5. **Cloudflare Account**: For DNS and tunneling

### Initial Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/igh9410/igh9410-infra.git
   cd igh9410-infra
   ```

2. **Configure Terraform Backend**

   ```bash
   cd infrastructure/terraform
   # Create backend.conf file (add to .gitignore)
   echo 'endpoints = { s3 = "https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com" }' > backend.conf
   echo 'access_key = "YOUR_ACCESS_KEY"' >> backend.conf
   echo 'secret_key = "YOUR_SECRET_KEY"' >> backend.conf
   ```

3. **Initialize Infrastructure**

   ```bash
   terraform init -backend-config=backend.conf
   terraform plan
   terraform apply
   ```

4. **Deploy ArgoCD Applications**
   ```bash
   kubectl apply -f argocd/infrastructure-app-of-apps.yaml
   kubectl apply -f argocd/applications-app-of-apps.yaml
   ```

## 🔄 GitOps Workflow

### Application Deployment Flow

1. **Code Changes**: Push application code to respective repositories
2. **Image Build**: GitHub Actions builds and pushes container images
3. **Manifest Update**: Update image tags in Kustomize overlays
4. **ArgoCD Sync**: ArgoCD detects changes and deploys automatically

### Infrastructure Updates

1. **Terraform Changes**: Modify infrastructure code
2. **Plan & Apply**: Review and apply Terraform changes
3. **ArgoCD Config**: Update ArgoCD applications if needed
4. **Verification**: Ensure services are healthy

## 📊 Monitoring & Observability

### Access Points

- **Grafana**: `https://grafana.yourdomain.com` (via Traefik ingress)
- **Prometheus**: `https://prometheus.yourdomain.com`
- **ArgoCD**: `https://argocd.yourdomain.com`

### Key Metrics

- Application performance and availability
- Infrastructure resource utilization
- Database health and performance
- Network traffic and security events

## 🔧 Common Operations

### Update Application Image

```bash
cd apps/[app-name]/overlays/[environment]
# Edit kustomization.yaml to update image tag
git commit -m "Update [app-name] to [new-tag]"
git push
```

### Scale Application

```bash
cd apps/[app-name]/overlays/[environment]
# Edit deployment-patch.yaml to modify replicas
git commit -m "Scale [app-name] to [replica-count] replicas"
git push
```

### Add New Environment

```bash
cd apps/[app-name]
mkdir -p overlays/[new-env]
# Copy and modify files from existing overlay
# Update ArgoCD application definition
```

## 🛡️ Security Considerations

- **Network Policies**: Implemented via Cilium Network Policies (TODO)
- **RBAC**: Proper role-based access control configured
- **Image Security**: Container images scanned for vulnerabilities
- **TLS Termination**: Handled by Cloudflare and Traefik

## 📈 Future Improvements

- [ ] Implement comprehensive CI/CD pipeline testing
- [ ] Add automated security scanning
- [ ] Implement disaster recovery procedures
- [ ] Add performance testing automation
- [ ] Implement multi-cluster deployment
- [ ] Add cost optimization monitoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following the established patterns
4. Test changes in development environment
5. Submit pull request with detailed description

---

## 🏗️ 아키텍처 개요

이 저장소는 ArgoCD를 사용한 지속적 배포와 함께 GitOps 원칙을 사용하여 현대적인 클라우드 네이티브 인프라스트럭처를 구현합니다. 아키텍처는 다음으로 구성됩니다:

- **Kubernetes 클러스터**: 자체 관리 Kubernetes 클러스터
- **GitOps**: 선언적 애플리케이션 배포를 위한 ArgoCD
- **Infrastructure as Code**: 클라우드 리소스 관리를 위한 Terraform
- **애플리케이션 패키징**: Kubernetes 매니페스트 관리를 위한 Kustomize
- **네트워킹**: Cloudflare 통합을 통한 Traefik 인그레스 컨트롤러
- **가시성**: Prometheus, Grafana, Loki 스택
- **데이터베이스**: PostgreSQL 관리를 위한 CloudNative-PG

## 📁 저장소 구조

```
igh9410-infra/
├── apps/                           # 애플리케이션 정의
│   ├── artskorner/                 # 프로덕션 애플리케이션
│   │   ├── base/                   # 기본 Kubernetes 매니페스트
│   │   ├── overlays/prod/          # 프로덕션별 패치
│   │   └── terraform/prod/         # 앱별 인프라스트럭처
│   └── gramnuri/                   # 개발 애플리케이션
│       ├── base/                   # 기본 Kubernetes 매니페스트
│       ├── overlays/dev/           # 개발별 패치
│       └── terraform/dev/          # 앱별 인프라스트럭처
├── argocd/                         # ArgoCD 구성
│   ├── apps/                       # 애플리케이션 정의
│   ├── infra-apps/                 # 인프라스트럭처 애플리케이션 정의
│   └── values/                     # 인프라스트럭처용 Helm 값
├── infrastructure/                 # 핵심 인프라스트럭처
│   └── terraform/                  # 메인 인프라스트럭처 코드
├── diagram/                        # 아키텍처 다이어그램
└── Makefile                        # 자동화 스크립트
```

## 🛠️ 사용 기술

### 핵심 인프라스트럭처

- **Kubernetes**: 컨테이너 오케스트레이션 플랫폼
- **ArgoCD**: GitOps 지속적 전달 도구
- **Terraform**: Infrastructure as Code
- **Kustomize**: Kubernetes 네이티브 구성 관리

### 네트워킹 및 보안

- **Traefik**: 현대적인 리버스 프록시 및 로드 밸런서
- **Cloudflare**: DNS 관리 및 터널링
- **Sealed Secrets**: Kubernetes 시크릿 관리

### 가시성

- **Prometheus**: 메트릭 수집 및 알림
- **Grafana**: 메트릭 시각화 및 대시보드
- **Loki**: 로그 집계 시스템
- **Alloy**: 텔레메트리 데이터 수집

### 데이터베이스

- **CloudNative-PG**: Kubernetes용 PostgreSQL 오퍼레이터

## 🚀 시작하기

### 전제 조건

1. **Kubernetes 클러스터**: kubectl 접근 권한이 있는 실행 중인 Kubernetes 클러스터
2. **Terraform**: v1.0+ 설치됨
3. **Helm**: v3.0+ 설치됨
4. **ArgoCD CLI**: ArgoCD 관리용
5. **Cloudflare 계정**: DNS 및 터널링용

### 초기 설정

1. **저장소 복제**

   ```bash
   git clone https://github.com/igh9410/igh9410-infra.git
   cd igh9410-infra
   ```

2. **Terraform 백엔드 구성**

   ```bash
   cd infrastructure/terraform
   # backend.conf 파일 생성 (.gitignore에 추가)
   echo 'endpoints = { s3 = "https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com" }' > backend.conf
   echo 'access_key = "YOUR_ACCESS_KEY"' >> backend.conf
   echo 'secret_key = "YOUR_SECRET_KEY"' >> backend.conf
   ```

3. **인프라스트럭처 초기화**

   ```bash
   terraform init -backend-config=backend.conf
   terraform plan
   terraform apply
   ```

4. **ArgoCD 애플리케이션 배포**
   ```bash
   kubectl apply -f argocd/infrastructure-app-of-apps.yaml
   kubectl apply -f argocd/applications-app-of-apps.yaml
   ```

## 🔄 GitOps 워크플로우

### 애플리케이션 배포 흐름

1. **코드 변경**: 각 저장소에 애플리케이션 코드 푸시
2. **이미지 빌드**: GitHub Actions가 컨테이너 이미지 빌드 및 푸시
3. **매니페스트 업데이트**: Kustomize 오버레이에서 이미지 태그 업데이트
4. **ArgoCD 동기화**: ArgoCD가 변경 사항을 감지하고 자동으로 배포

### 인프라스트럭처 업데이트

1. **Terraform 변경**: 인프라스트럭처 코드 수정
2. **계획 및 적용**: Terraform 변경 사항 검토 및 적용
3. **ArgoCD 구성**: 필요시 ArgoCD 애플리케이션 업데이트
4. **검증**: 서비스가 정상인지 확인

## 📊 모니터링 및 가시성

### 접근 지점

- **Grafana**: `https://grafana.yourdomain.com` (Traefik 인그레스를 통해)
- **Prometheus**: `https://prometheus.yourdomain.com`
- **ArgoCD**: `https://argocd.yourdomain.com`

### 주요 메트릭

- 애플리케이션 성능 및 가용성
- 인프라스트럭처 리소스 사용률
- 데이터베이스 상태 및 성능
- 네트워크 트래픽 및 보안 이벤트

## 🔧 일반적인 작업

### 애플리케이션 이미지 업데이트

```bash
cd apps/[app-name]/overlays/[environment]
# kustomization.yaml을 편집하여 이미지 태그 업데이트
git commit -m "Update [app-name] to [new-tag]"
git push
```

### 애플리케이션 스케일링

```bash
cd apps/[app-name]/overlays/[environment]
# deployment-patch.yaml을 편집하여 복제본 수정
git commit -m "Scale [app-name] to [replica-count] replicas"
git push
```

### 새 환경 추가

```bash
cd apps/[app-name]
mkdir -p overlays/[new-env]
# 기존 오버레이에서 파일 복사 및 수정
# ArgoCD 애플리케이션 정의 업데이트
```

## 🛡️ 보안 고려사항

- **네트워크 정책**: Cilium 네트워크 정책을 통해 구현 (TODO)
- **RBAC**: 적절한 역할 기반 접근 제어 구성
- **이미지 보안**: 취약점에 대한 컨테이너 이미지 스캔
- **TLS 종료**: Cloudflare 및 Traefik에서 처리

## 📈 향후 개선사항

- [ ] 포괄적인 CI/CD 파이프라인 테스트 구현
- [ ] 자동화된 보안 스캐닝 추가
- [ ] 재해 복구 절차 구현
- [ ] 성능 테스트 자동화 추가
- [ ] 멀티 클러스터 배포 구현
- [ ] 비용 최적화 모니터링 추가

## 🤝 기여하기

1. 저장소 포크
2. 기능 브랜치 생성
3. 기존 패턴을 따라 변경사항 적용
4. 개발 환경에서 변경사항 테스트
5. 상세한 설명과 함께 풀 리퀘스트 제출
