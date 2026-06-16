# AWS Istanbul Local Zone'da Terragrunt ile Production EKS Kurulumu

> Türkiye'de faaliyet gösteren şirketlerin büyük bir kısmı KVKK nedeniyle public cloud kullanamıyor. Veri yurt dışına çıkamaz, ama Frankfurt'taki bir EKS cluster'ı tam olarak bunu yapıyor. AWS Istanbul Local Zone bu kısıtlamayı kırdı — artık veriler Türkiye'de kalırken tam anlamıyla cloud-native çalışmak mümkün. Biz de bunu Terragrunt ile production'da nasıl kurduğumuzu, yol boyunca nerelerde takıldığımızı ve her engeli nasıl aştığımızı bu yazıda belgeliyoruz.

---

## Neden Bu Yazıyı Yazdım?

Türkiye'de yazılım geliştiren ekiplerin önünde yıllardır görünmez bir duvar vardı: **KVKK**.

6698 sayılı Kişisel Verilerin Korunması Kanunu, kişisel verinin yurt dışına aktarılmasını ciddi koşullara bağlıyor. Fintech, sağlık, e-ticaret, sigorta — kullanıcı verisi işleyen her sektörden şirket aynı soruyla boğuşuyordu: "Modern cloud altyapısı kurmak istiyoruz, ama verimiz Türkiye'de kalmak zorunda."

Çözüm seçenekleri hep aynıydı ve hep sancılıydı:

- **On-premise datacenter** — yüksek sermaye maliyeti, yavaş ölçeklenme, ops yükü
- **Colocation** — biraz daha esnek ama aynı sorunların çoğu hâlâ var
- **Frankfurt'ta AWS** — KVKK riskini göze almak demek; hukuki belirsizlik, denetim kaygısı
- **Türkiye'deki yerel cloud sağlayıcılar** — managed Kubernetes yok, ekosistem kısıtlı

Sonra AWS, Istanbul Local Zone'u duyurdu.

`eu-central-1-ist-1a` — compute ve storage Türkiye topraklarında, Frankfurt'un yönetim düzlemiyle bağlı, tam AWS ekosistemi. KVKK uyumu artık cloud-native mimariyle çelişmiyor.

Biz de bu Local Zone'u production EKS cluster'ı kurmak için test ettik. Teoride basitti: aynı altyapı, sadece worker node'lar Istanbul'da. Pratikte ise Local Zone'a özgü kısıtlamalar, provider versiyon çakışmaları ve Karpenter v1'in değişen API'si bizi uzun süre uğraştırdı.

Bu yazı, o süreçte öğrendiklerimizin tamamını belgeleyen bir rehber. KVKK uyumu arayan ekipler için sıfırdan production'a her adımı gerçek kod örnekleriyle anlattım.

---

## Istanbul Local Zone Nedir?

AWS Local Zone'lar, AWS altyapısının büyük şehirlere taşınmış küçük uzantılarıdır. Frankfurt ana bölgesine (`eu-central-1`) bağlı olan Istanbul Local Zone, `eu-central-1-ist-1a` identifier'ıyla hizmet veriyor.

**Ne işe yarar?**

Standart cloud mimarisinde kullanıcı trafiği Frankfurt'taki datacenter'a gidip geliyor. Local Zone ile bu mesafe dramatik şekilde kısalıyor:

| Senaryo | Yaklaşık Latency |
|---------|-----------------|
| Türkiye → Frankfurt EKS | ~35-40ms |
| Türkiye → Istanbul Local Zone EKS | ~2-8ms |
| Fark | **~5-6x daha hızlı** |

Bu fark şu use case'lerde kritik önem taşır:

- **Gaming backend'leri** — ping hassasiyeti olan oyunlar
- **Fintech uygulamaları** — gerçek zamanlı fiyatlama, işlem onayı
- **Video streaming** — adaptive bitrate, düşük buffer
- **Veri egemenliği** — Türkiye'de işlenmesi gereken veriler
- **IoT platformları** — düşük latency gerektiren cihaz komutları

---

## 1. Istanbul Local Zone'u Anlamak

### Desteklenen Instance Tipleri

Istanbul Local Zone yalnızca **7. nesil Intel** instance'larını destekler:

| Tip | Kullanım Alanı | vCPU Aralığı | Örnek Kullanım |
|-----|---------------|-------------|---------------|
| `c7i` | Compute-optimized | 2-192 | Web server, batch işleme, CI/CD |
| `m7i` | General purpose | 2-192 | Uygulama sunucuları, microservice |
| `r7i` | Memory-optimized | 2-192 | In-memory cache, analitik DB |

> **Önemli:** 6. nesil ve altı (`c6i`, `m6i` vb.) Istanbul'da **desteklenmez**. Graviton/ARM (`c7g`, `m7g` vb.) instance'ları da şu an desteklenmemektedir. Karpenter konfigürasyonunda bu kritik bir detay.

### Kritik Kısıtlamalar

Local Zone standart bir AWS bölgesi değildir, bazı servisleri ve özellikleri desteklemez:

| Kısıtlama | Açıklama | Çözüm |
|-----------|----------|-------|
| Spot instance yok | Tüm node'lar ON_DEMAND olmak zorunda | Maliyet planlaması yapın |
| NAT Gateway yok | Internet çıkışı için Frankfurt NAT kullanılır, cross-zone transfer maliyeti oluşur | [fck-nat](https://github.com/AndrewGuenther/fck-nat) |
| EKS Control Plane yok | Sadece worker node'lar Local Zone'da olabilir | Control plane Frankfurt'ta kalır |
| EFS yok | Elastic File System Local Zone'da desteklenmez | EBS (gp3) veya self-hosted NFS |
| RDS / Aurora yok | Managed DB desteklenmez, KVKK nedeniyle Frankfurt'a da gönderilmez | EC2 üzerinde Percona Server / Percona XtraDB Cluster |
| ElastiCache yok | Managed cache yok | Self-hosted Redis (EC2 veya pod olarak) |
| Graviton / ARM yok | `c7g`, `m7g` gibi ARM instance'lar desteklenmez | Yalnızca Intel (`c7i`, `m7i`, `r7i`) kullanın |
| ALB — subnet annotation gerekir | ALB Local Zone'da oluşturulabilir; Ingress'e `alb.ingress.kubernetes.io/subnets: eu-central-1-ist-1a` annotation'ı eklenince ALB doğrudan Istanbul subnet'inde kurulur | Ingress annotation'ına Local Zone subnet adını verin |
| S3 henüz yerel değil | S3 bucket'ları şu an Frankfurt'ta yaratılır, veri AZ dışına çıkabilir | S3 Express One Zone yakında Istanbul Local Zone'da GA olması bekleniyor; çıkınca `Infrequent Access` class ile yerel bucket kullanın |

#### Veritabanı: Neden Frankfurt seçenek değil?

RDS / Aurora Istanbul'da desteklenmez. Ama Frankfurt'ta managed DB açmak da KVKK açısından sorunlu — kişisel veri Türkiye dışına çıkmış olur.

Önerilen yaklaşım: **EC2 üzerinde self-hosted veritabanı**, Istanbul Local Zone subnet'inde.

| Seçenek | Açıklama | Kullanım |
|---------|----------|---------|
| [Percona Server for MySQL](https://www.percona.com/mysql/software/percona-server-for-mysql) | MySQL uyumlu, enterprise özellikler | Genel OLTP |
| [Percona XtraDB Cluster](https://www.percona.com/mysql/software/percona-xtradb-cluster) | Multi-master MySQL cluster | Yüksek erişilebilirlik |
| [Percona Distribution for PostgreSQL](https://www.percona.com/postgresql/software/postgresql-distribution) | PostgreSQL + HA araçları | PostgreSQL workload'ları |

Bu yaklaşım hem verinin Türkiye'de kalmasını sağlar hem de yönetilen servis kısıtlamasını aşar.

> **S3 notu:** S3 Express One Zone'un Istanbul Local Zone'da GA olması bekleniyor. GA olduğunda bucket'ları `Infrequent Access` class ile local zone'da oluşturmak mümkün olacak.

### Mimari Genel Bakış

```
┌─────────────────────────────────────────────────────────┐
│                   eu-central-1 (Frankfurt)               │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                    VPC 10.20.0.0/16              │   │
│  │                                                  │   │
│  │  ┌──────────────┐    ┌──────────────┐           │   │
│  │  │ eu-central-1a│    │ eu-central-1b│           │   │
│  │  │              │    │              │           │   │
│  │  │ Private[0]   │    │ Private[1]   │           │   │
│  │  │ 10.20.0.0/19 │    │ 10.20.64.0/19│           │   │
│  │  │              │    │              │           │   │
│  │  │ ┌──────────┐ │    │              │           │   │
│  │  │ │EKS Control│ │    │  EKS Control │           │   │
│  │  │ │  Plane   │ │    │    Plane     │           │   │
│  │  │ └──────────┘ │    │              │           │   │
│  │  │ ┌──────────┐ │    │              │           │   │
│  │  │ │NAT Gateway│ │    │              │           │   │
│  │  │ └────┬─────┘ │    │              │           │   │
│  │  └──────│───────┘    └──────────────┘           │   │
│  │         │                                        │   │
│  │  ┌──────│──────────────────────────────────┐    │   │
│  │  │      │    eu-central-1-ist-1a (Istanbul) │    │   │
│  │  │      │                                  │    │   │
│  │  │  ┌───▼──────────────────────────────┐   │    │   │
│  │  │  │  Private[2] — 10.20.32.0/19      │   │    │   │
│  │  │  │                                  │   │    │   │
│  │  │  │  ┌────────────┐ ┌─────────────┐  │   │    │   │
│  │  │  │  │ Node Group │ │  Karpenter  │  │   │    │   │
│  │  │  │  │ m7i.xlarge │ │  Nodes      │  │   │    │   │
│  │  │  │  │ (static)   │ │  c7i/m7i/r7i│  │   │    │   │
│  │  │  │  └────────────┘ └─────────────┘  │   │    │   │
│  │  │  └──────────────────────────────────┘   │    │   │
│  │  └──────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Internet ──► ALB (Istanbul Local Zone) ──► Pods (Istanbul) │
└──────────────────────────────────────────────────────────────┘
```

**Trafik akışı:**
- **Gelen trafik:** Internet → ALB (Istanbul Local Zone — `alb.ingress.kubernetes.io/subnets: eu-central-1-ist-1a` annotation'ı ile) → Pod (Istanbul)
- **Çıkan trafik:** Pod (Istanbul) → NAT instance / fck-nat (EC2) → Internet *(NAT Gateway Istanbul'da yok; Frankfurt NAT kullanmak cross-zone transfer maliyeti doğurur)*
- **Control plane iletişimi:** Worker node (Istanbul) ↔ API Server (Frankfurt) ~5ms ek gecikme
- **DB/Cache erişimi:** Pod (Istanbul) → Percona / Redis (EC2, Istanbul Local Zone'da) — Frankfurt'a veri çıkmaz, KVKK uyumlu

> **Not:** Istanbul Local Zone, AWS mimarisinde standart bir Availability Zone gibi davranır — subnet, route table, security group mantığı aynıdır. Fark yalnızca desteklenen servis setindedir. Cross-zone transfer maliyetleri standart AZ'lara kıyasla küçük farklılıklar gösterebilir.

#### NAT Gateway Alternatifi: Açık Kaynak ile Maliyet Düşürme

Istanbul Local Zone'da NAT Gateway yok. Varsayılan yöntem Frankfurt'taki NAT Gateway'i kullanmak — ama bu hem cross-zone veri transfer maliyeti doğurur hem de tüm çıkan trafik Frankfurt'tan geçer.

Daha ucuz ve Türkiye'de kalan alternatifler:

| Çözüm | Açıklama | Maliyet |
|-------|----------|---------|
| [fck-nat](https://github.com/AndrewGuenther/fck-nat) | EC2 tabanlı NAT, Terraform modülü mevcut | ~$4-8/ay (t4g.nano) |

`fck-nat` Terraform ile kurulum:

```hcl
module "nat" {
  source  = "int128/nat-instance/aws"
  version = "~> 2.0"

  name                        = "nat"
  vpc_id                      = module.vpc.vpc_id
  public_subnet               = module.vpc.public_subnets[0]
  private_subnets_cidr_blocks = [local.istanbul_subnet_cidr]
  private_route_table_ids     = [module.vpc.private_route_table_ids[2]] # Istanbul subnet route table
}
```

> Istanbul Local Zone subnet'indeki route table'ı Frankfurt NAT yerine bu instance'a yönlendirdiğinizde trafik Türkiye'de kalır ve cross-zone maliyeti ortadan kalkar.

---

## 2. Gereksinimler ve Hazırlık

### Local Zone Opt-in

Istanbul Local Zone varsayılan olarak kapalı gelir, hesabınızda aktif etmeniz gerekir. İki yöntem var:

**Seçenek 1 — Terragrunt (önerilen):**

Opt-in işlemini altyapı koduna dahil etmek için Terraform'ın `aws_ec2_availability_zone_group` resource'unu kullanabilirsiniz. Böylece bu adım da versiyon kontrolünde olur ve VPC'den önce otomatik uygulanır.

```hcl
# modules/local-zone-optin/main.tf
resource "aws_ec2_availability_zone_group" "istanbul" {
  group_name    = "eu-central-1-ist-1a"
  opt_in_status = "opted-in"
}
```

```hcl
# env/hepapi/eu-central-1/prod/local-zone-optin/terragrunt.hcl
terraform {
  source = "../../../../modules/local-zone-optin"
}

include "root" {
  path = find_in_parent_folders()
}
```

> VPC modülünün `dependency` bloğuna bu modülü ekleyerek sıralamayı garantileyin. Aktifleştirme birkaç dakika sürebilir; Terraform bunu otomatik bekler.

---

**Seçenek 2 — AWS CLI / Console:**

**AWS Console:**
> EC2 → Sol menü → "Zone Groups" → `eu-central-1-ist-1a` → Actions → **Enable**

**AWS CLI:**
```bash
aws ec2 modify-availability-zone-group \
  --group-name eu-central-1-ist-1a \
  --opt-in-status opted-in \
  --region eu-central-1 \
  --profile hepapi-sso
```

Aktifleştirme birkaç dakika alabilir. Kontrol edin:
```bash
aws ec2 describe-availability-zones \
  --all-availability-zones \
  --region eu-central-1 \
  --query 'AvailabilityZones[?ZoneName==`eu-central-1-ist-1a`]' \
  --profile hepapi-sso
```

### Araçlar

```bash
# macOS
brew install terraform terragrunt awscli kubectl helm

# Versiyon kontrol
terraform --version   # >= 1.5.0
terragrunt --version  # >= 0.55.0
aws --version         # >= 2.0.0
```

### S3 Backend ve DynamoDB

Terragrunt remote state için S3 bucket ve DynamoDB tablosu gerekir. İki yöntem var:

**Seçenek 1 — Terragrunt (önerilen):**

`terragrunt.hcl` dosyasındaki `remote_state` bloğuna `bucket` ve `dynamodb_table` tanımlandığında Terragrunt, ilk `terragrunt apply` sırasında bu kaynakları **otomatik olarak oluşturur** — ayrıca bir şey yapmanıza gerek yoktur:

```hcl
# terragrunt.hcl (root)
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "hepapi-local-zone-terragrunt-states"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "hepapi-local-zone-terragrunt-lock-tables"
    profile        = local.profile
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
```

Bucket versioning ve server-side encryption da otomatik aktif edilir.

---

**Seçenek 2 — AWS CLI (manuel):**

```bash
# S3 bucket
aws s3api create-bucket \
  --bucket hepapi-local-zone-terragrunt-states \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1 \
  --profile hepapi-sso

# Versioning aktif et
aws s3api put-bucket-versioning \
  --bucket hepapi-local-zone-terragrunt-states \
  --versioning-configuration Status=Enabled \
  --profile hepapi-sso

# DynamoDB lock table
aws dynamodb create-table \
  --table-name hepapi-local-zone-terragrunt-lock-tables \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1 \
  --profile hepapi-sso
```

### SSO ile Kimlik Doğrulama

AWS SSO kullanıyorsanız kritik bir sorunla karşılaşırsınız: Terraform S3 backend `sso_session` formatını **desteklemez**. Her terminal oturumunda şunu çalıştırın:

```bash
aws sso login --profile hepapi-sso
eval "$(aws configure export-credentials --profile hepapi-sso --format env)"
```

Bu komut `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` ve `AWS_SESSION_TOKEN` ortam değişkenlerini set eder. Terraform bu değişkenleri otomatik okur.

---

## 3. Proje Yapısı

```
.
├── terragrunt.hcl                    # Root config (provider, backend)
├── account.hcl                       # Account ID
└── env/
    └── hepapi/
        └── eu-central-1/
            └── prod/
                ├── env.hcl           # Tüm versiyon ve config değerleri
                ├── vpc/
                │   └── terragrunt.hcl
                └── eks/
                    ├── eks/
                    │   └── terragrunt.hcl
                    ├── node-group/
                    │   └── terragrunt.hcl
                    ├── karpenter/
                    │   ├── karpenter-module/
                    │   ├── karpenter-controller-helm/
                    │   └── karpenter-configs/
                    ├── ebs-csi/
                    ├── alb-controller/
                    │   ├── aws-alb-controller-role/
                    │   └── aws-alb-controller/
                    └── common-security-group/
```

---

## 4. Terragrunt Root Yapılandırması

Kök `terragrunt.hcl` dosyası tüm alt modüller için provider ve backend ayarlarını **otomatik üretir**. Her modülde tekrar tekrar yazmaya gerek kalmaz:

```hcl
# terragrunt.hcl (root)
locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region       = local.env_vars.locals.region
  profile      = "hepapi-sso"
}

generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region  = "${local.region}"
  profile = "${local.profile}"
}
EOF
}

generate "provider_version" {
  path      = "provider_version_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "hepapi-local-zone-terragrunt-states"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "hepapi-local-zone-terragrunt-lock-tables"
    profile        = local.profile
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
```

### Versiyon Uyumluluğu — En Kritik Konu

Bu kurulumda en çok zaman harcadığımız konu provider ve module versiyon uyumluluğuydu. Kısaca:

- **EKS module 20.x** → AWS Provider **v5** gerektirir (v6 ile çalışmaz)
- **VPC module 6.x** → AWS Provider **v6** gerektirir
- Sonuç: VPC module'ü **5.19.0'a** düşürdük, AWS Provider **~> 5.83.0** sabitledik

Tüm versiyon değerleri tek yerden yönetilir:

```hcl
# env/hepapi/eu-central-1/prod/env.hcl
locals {
  module_versions = {
    vpc        = "5.19.0"   # v6 AWS Provider v6 gerektirir, uyumsuz
    eks        = "20.33.1"  # AWS Provider ~> 5.83.0 gerektirir
    node-group = "20.33.1"
  }
  helm_versions = {
    karpenter-chart              = "1.1.2"
    ebs-csi-chart                = "2.40.3"
    efs-csi-chart                = "3.1.5"
    aws-load-balancer-controller = "1.11.0"
  }
}
```

---

## 5. VPC Kurulumu

### Subnet İndeksleme Stratejisi

Local Zone kurulumunun temel tasarım kararı budur. VPC module subnet'leri `azs` listesinin sırasına göre oluşturur ve bu sıra **garanti edilmiştir**:

```
azs = ["eu-central-1a", "eu-central-1b", "eu-central-1-ist-1a"]

private_subnets[0] → 10.20.0.0/19   → eu-central-1a       → EKS control plane
private_subnets[1] → 10.20.64.0/19  → eu-central-1b       → EKS control plane
private_subnets[2] → 10.20.32.0/19  → eu-central-1-ist-1a → Istanbul workers
```

Bu indeks stratejisi sayesinde:
- `slice(subnets, 0, 2)` → Control plane subnets
- `slice(subnets, 2, 3)` → Istanbul worker subnets

```hcl
# env.hcl — VPC konfigürasyonu
vpc = {
  vpc_name        = "hepapi-local-zone"
  cidr            = "10.20.0.0/16"
  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1-ist-1a"]
  private_subnets = ["10.20.0.0/19", "10.20.64.0/19", "10.20.32.0/19"]
  public_subnets  = ["10.20.100.0/24", "10.20.102.0/24", "10.20.101.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true   # Istanbul trafiği Frankfurt NAT üzerinden
  one_nat_gateway_per_az = false
}
```

```hcl
# env/hepapi/eu-central-1/prod/vpc/terragrunt.hcl
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws//?version=${local.env_vars.locals.module_versions.vpc}"
}

inputs = {
  name            = "${local.env_vars.locals.vpc.vpc_name}-vpc"
  cidr            = local.env_vars.locals.vpc.cidr
  azs             = local.env_vars.locals.vpc.azs
  private_subnets = local.env_vars.locals.vpc.private_subnets
  public_subnets  = local.env_vars.locals.vpc.public_subnets

  # Local Zone'da database subnet group desteklenmiyor
  create_database_subnet_group       = false
  create_database_subnet_route_table = false

  enable_nat_gateway     = local.env_vars.locals.vpc.enable_nat_gateway
  single_nat_gateway     = local.env_vars.locals.vpc.single_nat_gateway
  one_nat_gateway_per_az = local.env_vars.locals.vpc.one_nat_gateway_per_az

  enable_dns_hostnames = true
  enable_dns_support   = true

  # ALB discovery için public subnet tag'i
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                           = 1
    "kubernetes.io/cluster/${local.env_vars.locals.eks.cluster_name}" = "shared"
  }
  # Karpenter subnet discovery için private subnet tag'leri
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                  = 1
    "kubernetes.io/cluster/${local.env_vars.locals.eks.cluster_name}"  = "shared"
    "karpenter.sh/discovery/${local.env_vars.locals.eks.cluster_name}" = "${local.env_vars.locals.eks.cluster_name}"
  }
}
```

> **NAT Gateway Notu:** `single_nat_gateway = true` ile NAT Gateway yalnızca `eu-central-1a`'da oluşturulur. Istanbul pod'larının internet trafiği Frankfurt NAT üzerinden geçer. Bu cross-zone data transfer ücreti doğurur (~$0.02/GB). Yüksek egress trafiğiniz varsa bunu maliyet planlamasına ekleyin.

---

## 6. EKS Cluster Kurulumu

### Control Plane Kısıtlaması

EKS control plane Local Zone subnet'lerini **kabul etmez** ve minimum 2 farklı standart AZ gerektirir. `slice()` ile ilk iki subnet seçilir:

```hcl
# env/hepapi/eu-central-1/prod/eks/eks/terragrunt.hcl
terraform {
  source = "tfr:///terraform-aws-modules/eks/aws//?version=${local.env_vars.locals.module_versions.eks}"

  # apply sonrası kubeconfig otomatik güncellenir
  after_hook "after_hook" {
    commands = ["apply"]
    execute  = [
      "aws", "eks", "update-kubeconfig",
      "--region",  "${include.root.locals.region}",
      "--name",    "${local.env_vars.locals.eks.cluster_name}",
      "--profile", "${local.env_vars.locals.aws_profile}"
    ]
  }
}

inputs = {
  cluster_name    = local.env_vars.locals.eks.cluster_name
  cluster_version = "1.35"
  vpc_id          = dependency.vpc.outputs.vpc_id

  # KRITIK: Local Zone control plane'de çalışmaz
  # Sadece index 0 (eu-central-1a) ve 1 (eu-central-1b)
  subnet_ids = slice(dependency.vpc.outputs.private_subnets, 0, 2)

  authentication_mode             = "API"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_service_ipv4_cidr       = "10.240.0.0/16"
  enable_irsa                     = true

  cluster_addons = {
    coredns = {
      addon_version = "v1.13.2-eksbuild.3"
    }
    eks-pod-identity-agent = {}
    vpc-cni = {
      addon_version = "v1.21.1-eksbuild.1"
      configuration_values = jsonencode({
        env = {
          # Prefix delegation: node başına daha fazla pod IP'si
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  # Karpenter node discovery için security group tag'i
  node_security_group_tags = {
    "karpenter.sh/discovery/${local.env_vars.locals.eks.cluster_name}" = local.env_vars.locals.eks.cluster_name
  }
}
```

### SSO ile EKS Erişimi

EKS access entry için **IAM user ARN değil, SSO permission set role ARN** kullanın. Bu yaklaşımla o permission set'e sahip tüm kullanıcılar tek tanımla admin yetkisi alır — her kullanıcı için ayrı access entry yazmaya gerek kalmaz.

SSO role ARN'ını bulun:
```bash
aws iam list-roles --profile hepapi-sso \
  --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].{Name:RoleName,Arn:Arn}' \
  --output table
```

```hcl
# env.hcl — access_entries
access_entries = {
  hepapi = {
    # Tüm SSO AdministratorAccess kullanıcıları bu role ile gelir
    principal_arn = "arn:aws:iam::xxxxxxxxxxxx:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_xxxxxxxxxxxxxxxx"
    policy_associations = {
      policy = {
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }
    }
  }
}
```

---

## 7. Istanbul Worker Node Group

Node group yalnızca `private_subnets[2]` (Istanbul) subnet'ine kurulur:

```hcl
# env/hepapi/eu-central-1/prod/eks/node-group/terragrunt.hcl
inputs = {
  name            = "hepapi-istanbul-node-group"
  cluster_name    = dependency.eks.outputs.cluster_name
  cluster_version = dependency.eks.outputs.cluster_version

  # Sadece Istanbul Local Zone subnet (index 2)
  subnet_ids = slice(dependency.vpc.outputs.private_subnets, 2, 3)

  instance_types = ["m7i.xlarge"]
  capacity_type  = "ON_DEMAND"  # Local Zone'da Spot desteklenmez
  min_size       = 1
  max_size       = 2
  desired_size   = 1

  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size = 80
        volume_type = "gp3"
      }
    }
  }

  # SSM ile SSH yerine güvenli node erişimi
  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Workload scheduling için node label'ları
  # Bu label'lar Deployment nodeSelector'da kullanılır
  labels = {
    topology = "local-zone"
    zone     = "istanbul"
  }
}
```

Node'un Istanbul'da çalıştığını doğrulayın:
```bash
kubectl get nodes -o custom-columns='NAME:.metadata.name,ZONE:.metadata.labels.topology\.kubernetes\.io/zone'
```

---

## 8. Karpenter ile Dinamik Scaling

Static node group yetmediğinde Karpenter devreye girer. Istanbul için özel yapılandırma gerektiriyor — yanlış yapılandırılırsa Karpenter Frankfurt'ta node açar, Istanbul'da değil.

### Karpenter IAM Modülü

```hcl
# env/hepapi/eu-central-1/prod/eks/karpenter/karpenter-module/terragrunt.hcl
terraform {
  source = "tfr:///terraform-aws-modules/eks/aws//modules/karpenter//?version=20.33.1"
}

inputs = {
  cluster_name                    = dependency.eks.outputs.cluster_name
  enable_v1_permissions           = true
  enable_irsa                     = true
  enable_pod_identity             = true
  create_pod_identity_association = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}
```

### Karpenter Helm Chart

```hcl
# env/hepapi/eu-central-1/prod/eks/karpenter/karpenter-controller-helm/terragrunt.hcl
inputs = {
  name          = "karpenter"
  namespace     = "kube-system"
  chart_version = "1.1.2"
  helm_repo_url = "oci://public.ecr.aws/karpenter"

  sets = [
    { name  = "serviceAccount.name",
      value = dependency.karpenter-module.outputs.service_account },
    { name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn",
      value = dependency.karpenter-module.outputs.iam_role_arn },
    { name  = "settings.interruptionQueue",
      value = dependency.karpenter-module.outputs.queue_name },
    { name  = "settings.clusterName",
      value = dependency.eks.outputs.cluster_name },
    { name  = "settings.clusterEndpoint",
      value = dependency.eks.outputs.cluster_endpoint },
    { name  = "replicas", value = "1" }
  ]
}
```

### NodePool — Istanbul'a Özgü Yapılandırma

Bu NodePool tanımında **iki kritik requirement** var:

1. `topology.kubernetes.io/zone: eu-central-1-ist-1a` → Sadece Istanbul'da node aç
2. `instance-generation Gt 6` → Sadece 7. nesil seç (c7i/m7i/r7i) — 6. nesil desteklenmiyor

```hcl
# modules/karpenter/karpenter_node_pool.tf
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: hepapi-istanbul
      labels:
        capacity-type: on-demand
    spec:
      template:
        metadata:
          labels:
            capacity-type: on-demand
            topology: local-zone
            zone: istanbul
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["6"]           # 7. nesil ve üzeri: c7i, m7i, r7i
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand"]   # Spot yok!
            - key: "topology.kubernetes.io/zone"
              operator: In
              values: ["eu-central-1-ist-1a"]  # Sadece Istanbul
      limits:
        cpu: 50
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 60s
  YAML
}
```

Karpenter'ın doğru çalıştığını doğrulayın:
```bash
# Karpenter pod'u çalışıyor mu?
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter

# NodePool durumu
kubectl get nodepool hepapi-istanbul

# Karpenter tarafından açılan node'lar
kubectl get nodes -l karpenter.sh/nodepool=hepapi-istanbul
```

Pod'ları Istanbul node'larına yönlendirmek için `nodeSelector` ekleyin:
```yaml
spec:
  nodeSelector:
    topology: local-zone
    zone: istanbul
```

---

## 9. EBS CSI Driver — Zone-Aware Storage

Local Zone'da storage kurulumunda yapılan en yaygın hata: StorageClass'a hardcoded zone topology eklemek.

**Yanlış yaklaşım:**
```yaml
# BUNU YAPMAYIN — pod başka node'a taşınırsa volume erişilemez
volumeBindingMode: Immediate
allowedTopologies:
  - matchLabelExpressions:
    - key: topology.kubernetes.io/zone
      values: ["eu-central-1-ist-1a"]
```

**Doğru yaklaşım:** `WaitForFirstConsumer` — volume, pod'un schedule edildiği node'un zone'unda oluşturulur. Zone değişirse volume de değişir.

```hcl
# modules/ebs-csi/main.tf
resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver/"
  chart      = "aws-ebs-csi-driver"
  version    = var.chart_version

  set = [
    { name  = "controller.serviceAccount.create", value = "true" },
    { name  = "controller.serviceAccount.name",   value = "ebs-csi-controller-sa" },
    { name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn",
      value = var.ebs_csi_role_arn },
  ]
}

resource "kubectl_manifest" "storageclass" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: ${var.storageclassname}
    provisioner: ebs.csi.aws.com
    parameters:
      tagSpecification_1: "Name={{ .PVCNamespace }}-{{ .PVCName }}"
      tagSpecification_2: "Namespace={{ .PVCNamespace }}"
    allowVolumeExpansion: true
    volumeBindingMode: WaitForFirstConsumer  # Pod'u takip et, zone hardcode etme
  YAML
}
```

---

## 10. AWS Load Balancer Controller

ALB, Local Zone'da **oluşturulamaz**. ALB Frankfurt'ta kurulur, `target-type: ip` modunda Istanbul pod IP'lerine yönlenir.

### IAM IRSA Role

```hcl
# modules/aws-alb-controller-role/main.tf
module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52.0"  # v6 dizin yapısını değiştirdi, pinlemek şart

  role_name                              = "eks-lb-controller-${var.cluster_name}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account" "service-account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}
```

### Helm Chart

```hcl
# env/hepapi/eu-central-1/prod/eks/alb-controller/aws-alb-controller/terragrunt.hcl
inputs = {
  name          = "aws-load-balancer-controller"
  namespace     = "kube-system"
  chart_version = "1.11.0"
  helm_repo_url = "https://aws.github.io/eks-charts"

  sets = [
    { name = "serviceAccount.create", value = "false" },
    { name = "serviceAccount.name",   value = "aws-load-balancer-controller" },
    { name = "clusterName",           value = dependency.eks.outputs.cluster_name },
    { name = "vpcId",                 value = dependency.vpc.outputs.vpc_id },
    # eu-central-1 ECR mirror (us-east-1 değil!)
    { name = "image.repository",
      value = "602401143452.dkr.ecr.eu-central-1.amazonaws.com/amazon/aws-load-balancer-controller" }
  ]
}
```

### Ingress Örneği — Local Zone İçin Annotation'lar

ALB'yi Istanbul Local Zone'da oluşturmak için tek yapmanız gereken `alb.ingress.kubernetes.io/subnets` annotation'ına Local Zone subnet adını vermek. AWS Load Balancer Controller bu subnet'i okuyarak ALB'yi doğrudan Istanbul'da açar.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing

    # ZORUNLU: pod IP'lerine doğrudan yönlendirme için IP modunu kullan
    alb.ingress.kubernetes.io/target-type: ip

    # ALB'yi Istanbul Local Zone subnet'inde oluştur
    alb.ingress.kubernetes.io/subnets: eu-central-1-ist-1a

    alb.ingress.kubernetes.io/healthcheck-path: /health
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

Public subnet ID'lerini bulmak için:
```bash
aws ec2 describe-subnets \
  --filters "Name=tag:kubernetes.io/role/elb,Values=1" \
            "Name=availabilityZone,Values=eu-central-1a,eu-central-1b" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone]' \
  --output table \
  --profile hepapi-sso
```

---

## 11. Karşılaşılan Sorunlar ve Çözümleri

Bu kurulum boyunca karşılaştığımız tüm hatalar ve çözümleri:

### 1. EKS Control Plane Subnet Hatası

```
Error: at least 2 subnets in different availability zones required
```

**Neden:** Yalnızca `eu-central-1-ist-1a` subnet'i verilmişti. Control plane Local Zone subnet'i kabul etmez ve minimum 2 standart AZ gerektirir.

**Çözüm:**
```hcl
# Sadece eu-central-1a ve eu-central-1b (index 0 ve 1)
subnet_ids = slice(dependency.vpc.outputs.private_subnets, 0, 2)
```

---

### 2. VPC Module `region` Unsupported Argument

```
Error: An argument named "region" is not expected here.
```

**Neden:** VPC module 6.x, AWS Provider v6'ya özgü argüman ekledi. EKS module 20.x, Provider v5 gerektiriyor.

**Çözüm:** VPC module'ü 5.19.0'a downgrade et.

---

### 3. SSO Backend Uyumsuzluğu

```
Error: error configuring S3 Backend: no valid credential sources found
```

**Neden:** Terraform S3 backend `sso_session` formatını desteklemiyor.

**Çözüm:**
```bash
eval "$(aws configure export-credentials --profile hepapi-sso --format env)"
```

---

### 4. Helm Provider v3 Breaking Change

```
Error: Unsupported block type - "kubernetes"
```

**Neden:** Helm provider v3, `kubernetes {}` blok syntax'ını kaldırdı.

**Çözüm — tüm provider.tf dosyalarında:**
```hcl
# ÖNCE (v2)
provider "helm" {
  kubernetes {
    host = var.kube_host
    exec {
      command = "aws"
    }
  }
}

# SONRA (v3)
provider "helm" {
  kubernetes = {
    host = var.kube_host
    exec = {
      command = "aws"
    }
  }
}
```

`set {}` blokları da değişti:
```hcl
# ÖNCE (v2)
dynamic "set" {
  for_each = var.sets
  content {
    name  = set.value.name
    value = set.value.value
  }
}

# SONRA (v3)
set = var.sets
```

---

### 5. IAM Module "Unreadable Directory" Hatası

```
Error: Unreadable module directory — no Terraform files found in
.terraform/modules/lb_role/modules/iam-role-for-service-accounts-eks
```

**Neden:** IAM module v6, iç dizin yapısını değiştirdi. Versiyon pinlenmemişti ve v6 indirildi.

**Çözüm:**
```hcl
source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
version = "~> 5.52.0"  # v6'ya geçmesin
```

---

### 6. Karpenter Replicas=0

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
# No resources found
```

**Neden:** Helm values'ta `replicas: 0` olarak set edilmişti.

**Çözüm:** `env.hcl`'de `replicas = "1"` yap.

---

### 7. EKS Access Entry Invalid Principal

```
Error: InvalidParameterException: principalArn is not valid
```

**Neden:** Mevcut olmayan bir IAM user ARN (`arn:aws:iam::ACCOUNT:user/username`) verilmişti.

**Çözüm:** SSO role ARN kullan (user ARN değil):
```bash
aws iam list-roles --profile hepapi-sso \
  --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].Arn'
```

---

## 12. Maliyet Analizi

Local Zone kullanımı standart bölgelere göre bazı maliyet farklılıkları içerir:

### EC2 Instance Maliyeti

Local Zone instance'ları standart AZ fiyatının yaklaşık **%10-20 üzerinde** fiyatlanır:

| Instance | Frankfurt (On-Demand) | Istanbul Local Zone (yaklaşık) |
|----------|----------------------|-------------------------------|
| m7i.xlarge | ~$0.202/saat | ~$0.22-0.24/saat |
| c7i.xlarge | ~$0.170/saat | ~$0.19-0.21/saat |
| r7i.xlarge | ~$0.252/saat | ~$0.27-0.30/saat |

> Güncel fiyatlar için AWS Pricing sayfasını kontrol edin, Local Zone fiyatları düzenli güncellenir.

### Spot Instance Yok

Standart AZ'larda Spot ile %60-70 tasarruf mümkünken, Local Zone'da bu seçenek **yoktur**. Karpenter ve node group konfigürasyonunda `ON_DEMAND` zorunludur. Bu maliyet planlamasında kritik bir faktör.

### Cross-Zone Data Transfer

İki ek cross-zone ücret kategorisi var:

| Transfer Yönü | Ücret |
|--------------|-------|
| Istanbul Pod → Frankfurt NAT (internet çıkışı) | ~$0.02/GB |
| Frankfurt ALB → Istanbul Pod | ~$0.01/GB |

Yüksek egress trafiğiniz varsa (video streaming, büyük dosya indirme) bu rakamlar önemli olabilir.

### Genel Değerlendirme

Local Zone maliyeti standart bölgeye göre %20-30 daha yüksek çıkabilir. Ancak elde edilen gecikme avantajı (~5-8ms vs ~35-40ms) latency-sensitive uygulamalar için bu maliyeti fazlasıyla karşılar.

---

## 13. Best Practices Özeti

**Mimari**
- Control plane için asla Local Zone subnet kullanma — 2 standart AZ şart
- Subnet'leri isim değil index ile ayır — VPC module sıra garantisi verir
- Istanbul node'larını label ile işaretle (`topology: local-zone`, `zone: istanbul`)
- ALB'yi Frankfurt public subnet'lerine kur, `target-type: ip` ile pod'lara yönlendir

**Karpenter**
- `topology.kubernetes.io/zone: eu-central-1-ist-1a` olmadan NodePool tüm zone'lara node açar
- `instance-generation Gt 6` ile sadece c7i/m7i/r7i hedefle — 6. nesil Istanbul'da yok
- `capacity-type: on-demand` zorunlu, Spot kullanılamaz

**Storage**
- EBS StorageClass'ta `volumeBindingMode: WaitForFirstConsumer` kullan
- Hardcoded zone topology pod migration'da volume kaybına yol açar

**Versiyon Yönetimi**
- Tüm module ve helm versiyonlarını `env.hcl`'de merkezi tut
- Provider versiyonlarını `~>` ile minor seviyede sabitle
- Module yükseltmeden önce provider uyumluluğunu mutlaka test et

**Maliyet**
- Yüksek egress trafiği varsa cross-zone transfer ücretlerini hesapla
- Spot kullanamayacağını baştan maliyet modeline yansıt
- Local Zone fiyat farkını (~%15-20) rezervasyon veya savings plan ile azaltabilirsin

---

## Sonuç

Istanbul Local Zone, Türkiye kullanıcılarına hitap eden uygulamalar için gerçek bir gecikme avantajı sunar. Frankfurt'tan ~35-40ms olan RTT, Istanbul Local Zone ile ~2-8ms'ye düşüyor — bu 5-6 kat bir iyileşme.

Kurulum standart EKS'ten daha karmaşık: control plane Local Zone'da çalışmıyor, Spot yok, NAT Gateway yok. ALB ise `alb.ingress.kubernetes.io/subnets: eu-central-1-ist-1a` annotation'ı ile doğrudan Istanbul'da oluşturulabiliyor. Bu kısıtlamaları anlayarak tasarladığınız subnet stratejisi ve Karpenter konfigürasyonu ile production-grade bir cluster kurabilirsiniz.

**Kurulum sırası:**
```
VPC → EKS → Node Group → Karpenter → EBS CSI → ALB Controller
```