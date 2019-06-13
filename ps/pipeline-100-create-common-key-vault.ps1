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

#hard-coded
$kvName = "pat-devops-kv"
$rgName = "pat-core"
$location = "west europe"

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
$azDevOpsAppName = "pat-devops" #hard-coded
$azureAdApplication = Get-AzureRmADApplication -DisplayNameStartWith $azDevOpsAppName -ErrorAction SilentlyContinue
if( $azureAdApplication ) {
    Write-Host "AAD Application: $($azureAdApplication.ApplicationId)"
} else {
	Write-Error "Could not find $($azDevOpsAppName) in Azure AD"
	exit 1
}

Set-AzureRmKeyVaultAccessPolicy -VaultName $kvName -ObjectId $azureAdApplication -EnabledForDeployment -EnabledForTemplateDeployment `
    -PermissionsToKeys Decrypt,Encrypt,UnwrapKey,WrapKey,Verify,Sign,Get,List,Update,Create,Import,Delete,Backup,Restore,Recover,Purge `
    -PermissionsToSecrets Get,List,Set,Delete,Backup,Restore,Recover,Purge `
    -PermissionsToCertificates Get,List,Delete,Create,Import,Update,Managecontacts,Getissuers,Listissuers,Setissuers,Deleteissuers,Manageissuers,Recover,Backup,Restore,Purge `
    -PassThru

#hard-coded
Set-AzureKeyVaultSecret -VaultName $kvName -Name "DevOpsAccountObjectId" -SecretValue (ConvertTo-SecureString $azureAdApplication.ApplicationId -AsPlainText -Force)
