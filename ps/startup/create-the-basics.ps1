param(
    [bool] $AlreadySignedIn = $false
)
################################################################################
### Pre-requisites
################################################################################

# - Subscription must exist

################################################################################
### Login to Azure. 
################################################################################
if( $AlreadySignedIn -eq $false ) {
    # Do the login prompt
    Login-AzAccount

    # Prompt for subscription selection
    $subscriptionId = 
        ( Get-AzSubscription |
            Out-GridView `
            -Title "Select an Azure Subscription …" `
            -PassThru
        ).Id

    Get-AzSubscription -SubscriptionId $subscriptionId | Select-AzSubscription
}

################################################################################
### Create the core resource group 
################################################################################

$rgName = Read-Host 'Enter the name of the core resource group'
if( !$rgName ) {
    Write-Host 'No resource group name supplied. Exiting.'
    exit
}

$location = Read-Host 'Enter the region for the core resource group'
if( !$location ) {
    Write-Host 'No resource group region supplied. Exiting.'
    exit
}

$rg = Get-AzResourceGroup -Name $rgName -Location $location -ErrorAction SilentlyContinue

if($rg) {
    Write-Host "Resource group already exists."
} else {
    Write-Host "Creating resource group"
    $rg = New-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop
}

################################################################################
### Create the core Key Vault
################################################################################

$kvName = Read-Host 'Enter the name of the core Azure Key Vault resource'
if( !$kvName ) {
    Write-Host 'No Key Vault name supplied. Exiting.'
    exit
}

$kv = Get-AzKeyVault -Name $kvName -ErrorAction SilentlyContinue

if($kv) {
    Write-Host "Key Vault already exists."
} else {
    Write-Host "Creating Key Vault"
    $kv = New-AzKeyVault -VaultName $kvName -ResourceGroupName $rgName -Location $location -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption
}

################################################################################
### Create the Azure AD Application Registration (Client ID)
################################################################################

$azDevOpsAppName = Read-Host 'Enter the name of App Registration for Azure DevOps'
if( !$azDevOpsAppName ) {
    Write-Host 'No App Registration name supplied. Exiting.'
    exit
}

$aadClientSecret = Read-Host 'Enter the secret for the App Registration for Azure DevOps' -AsSecureString
if( !$aadClientSecret ) {
    Write-Host 'No secret supplied. Exiting.'
    exit
}

# Create the Azure AD Application if it does not exist
$azureAdApplication = Get-AzADApplication -DisplayNameStartWith $azDevOpsAppName -ErrorAction SilentlyContinue
if( $azureAdApplication ) {
    Write-Host "Application Registration already exists."
} else {
	#$secureStringPwd = ConvertTo-SecureString $aadClientSecret -AsPlainText -Force
	Write-Host 'Creating a new AAD Application.'
	$azureAdApplication = New-AzADApplication -DisplayName $azDevOpsAppName `
		-HomePage "https://www.microsoft.com/$azDevOpsAppName" `
		-IdentifierUris "https://www.microsoft.com/$azDevOpsAppName" -Password $aadClientSecret
}
Write-Host "AAD Application: $($azureAdApplication.ApplicationId)"

################################################################################
### Create the Azure AD Service Principal
################################################################################
$aadServicePrincipal = Get-AzADServicePrincipal -SearchString $azDevOpsAppName -ErrorAction SilentlyContinue
if( !$aadServicePrincipal ) {
	Write-Host 'Creating a new AAD Service Principal.'
	$aadServicePrincipal = New-AzADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId
}
Write-Host "AAD Service Principal: $($aadServicePrincipal.Id)"

################################################################################
### Grant the service principal access to the key vault
################################################################################

Set-AzKeyVaultAccessPolicy -VaultName $kvName -ObjectId $aadServicePrincipal.Id `
    -PermissionsToKeys Decrypt,Encrypt,UnwrapKey,WrapKey,Verify,Sign,Get,List,Update,Create,Import,Delete,Backup,Restore,Recover,Purge `
    -PermissionsToSecrets Get,List,Set,Delete,Backup,Restore,Recover,Purge `
    -PermissionsToCertificates Get,List,Delete,Create,Import,Update,Managecontacts,Getissuers,Listissuers,Setissuers,Deleteissuers,Manageissuers,Recover,Backup,Restore,Purge `
    -PassThru

###############################################################################
# Add the DevOpsAccountObjectId
###############################################################################
Write-Verbose "Adding the DevOpsAccountObjectId to key vault"
Set-AzureKeyVaultSecret -VaultName $kvName -Name "DevOpsAccountObjectId" -SecretValue (ConvertTo-SecureString $aadServicePrincipal.Id -AsPlainText -Force)

###############################################################################
# Add the Tenant ID
###############################################################################
Write-Verbose "Adding TenantId to key vault"
$context = Get-AzContext
Set-AzureKeyVaultSecret -VaultName $kvName -Name "TenantId" -SecretValue (ConvertTo-SecureString $context.Tenant.Id -AsPlainText -Force)



Write-Host 'Finished'