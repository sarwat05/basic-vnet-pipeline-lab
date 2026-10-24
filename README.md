# Basic CI/CD pipeline: deploy one VNet with Terraform

Deploys a resource group, one VNet and one subnet to a single subscription. GitHub Actions logs in
to Azure with OIDC (no stored secret), keeps Terraform state in Azure Storage, plans on pull
requests, and applies when you merge to `main`.

## CI and CD in this pipeline
- **CI (continuous integration):** on every pull request the pipeline formats, validates and plans. Nothing changes in Azure.
- **CD (continuous delivery):** when the change is merged to `main`, the pipeline applies the plan to Azure.

## Files
| File | Purpose |
|---|---|
| terraform/providers.tf | Provider and remote state backend |
| terraform/variables.tf | Inputs with defaults (region, names, address ranges) |
| terraform/main.tf | Resource group, VNet, subnet |
| terraform/outputs.tf | Values printed after apply |
| .github/workflows/deploy-vnet.yml | The pipeline |
| scripts/bootstrap.ps1 | One-time setup of state storage and the OIDC identity |
| scripts/add-federated-credential.ps1 | Fixes an OIDC subject mismatch |

## Setup order
1. Create an empty GitHub repo (for example `basic-vnet-pipeline`).
2. In PowerShell, after `az login`, run: `./scripts/bootstrap.ps1 -GitHubRepo sarwat05/basic-vnet-pipeline`
3. Add the five printed values as GitHub **Variables** (not Secrets): `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `TFSTATE_RG`, `TFSTATE_SA`.
4. Push the code to `main`:
   `git init`, `git add .`, `git commit -m "initial"`, `git branch -M main`, `git remote add origin <repo url>`, `git push -u origin main`
5. Open the Actions tab and watch the run. The first push plans and applies.
6. Check the portal for `rg-basiclab` with `vnet-basiclab`.

## Try the pull request flow
1. Create a branch and change `address_space` or the subnet prefix in `variables.tf`.
2. Push it and open a pull request. The pipeline plans and prints what would change.
3. Merge it. The pipeline applies the change.

## If login fails with AADSTS700213
Newer GitHub repos can present a subject that contains numeric IDs, so the plain subject created by the bootstrap does not match. Open the failed run, read the `sub` value printed by "Show the OIDC claims", and run:
`./scripts/add-federated-credential.ps1 -AppId <ARM_CLIENT_ID> -Name github-main-fix -Subject "<sub value>"`
Do the same for the pull request subject if plans on pull requests fail. Wait a minute, then re-run the workflow.

## Cost
Free: resource groups, VNets and subnets cost nothing. The state storage account costs a few cents per month.

## Clean up
Actions > deploy-vnet > Run workflow > action = destroy. Then delete `rg-tfstate` and the `sp-basic-vnet-pipeline` app registration.

## Notes
- The pipeline identity has Contributor on the subscription. That is enough for a VNet and acceptable for a lab. For real work, scope it to a resource group.
- There is no approval gate between plan and apply. Real teams add a protected environment with required reviewers before apply.
- This code was written without being run against Azure. If something fails, read the error in the Actions log and fix that step.
