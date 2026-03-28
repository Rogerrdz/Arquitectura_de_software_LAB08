# Paso a paso para terminar al 100 por ciento

Este documento te lleva desde cero hasta la entrega completa en Teams.

## 1) Prerrequisitos locales
En PowerShell verifica herramientas:

```powershell
az version
terraform -version
```

Debe existir tu llave publica (ya detectada):

```powershell
Test-Path "C:/Users/Admin/.ssh/id_ed25519.pub"
```

## 2) Login en Azure y contexto

```powershell
az login
az account show --output table
```

Si tienes varias suscripciones:

```powershell
az account list --output table
az account set --subscription "<SUBSCRIPTION_ID_O_NOMBRE>"
az account show --output table
```

## 3) Bootstrap del backend remoto (state)
Ejecuta estos comandos en PowerShell:

```powershell
$SUFFIX = Get-Random -Maximum 99999
$LOCATION = "eastus"
$RG = "rg-tfstate-lab8"
$STO = "sttfstate$SUFFIX"
$CONTAINER = "tfstate"

az group create --name $RG --location $LOCATION
az storage account create --resource-group $RG --name $STO --location $LOCATION --sku Standard_LRS --encryption-services blob
az storage container create --name $CONTAINER --account-name $STO --auth-mode login

@"
resource_group_name  = "$RG"
storage_account_name = "$STO"
container_name       = "$CONTAINER"
key                  = "lab8/dev/terraform.tfstate"
"@ | Set-Content -Path "infra/backend.hcl"
```

Verifica que el archivo se creo:

```powershell
Get-Content infra/backend.hcl
```

## 4) Verifica valores reales del entorno dev
Ya quedaron en [infra/env/dev.tfvars](infra/env/dev.tfvars):
- owner: `admin`
- ssh_public_key: `C:/Users/Admin/.ssh/id_ed25519.pub`
- allow_ssh_from_cidr: `179.51.125.11/32`

Si tu IP cambia, actualiza solo este valor:

```powershell
$IP = Invoke-RestMethod -Uri "https://api.ipify.org"
(Get-Content infra/env/dev.tfvars) -replace 'allow_ssh_from_cidr = ".*"', "allow_ssh_from_cidr = `"$IP/32`"" | Set-Content infra/env/dev.tfvars
```

## 5) Despliegue local (evidencia tecnica)

```powershell
Set-Location infra
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan -var-file=env/dev.tfvars -out plan.tfplan
terraform apply plan.tfplan
```

Obtiene outputs:

```powershell
terraform output
terraform output -raw lb_public_ip
```

Prueba balanceo (haz varias peticiones para ver hostnames alternando):

```powershell
$LB = terraform output -raw lb_public_ip
1..10 | ForEach-Object { Invoke-RestMethod -Uri "http://$LB" }
```

## 6) Pipeline GitHub Actions con OIDC
Archivo ya listo: [ .github/workflows/terraform.yml](.github/workflows/terraform.yml)

### 6.1 Crear App Registration y Federated Credential

```powershell
$SUB_ID = az account show --query id -o tsv
$TENANT_ID = az account show --query tenantId -o tsv
$APP_NAME = "gh-lab8-oidc"

$APP_ID = az ad app create --display-name $APP_NAME --query appId -o tsv
$SP_OBJECT_ID = az ad sp create --id $APP_ID --query id -o tsv
```

Asigna permisos al RG del laboratorio (Contributor):

```powershell
$LAB_RG = "rg-lab8-eastus"
$SCOPE = az group show --name $LAB_RG --query id -o tsv
az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal --role Contributor --scope $SCOPE
```

Crea federacion OIDC para este repo (ajusta owner/repo):

```powershell
$OWNER = "<TU_ORG_O_USUARIO_GITHUB>"
$REPO = "<TU_REPO>"

$CRED = @{
  name = "gh-main"
  issuer = "https://token.actions.githubusercontent.com"
  subject = "repo:$OWNER/$REPO:ref:refs/heads/main"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 4

$TMP = New-TemporaryFile
$CRED | Set-Content $TMP
az ad app federated-credential create --id $APP_ID --parameters @$TMP
```

### 6.2 Configurar secrets en GitHub
En Settings > Secrets and variables > Actions, crea:
- `AZURE_CLIENT_ID` = APP_ID
- `AZURE_TENANT_ID` = TENANT_ID
- `AZURE_SUBSCRIPTION_ID` = SUB_ID

### 6.3 Ejecutar CI/CD
- Abre PR para disparar `fmt/validate/plan`.
- Revisa artefacto y comentario del plan.
- Ejecuta workflow manual `Terraform Azure` con:
  - `environment=dev`
  - `confirm_apply=APPLY`

## 7) Evidencias para Teams
1. Repo con código Terraform y workflow.
2. Diagramas en [docs/diagramas.md](docs/diagramas.md).
3. Capturas de:
   - `terraform output -raw lb_public_ip`
   - respuestas alternadas de hostname.
4. Reflexion en [docs/reflexion-tecnica-template.md](docs/reflexion-tecnica-template.md).
5. Captura de ejecucion del plan en PR y apply manual.

## 8) Limpieza final (obligatoria)

```powershell
Set-Location infra
terraform destroy -var-file=env/dev.tfvars
```

Luego confirma en Azure Portal que no queden recursos del lab.
