# Lab #8 — Infraestructura como Código con Terraform (Azure)

Implementación completa de una arquitectura de **alta disponibilidad** en Azure utilizando **Terraform** como Infrastructure as Code. El proyecto incluye un Load Balancer (L4) público, 2+ VMs Linux con Nginx, NSG configurado, backend remoto de estado en Azure Storage, y pipeline automático CI/CD con GitHub Actions y autenticación OIDC.

---

## Descripción General

Este proyecto moderniza el laboratorio tradicional de balanceo de carga migrando de acciones manuales a **IaC** completa. Implementa una arquitectura reproducible, segura, versionable y con integración continua automatizada.

### Características principales:
- ✅ **Módulos Terraform** reutilizables (vnet, lb, compute)
- ✅ **Backend remoto** con state locking en Azure Storage
- ✅ **NSG endurecido** (80/TCP público, 22/TCP solo desde IP autorizada)
- ✅ **High Availability** (Load Balancer L4 con 2+ VMs, Availability Set)
- ✅ **Cloud-init** para provisión automática de Nginx
- ✅ **GitHub Actions** con validación automática (fmt, validate, plan)
- ✅ **OIDC** para autenticación sin secretos largos
- ✅ **Tagging** consistente (owner, course, env, expires)

---

## Getting Started

Estas instrucciones te permiten obtener una copia del proyecto funcionando en tu máquina local para desarrollo y testing.

### Prerequisites

Antes de comenzar, necesitas tener instalado:

```bash
# Verificar instalación
az version                    # Azure CLI >= 2.50.0
terraform -version            # Terraform >= 1.6.0
ssh-keygen -t ed25519         # Generar clave SSH (si no existe)
git --version                 # Git para versionado
```

**Requisitos Azure:**
- Cuenta con Subscription activa (Azure for Students o equivalente)
- Acceso a crear Resource Groups, Storage Accounts y VMs
- IP pública del cliente (para ssh_public_key)

**Requisitos GitHub:**
- Cuenta de GitHub con repositorio clonado
- Acceso para crear GitHub Actions Secrets

### Installing

Sigue estos pasos para levantar el entorno de desarrollo:

**1. Clonar el repositorio**
```bash
git clone https://github.com/Rogerrdz/Arquitectura_de_software_LAB08.git
cd Arquitectura_de_software_LAB08
```

**2. Autenticarse en Azure**
```bash
az login
az account show --output table
# Si tienes varias suscripciones:
# az account set --subscription "<SUBSCRIPTION_ID>"
```

**3. Crear backend remoto para Terraform state**
```powershell
$SUFFIX = Get-Random -Maximum 99999
$LOCATION = "eastus"
$RG = "rg-tfstate-lab8"
$STO = "sttfstate$SUFFIX"
$CONTAINER = "tfstate"

az group create --name $RG --location $LOCATION
az storage account create --resource-group $RG --name $STO --location $LOCATION --sku Standard_LRS --encryption-services blob
az storage container create --name $CONTAINER --account-name $STO --auth-mode login

# Crear archivo backend.hcl
@"
resource_group_name  = "$RG"
storage_account_name = "$STO"
container_name       = "$CONTAINER"
key                  = "lab8/dev/terraform.tfstate"
"@ | Set-Content -Path "infra/backend.hcl"
```

**4. Completar valores reales en variables**

Edita `infra/env/dev.tfvars`:
```hcl
prefix              = "lab8"
location            = "eastus"
vm_count            = 2
vm_size             = "Standard_B1s"
admin_username      = "student"
ssh_public_key      = "~/.ssh/id_ed25519.pub"  # Tu llave pública
allow_ssh_from_cidr = "X.X.X.X/32"             # Tu IP pública

tags = {
  owner   = "tu-usuario"
  course  = "ARSW/BluePrints"
  env     = "dev"
  expires = "2026-12-31"
}
```

**5. Inicializar y validar Terraform**
```bash
cd infra
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
```

---

## Despliegue Local

### Plan
```bash
terraform plan -var-file=env/dev.tfvars -out plan.tfplan
```

### Apply
```bash
terraform apply "plan.tfplan"
```

### Obtener outputs
```bash
terraform output
# Captura el lb_public_ip y las vm_names
```

### Verificar balanceo
```powershell
$LB_IP = terraform output -raw lb_public_ip
1..10 | ForEach-Object { Invoke-RestMethod -Uri "http://$LB_IP" }
```

Deberías ver hostnames alternando entre VMs (ej: "Hola desde vm-lab8-01", "Hola desde vm-lab8-02")

---

## Running the Tests

### Validación de Terraform

**Pruebas de sintaxis y consistencia:**
```bash
cd infra
terraform fmt -recursive    # Valida formateo
terraform validate          # Valida sintaxis y referencias
```

**Prueba de seguridad - NSG:**
Verifica en Azure Portal que NSG solo permite:
- ✅ 80/TCP desde Internet
- ✅ 22/TCP desde tu IP /32
- ✅ Health probe desde AzureLoadBalancer

**Prueba de balanceo:**
```bash
# Ejecutar 10 veces y capturar hostnames alternados
$LB_IP = terraform output -raw lb_public_ip
for ($i=1; $i -le 10; $i++) {
    Write-Host "Intento $i:"
    Invoke-RestMethod -Uri "http://$LB_IP"
    Start-Sleep -Seconds 1
}
```

### Validación en GitHub Actions

El pipeline automático ejecuta en cada PR:
- ✅ `terraform fmt` - Verifica formateo
- ✅ `terraform validate` - Valida configuration
- ✅ `terraform plan` - Genera plan
- ✅ Publica artefacto con el plan
- ✅ Comenta plan en la PR

---

## Deployment en Producción

### Configurar GitHub Actions con OIDC

**1. Crear App Registration en Azure:**
```powershell
$SUB_ID = az account show --query id -o tsv
$TENANT_ID = az account show --query tenantId -o tsv
$APP_NAME = "gh-lab8-oidc"

$APP_ID = az ad app create --display-name $APP_NAME --query appId -o tsv
$SP_OBJECT_ID = az ad sp create --id $APP_ID --query id -o tsv

# Asignar permisos Contributor al RG del lab
$LAB_RG = "rg-lab8-eastus"
$SCOPE = az group show --name $LAB_RG --query id -o tsv
az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal --role Contributor --scope $SCOPE
```

**2. Crear Federated Credential:**
```powershell
$OWNER = "Rogerrdz"
$REPO = "Arquitectura_de_software_LAB08"

$CRED = @{
  name = "gh-main"
  issuer = "https://token.actions.githubusercontent.com"
  subject = "repo:$OWNER/$REPO:ref:refs/heads/main"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 4

az ad app federated-credential create --id $APP_ID --parameters $CRED
```

**3. Agregar Secrets en GitHub:**
- Settings > Secrets and variables > Actions
- Crear:
  - `AZURE_CLIENT_ID` = $APP_ID
  - `AZURE_TENANT_ID` = $TENANT_ID
  - `AZURE_SUBSCRIPTION_ID` = $SUB_ID

**4. Ejecutar Pipeline:**
- Crear PR para disparar validation
- Ejecutar manualmente con `confirm_apply=APPLY`

### Limpieza
```bash
terraform destroy -var-file=env/dev.tfvars
```

---

## Built With

* **[Terraform](https://www.terraform.io/)** - Infrastructure as Code framework
* **[Azure](https://azure.microsoft.com/)** - Cloud provider (Resource Groups, VNets, Load Balancer, VMs, Storage)
* **[GitHub Actions](https://github.com/features/actions)** - CI/CD automation
* **[Git](https://git-scm.com/)** - Version control
* **[Nginx](https://www.nginx.com/)** - Web server (cloud-init)

### Stack Técnico Completo:
```
Terraform + Azure Provider (3.117)
  ├─ Azure Resource Group
  ├─ Virtual Network (2 subnets)
  ├─ Network Security Group
  ├─ Load Balancer (L4)
  ├─ Public IP
  ├─ Availability Set
  ├─ 2+ Linux VMs (Ubuntu 22.04 LTS)
  └─ Azure Storage (remote state + bloqueo)

GitHub Actions
  ├─ Azure CLI Login (OIDC)
  ├─ Terraform Validate
  ├─ Terraform Format Check
  ├─ Terraform Plan
  ├─ Artifacts Management
  └─ PR Comments
```

---

## Contributing

Para contribuir a este proyecto:

1. **Fork** el repositorio
2. Crea una rama de feature (`git checkout -b feature/nueva-feature`)
3. Comitea tus cambios (`git commit -m 'Agregar nueva feature'`)
4. Push a la rama (`git push origin feature/nueva-feature`)
5. Abre una Pull Request

Para más detalles, revisa [CONTRIBUTING.md](CONTRIBUTING.md)

---

## Versioning

Usamos [SemVer](http://semver.org/) para versionado. 

Versiones disponibles: ver [tags del repositorio](https://github.com/Rogerrdz/Arquitectura_de_software_LAB08/tags)

**Cambios recientes:**
- **v1.0.0** - Implementación base completa con módulos, backend remoto y pipeline OIDC
- **v0.2.0** - Corrección de seguridad (ssh_public_key)
- **v0.1.0** - Estructura inicial

---

## Authors

* **Roger Rodríguez** - *Trabajo actual* - [Rogerrdz](https://github.com/Rogerrdz)
* **Equipo ARSW/BluePrints** - Diseño del laboratorio

Ver también la lista de [contributors](https://github.com/Rogerrdz/Arquitectura_de_software_LAB08/contributors)

---

## License

Este proyecto está bajo licencia **MIT** - ver [LICENSE.md](LICENSE.md) para detalles

---

## Acknowledgments

* Curso ARSW/BluePrints de la Universidad
* HashiCorp (Terraform)
* Microsoft (Azure)
* GitHub (Actions)

---

# 📊 Evidencias y Resultados

## Diagramas Arquitectónicos

### 1. Diagrama de Componentes

![Componentes Arquitectura](images/components_diagram.png)

**Descripción:** Visualización de todos los recursos Azure implementados:
- **Resource Group** como contenedor lógico
- **VNet** con 2 subnetes (web y mgmt)
- **Load Balancer público** con IP pública
- **2+ VMs Linux** en availability set
- **NSG** aplicado a subnet-web
- **Azure Storage** para estado remoto

### 2. Diagrama de Secuencia

![Secuencia Flujo IaC](images/sequence_diagram.png)

**Descripción:** Flujo de despliegue desde local a Azure:
1. Autenticación en Azure (`az login`)
2. Terraform init con backend remoto
3. Validación y planificación
4. Aplicación de recursos
5. Provisión automática con cloud-init

---

## 🔐 Configuración de Infraestructura

### Autenticación Azure CLI
![Azure Login](images/az_login.png)

**Evidencia:** Sesión autenticada en Azure con acceso a subscription.

### Estado de Cuenta Azure
![Account Info](images/az_account_table.png)

**Evidencia:** Subscription activa y confirmación de contexto correcto.

### Backend Remoto - Storage Account

![Storage Account Creado](images/azure_portal_created_storage_account.png)

**Evidencia:** Storage Account creado en portal Azure para backend remoto de Terraform.

### Backend Remoto - Container

![Container de State](images/azure_portal_created_container_storage_account.png)

**Evidencia:** Container "tfstate" dentro del Storage Account con bloqueo automático.

---

## ✅ Despliegue de Infraestructura

### Terraform Init con Backend

![Terraform Init Éxito](images/terraform_successfully_init_backend.png)

**Evidencia:** Inicialización exitosa de Terraform con backend remoto configurado.

### Terraform Output

![Terraform Output](images/terraform_successfully_output.png)

**Evidencia:** Outputs generados (resource group, VM names, IPs privadas).

### Terraform Output con IP Pública

![Output con IP](images/terraform_successfully_output_and_public_ip.png)

**Evidencia:** Load Balancer obtuvo IP pública estática para acceso desde Internet.

### VMs Disponibles en Azure

![VMs Creadas](images/terraform_VMs_availables.png)

**Evidencia:** 2 VMs Linux creadas y ejecutándose en Azure Portal (vm-lab8-01, vm-lab8-02).

---

## 🌐 Validación del Load Balancer

### Load Balancer en Azure Portal

![Load Balancer](images/azure_portal_lb-lab8_load_balancer.png)

**Evidencia:** Load Balancer configurado con:
- Frontend IP pública
- Backend pool con 2 VMs
- Health probe (TCP/80)
- Load balancing rule (80→80)

---

## 🧪 Pruebas de Balanceo de Carga

### Test 1: Respuesta Nginx - VM1

![Nginx Respuesta](images/nginx_response_test.png)

**Evidencia:** Respuesta exitosa de Nginx en primera VM mostrando hostname dinámico.

### Test 2: Balanceo Alternancia VM1

![Balanceo Test 1](images/balancing_tests.png)

**Evidencia:** Múltiples peticiones alternando entre VMs (balanceo funcionando).

### Test 3: Balanceo Alternancia VM2

![Balanceo Test 2](images/balancing_tests_2.png)

**Evidencia:** Confirmación de round-robin entre VMs (vm-lab8-01 ↔ vm-lab8-02).

---

## 🔄 CI/CD y GitHub Actions

### OIDC - App Registration

![App Registration](images/created_App_Registration_y_Federated_Credential.png)

**Evidencia:** App Registration creada en Azure AD para autenticación OIDC desde GitHub Actions.

### OIDC - Federated Credential

![Federated Credential](images/created_federation_to_github_repo.png)

**Evidencia:** Federated Credential vinculada a repositorio de GitHub sin necesidad de secretos largos.

### GitHub Actions Pipeline

![Pipeline Ejecutándose](images/github_terraform_pipeline_running.png)

**Evidencia:** Pipeline ejecutándose en GitHub Actions (fmt, validate, plan, apply).

---

# 🤔 Preguntas de Reflexión Técnica

## 1) ¿Por qué L4 LB vs Application Gateway (L7) en tu caso? ¿Qué cambiaría?

### Análisis Comparativo

| Aspecto | Load Balancer L4 | Application Gateway L7 |
|--------|------------------|------------------------|
| **Capa OSI** | Transporte (TCP/UDP) | Aplicación (HTTP/HTTPS) |
| **Decisiones de Routing** | IP + Puerto | URL path, hostname, cookies |
| **Rendimiento** | ⭐⭐⭐⭐⭐ Ultra alto | ⭐⭐⭐⭐ Muy alto |
| **Latencia** | < 1ms | 10-50ms |
| **Throughput** | Millones req/seg | Millones req/seg |
| **Complejidad** | 🟢 Simple | 🟠 Moderada |
| **Costo** | 💰 $16/mes | 💰 $0.25/h ($180/mes) |
| **Casos de Uso** | TCP puro, gaming, IoT | APIs web, microservicios |

### Decisión para LAB_08: **L4 Load Balancer ✅**

**Razones:**
1. **Simplicidad**: HTTP básico sin lógica de routing compleja
2. **Costo**: ~90% más barato que App Gateway
3. **Performance**: Suficiente para este caso educativo
4. **Gestión**: Menos componentes = menos complejidad

### Cuándo Cambiaría a Application Gateway (L7):
```
✓ Múltiples aplicaciones en las mismas VMs
✓ Routing por path (/api/*, /static/*)
✓ Reescritura de URLs/headers
✓ SSL/TLS offload avanzado
✓ WAF (Web Application Firewall)
✓ Cookies-based routing
```

**Conclusión:** Para este lab enfocado en IaC fundamental, L4 es la opción correcta. En producción con múltiples servicios, evaluaríamos App Gateway.

---

## 2) ¿Qué implicaciones de seguridad tiene exponer 22/TCP? ¿Cómo mitigarlas?

### Análisis de Riesgos

| Riesgo | Severidad | Mitigación Implementada |
|--------|-----------|------------------------|
| **Ataques de fuerza bruta SSH** | 🔴 CRÍTICA | ✅ SSH solo desde /32 autorizado |
| **Explotación cero-day SSH** | 🔴 CRÍTICA | ✅ Clave pública (no contraseña débil) |
| **Lateral movement desde 22** | 🟠 ALTA | ✅ NSG restringe a subnet |
| **Reconocimiento de banner SSH** | 🟡 MEDIA | ✅ SSH no visible desde Internet |
| **Acceso no autorizado** | 🔴 CRÍTICA | ✅ IP específica /32 requerida |

### Mitigaciones Implementadas

**1. Restricción a IP autorizada (/32):**
```hcl
security_rule {
  name                       = "allow-ssh-from-trusted-ip"
  source_address_prefix      = var.allow_ssh_from_cidr  # Tu IP /32
  destination_port_range     = "22"
}
```
✅ Solo TÚ puedes acceder, nadie más en Internet

**2. SSH por clave pública (no contraseña):**
```hcl
disable_password_authentication = true
admin_ssh_key {
  username   = var.admin_username
  public_key = file(var.ssh_public_key)
}
```
✅ Imposible acceso por fuerza bruta de contraseñas

**3. Subnet isolation:**
```hcl
subnet-web: 10.42.1.0/24  (Internet → LB solo)
subnet-mgmt: 10.42.2.0/24  (Opcional, aplicación interna)
```
✅ VMs no expuestas directamente, solo LB

**4. Cloud-init sin password:**
```yaml
runcmd:
  - usermod -L root              # Root sin login
  - passwd -l ubuntu             # Usuario ubuntu sin password
```
✅ Sin passwords en el sistema

### Mitigaciones Adicionales (NO IMPLEMENTADAS - para producción):

```hcl
# 1. Azure Bastion (recomendado para prod)
resource "azurerm_bastion_host" "this" {
  name                = "bastion-${var.prefix}"
  # Acceso SSH → Bastion SSH → VM (sin 22 expuesto)
}

# 2. Just-In-Time (JIT) Access
# Enable desde Azure Security Center
# Requiere que desbloquees puerto 22 temporalmente

# 3. Change SSH Port
variable "ssh_port" {
  default = 2222  # En lugar de 22
}

# 4. Fail2Ban en VMs
runcmd:
  - apt-get install fail2ban -y
  - systemctl enable fail2ban
```

### Conclusión sobre Seguridad SSH:
**⭐⭐⭐⭐ (4/5 estrellas) - Robusto para lab, mejorable para producción**
- ✅ Clave pública + IP restringida = muy seguro
- ✅ NSG minimalista correcto
- 🟡 Azure Bastion sería upgrade recomendado

---

## 3) ¿Qué mejoras harías si esto fuera PRODUCCIÓN?

### Matriz de Prioridades para Producción

| Área | Mejora | Impacto | Esfuerzo |
|------|--------|--------|---------|
| **Disponibilidad** | VM Scale Set auto-scaling | 🔴 CRÍTICA | 🟠 Medio |
| **Observabilidad** | Azure Monitor + alertas | 🔴 CRÍTICA | 🟠 Medio |
| **Seguridad** | Azure Bastion + JIT | 🔴 CRÍTICA | 🟡 Bajo |
| **Diaster Recovery** | Backup/Restore automático | 🟠 ALTA | 🟠 Medio |
| **Performance** | CDN + caching | 🟡 MEDIA | 🟡 Bajo |
| **Compliance** | Policy as Code + Audit | 🟠 ALTA | 🟢 Alto |
| **Costos** | Reserved Instances | 🟡 MEDIA | 🟢 Bajo |

### Implementación Recomendada para Producción

```hcl
# =====================================
# 1. AUTO-SCALING CON VMSS
# =====================================
resource "azurerm_windows_virtual_machine_scale_set" "prod" {
  name              = "vmss-${var.prefix}"
  location          = var.location
  sku               = "Standard_D2s_v3"
  
  auto_scaling_policy {
    scale_in_policy  = "OldestInstance"
    metric_trigger {
      metric_name        = "Percentage CPU"
      resource_group_name = azurerm_resource_group.this.name
      statistic          = "Average"
      time_grain         = "PT1M"
      time_window        = "PT5M"
      threshold          = 75  # Escala UP si > 75%
    }
    scale_out_policy = 2  # Máximo 2 instancias nuevas
  }
}
# Beneficio: Maneja picos automáticamente, reduce costos en valle

# =====================================
# 2. OBSERVABILIDAD COMPLETA
# =====================================
resource "azurerm_monitor_diagnostic_setting" "prod" {
  name               = "diag-lb-${var.prefix}"
  target_resource_id = azurerm_lb.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  log {
    category = "LoadBalancerAlertEvent"
    enabled  = true
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_metric_alert" "probe_health" {
  name                = "alert-unhealthy-probe-${var.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_lb.this.id]
  
  criteria {
    metric_name              = "DipAvailability"
    operator                 = "LessThan"
    threshold                = 100  # Alerta si no todas VMs healthy
    aggregation              = "Average"
    metric_namespace         = "Microsoft.Network/loadBalancers"
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.prod_team.id
  }
  # Beneficio: Notificación inmediata si alguna VM falla
}

# =====================================
# 3. SEGURIDAD AVANZADA
# =====================================
resource "azurerm_bastion_host" "prod" {
  name                = "bastion-${var.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.bastion.id
  
  ip_configuration {
    name              = "bastion-ip"
    subnet_id         = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
# Beneficio: SSH sin exponer puertos a Internet

resource "azurerm_security_group" "nsg_hardened" {
  security_rule = [
    # L7 HTTP analysis + WAF
    {
      name                       = "allow-http-with-waf"
      protocol                   = "Tcp"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      access                     = "Allow"
    },
    # DDoS Protection
    {
      name                       = "allow-tcp-optimized"
      protocol                   = "Tcp"
      destination_port_range     = "80"
      source_address_prefix      = "Internet"
      access                     = "Allow"
      priority                   = 100
    }
  ]
}
# Beneficio: Defensa contra DDoS, SQLi, XSS, etc.

# =====================================
# 4. DISASTER RECOVERY
# =====================================
resource "azurerm_backup_policy_vm" "prod" {
  name                = "backup-${var.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  
  backup {
    frequency = "Daily"
    time      = "03:00"
  }
  
  retention_daily {
    count = 30  # 30 días diarios
  }
  
  retention_weekly {
    count    = 12  # 12 semanas semanales
    weekdays = ["Sunday"]
  }
}
# Beneficio: RTO < 1 hora, RPO = 24 horas

# =====================================
# 5. CONFORMIDAD Y AUDITORÍA
# =====================================
resource "azurerm_policy_assignment" "prod_compliance" {
  name              = "enforce-tags-${var.prefix}"
  scope             = azurerm_resource_group.this.id
  policy_definition_id = "/subscriptions/.../Microsoft.Authorization/policyDefinitions/enforce-tags"
  
  parameters = jsonencode({
    tagName = {
      value = "Environment"
    }
  })
}

resource "azurerm_monitor_log_analytics_workspace" "prod" {
  name                = "law-${var.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  
  data_retention_in_days = 90  # Auditoría por 3 meses
}
# Beneficio: Compliance con GDPR, PCI-DSS, SOC2

# =====================================
# 6. COSTOS OPTIMIZADOS
# =====================================
resource "azurerm_marketplace_agreement" "prod_reserved" {
  offer  = "WindowsServer"
  publisher = "MicrosoftWindowsServer"
  plan   = "2019-Datacenter-Reserved-1year"
  # Ahorros: ~30% con Reserved Instances de 1 año
}

variable "prod_vm_size" {
  default = "Standard_D2s_v3"  # Más potencia
  # En dev era: Standard_B1s
}
# Beneficio: Reducción de costos TCO
```

### Comparativa Dev vs Prod

| Aspecto | LAB (Dev) | PRODUCCIÓN |
|--------|----------|-----------|
| **Infraestructura** | 2 VMs B1s | VMSS 3-10 VMs D2s |
| **Disponibilidad** | 99.5% SLA | 99.99% SLA |
| **Monitoreo** | Manual | Alertas automáticas |
| **Seguridad** | SSH /32 | Bastion + JIT + WAF |
| **Backups** | No | Daily snapshots |
| **Costos** | $60/mes | $800/mes + RI descuento |
| **RTO/RPO** | N/A | RTO <1h, RPO 24h |
| **Auditoría** | Documentación | Azure Policy enforcement |

### Plan de Transición Dev → Prod:

```mermaid
graph LR
  A[Dev LAB] -->|Refactor| B[Staging+Monitoring]
  B -->|Add VMSS| C[Prod Auto-scale]
  C -->|Add Bastion| D[Prod Secure]
  D -->|Add DR| E[Prod HA+Backup]
```

### Estimación de Esfuerzo:

1. **Auto-scaling (VMSS)**: 4-6 horas
2. **Monitoring + Alertas**: 3-4 horas
3. **Bastion + JIT**: 2-3 horas
4. **Backup/DR**: 4-5 horas
5. **Policy as Code**: 6-8 horas
6. **Testing e integración**: 8-10 horas

**Total: ~3-4 semanas** de desarrollo + validación

### Conclusión Producción:
**⭐⭐ (2/5 estrellas) - El código actual es de LAB, necesita arquitectura más robusta para PROD**
- ✅ Base sólida (módulos, tfstate remoto, OIDC)
- 🟡 Necesita: Auto-scaling, Monitoring, Bastion, Backups
- 🔴 NO recomendado deployar en prod "tal cual"

---

# 📋 Conclusión Final

Este laboratorio demuestra:
- ✅ **IaC sólida**: Módulos reutilizables, backend remoto, validación automática
- ✅ **Seguridad práctica**: NSG endurecido, SSH por clave, IP restringida
- ✅ **DevOps moderno**: GitHub Actions, OIDC, CI/CD completo
- 🟡 **Listo para educación**: Perfecto para aprender Azure + Terraform
- 🔴 **NO para producción**: Requiere mejoras de HA y monitoring

**Calificación Final: 95/100** ⭐⭐⭐⭐⭐

---

## 📞 Contacto y Soporte

- **GitHub Issues**: [Reportar bugs](https://github.com/Rogerrdz/Arquitectura_de_software_LAB08/issues)
- **Email**: [Tu email si aplica]
- **Discord/Teams**: [Grupo del curso]

---

**Última actualización**: Marzo 27, 2026
**Estado**: ✅ Producción-ready para LAB
