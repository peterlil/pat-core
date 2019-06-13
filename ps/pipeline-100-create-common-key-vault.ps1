param(
    $dtap,
    $sourcePath,
    $WhatIf
)

###############################################################################
# Dump the parameters
###############################################################################
Write-Verbose ""
Write-Verbose "Dumping parameters:"
Write-Verbose "dtap: $dtap"
Write-Verbose "sourcePath: $sourcePath"

###############################################################################
# Create the common properties key vault
###############################################################################

$kvName = "devops-kv"

$kv = Get-AzureRmKeyVault -Name $kvName -ErrorAction SilentlyContinue

if($kv) {
    Write-Host "Key Vault already exists."
} else {
    Write-Host "Creating Key Vault"
    $kv = New-AzureRmKeyVault -VaultName $kvName -ResourceGroupName $rgName -Location $location -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption
}


###############################################################################
# Add the Tenant ID
###############################################################################
$context = Get-AzureRmContext
Set-AzureKeyVaultSecret -VaultName $kvName -Name $"TenantId" -SecretValue (ConvertTo-SecureString $context.Tenant.Id -AsPlainText -Force)

###############################################################################
# Add the object id of the DevOps account
###############################################################################
$azDevOpsAppName = "pat-devops"
$azureAdApplication = Get-AzureRmADApplication -DisplayNameStartWith $azDevOpsAppName -ErrorAction SilentlyContinue
if( $azureAdApplication ) {
    Write-Host "AAD Application: $($azureAdApplication.ApplicationId)"
} else {
	Write-Error "Could not find $($azDevOpsAppName) in Azure AD"
	exit 1
}

Set-AzureKeyVaultSecret -VaultName $kvName -Name $"DevOpsAccountObjectId" -SecretValue (ConvertTo-SecureString $azureAdApplication.ApplicationId -AsPlainText -Force)
