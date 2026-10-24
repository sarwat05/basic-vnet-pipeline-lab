<#
 One-time setup. Run in PowerShell (or Cloud Shell in PowerShell mode) after `az login`,
 as an account that is Owner on the subscription.

 Usage:
   ./bootstrap.ps1 -GitHubRepo sarwat05/basic-vnet-pipeline

 Creates: Terraform state storage, an Entra app with GitHub OIDC (no client secret),
 and gives that app Contributor on the subscription (enough for a VNet).
#>
param(
  [Parameter(Mandatory = $true)][string]$GitHubRepo,
  [string]$Location = "centralindia",
  [string]$MainSubject = "",   # optional: exact subject GitHub presents for the main branch
  [string]$PrSubject = ""      # optional: exact subject GitHub presents for pull requests
)

$ErrorActionPreference = "Stop"
function Check([string]$what) { if ($LASTEXITCODE -ne 0) { throw "Failed: $what" } }

if (-not $MainSubject) { $MainSubject = "repo:${GitHubRepo}:ref:refs/heads/main" }
if (-not $PrSubject)   { $PrSubject   = "repo:${GitHubRepo}:pull_request" }

$subId    = az account show --query id -o tsv;       Check "az account show"
$tenantId = az account show --query tenantId -o tsv; Check "az account show"
Write-Host "Using subscription: $subId"

Write-Host "0/4 Registering resource providers..."
foreach ($p in "Microsoft.Storage", "Microsoft.Network", "Microsoft.Authorization") {
  az provider register -n $p --wait | Out-Null; Check "register $p"
}

Write-Host "1/4 State storage..."
$stateRg = "rg-tfstate"
$sa = "tfstate" + (Get-Random -Minimum 100000 -Maximum 999999) + (Get-Random -Minimum 100000 -Maximum 999999)
az group create -n $stateRg -l $Location | Out-Null; Check "create state resource group"
az storage account create -n $sa -g $stateRg -l $Location --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false | Out-Null; Check "create storage account"
$saId = az storage account show -n $sa -g $stateRg --query id -o tsv; Check "show storage account"
$me   = az ad signed-in-user show --query id -o tsv; Check "signed-in user"
az role assignment create --assignee-object-id $me --assignee-principal-type User --role "Storage Blob Data Contributor" --scope $saId | Out-Null; Check "storage role for you"
Start-Sleep -Seconds 25
az storage container create --name tfstate --account-name $sa --auth-mode login | Out-Null; Check "create container"

Write-Host "2/4 App registration..."
$appId = az ad app create --display-name "sp-basic-vnet-pipeline" --query appId -o tsv; Check "create app"
az ad sp create --id $appId | Out-Null; Check "create service principal"

Write-Host "3/4 GitHub OIDC trust (no client secret)..."
foreach ($c in @(@{ n = "github-main"; s = $MainSubject }, @{ n = "github-pr"; s = $PrSubject })) {
  $json = @{ name = $c.n; issuer = "https://token.actions.githubusercontent.com"; subject = $c.s; audiences = @("api://AzureADTokenExchange") } | ConvertTo-Json -Compress
  $json | Set-Content -Encoding ascii "cred-$($c.n).json"
  az ad app federated-credential create --id $appId --parameters "cred-$($c.n).json" | Out-Null; Check "federated credential $($c.n)"
  Remove-Item "cred-$($c.n).json"
}

Write-Host "4/4 Permissions..."
az role assignment create --assignee $appId --role "Contributor" --scope "/subscriptions/$subId" | Out-Null; Check "Contributor on subscription"
az role assignment create --assignee $appId --role "Storage Blob Data Contributor" --scope $saId | Out-Null; Check "storage data role"

Write-Host ""
Write-Host "Add these as GitHub repository VARIABLES (Settings > Secrets and variables > Actions > Variables):"
Write-Host "  ARM_CLIENT_ID       = $appId"
Write-Host "  ARM_TENANT_ID       = $tenantId"
Write-Host "  ARM_SUBSCRIPTION_ID = $subId"
Write-Host "  TFSTATE_RG          = $stateRg"
Write-Host "  TFSTATE_SA          = $sa"
Write-Host ""
Write-Host "Keep this app ID for later: $appId"
