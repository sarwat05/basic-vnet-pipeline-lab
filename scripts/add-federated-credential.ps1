<#
 Adds one more GitHub OIDC trust to an existing app. Use it when the pipeline fails with
 AADSTS700213 (no matching federated identity record): copy the 'sub' value printed by the
 "Show the OIDC claims" step and pass it here exactly.

 Usage:
   ./add-federated-credential.ps1 -AppId <client id> -Name github-main-fix -Subject "<sub value>"
#>
param(
  [Parameter(Mandatory = $true)][string]$AppId,
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Subject
)

$ErrorActionPreference = "Stop"
$json = @{ name = $Name; issuer = "https://token.actions.githubusercontent.com"; subject = $Subject; audiences = @("api://AzureADTokenExchange") } | ConvertTo-Json -Compress
$file = "cred-$Name.json"
$json | Set-Content -Encoding ascii $file
az ad app federated-credential create --id $AppId --parameters $file
Remove-Item $file
az ad app federated-credential list --id $AppId --query "[].{name:name, subject:subject}" -o table
