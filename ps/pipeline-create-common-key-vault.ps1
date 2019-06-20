param(
    $dtap,
    $sourcePath,
    $WhatIf
)
###############################################################################
# Set verbose
###############################################################################
$VerbosePreference = "continue"

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

Write-Verbose "Creating DevOps common properties key vault."
#hard-coded
$kvName = "pat-devops-kv"
$rgName = "pat-core"
$location = "west europe"

$kv = Get-AzKeyVault -Name $kvName -ErrorAction SilentlyContinue

if($kv) {
    Write-Host "Key Vault already exists."
} else {
    Write-Host "Creating Key Vault"
    $kv = New-AzKeyVault -VaultName $kvName -ResourceGroupName $rgName -Location $location -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption
}

###############################################################################
# Add the object id of the DevOps account
###############################################################################
Write-Verbose "Getting the DevOps account Object Id"
$azDevOpsAppName = "pat-devops" #hard-coded
$azureAdApplication = Get-AzADApplication -DisplayNameStartWith $azDevOpsAppName -ErrorAction SilentlyContinue
if( $azureAdApplication ) {
    Write-Host "AAD Application: $($azureAdApplication.ApplicationId)"
} else {
	Write-Error "Could not find $($azDevOpsAppName) in Azure AD"
	exit 1
}

Write-Verbose "Setting access policies"
Set-AzKeyVaultAccessPolicy -VaultName $kvName -ObjectId $azureAdApplication -EnabledForDeployment -EnabledForTemplateDeployment `
    -PermissionsToKeys Decrypt,Encrypt,UnwrapKey,WrapKey,Verify,Sign,Get,List,Update,Create,Import,Delete,Backup,Restore,Recover,Purge `
    -PermissionsToSecrets Get,List,Set,Delete,Backup,Restore,Recover,Purge `
    -PermissionsToCertificates Get,List,Delete,Create,Import,Update,Managecontacts,Getissuers,Listissuers,Setissuers,Deleteissuers,Manageissuers,Recover,Backup,Restore,Purge `
    -PassThru

Write-Verbose "Adding the DevOpsAccountObjectId to key vault"
#hard-coded
Set-AzKeyVaultSecret -VaultName $kvName -Name "DevOpsAccountObjectId" -SecretValue (ConvertTo-SecureString $azureAdApplication.ApplicationId -AsPlainText -Force)

###############################################################################
# Add the Tenant ID
###############################################################################
Write-Verbose "Adding TenantId to key vault"
$context = Get-AzContext
Set-AzKeyVaultSecret -VaultName $kvName -Name "TenantId" -SecretValue (ConvertTo-SecureString $context.Tenant.Id -AsPlainText -Force)

