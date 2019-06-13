################################################################################
### Pre-requisites
################################################################################

# - Subscription must exist

################################################################################
### Login to Azure. 
################################################################################
# Do the login prompt
Login-AzureRmAccount

# Prompt for subscription selection
$subscriptionId = 
    ( Get-AzureRmSubscription |
        Out-GridView `
          -Title "Select an Azure Subscription …" `
          -PassThru
    ).Id

Get-AzureRmSubscription -SubscriptionId $subscriptionId | Select-AzureRmSubscription

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

$rg = Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction SilentlyContinue

if($rg) {
    Write-Host "Resource group already exists."
} else {
    Write-Host "Creating resource group"
    $rg = New-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop
}

################################################################################
### Create the core Key Vault
################################################################################

$kvName = Read-Host 'Enter the name of the core Azure Key Vault resource'
if( !$kvName ) {
    Write-Host 'No Key Vault name supplied. Exiting.'
    exit
}

$kv = Get-AzureRmKeyVault -Name $kvName -ErrorAction SilentlyContinue

if($kv) {
    Write-Host "Key Vault already exists."
} else {
    Write-Host "Creating Key Vault"
    $kv = New-AzureRmKeyVault -VaultName $kvName -ResourceGroupName $rgName -Location $location -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption
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
$azureAdApplication = Get-AzureRmADApplication -DisplayNameStartWith $azDevOpsAppName -ErrorAction SilentlyContinue
if( $azureAdApplication ) {
    Write-Host "Application Registration already exists."
} else {
	#$secureStringPwd = ConvertTo-SecureString $aadClientSecret -AsPlainText -Force
	Write-Host 'Creating a new AAD Application.'
	$azureAdApplication = New-AzureRmADApplication -DisplayName $azDevOpsAppName `
		-HomePage "https://www.microsoft.com/$azDevOpsAppName" `
		-IdentifierUris "https://www.microsoft.com/$azDevOpsAppName" -Password $aadClientSecret
}
Write-Host "AAD Application: $($azureAdApplication.ApplicationId)"

################################################################################
### Create the Azure AD Service Principal
################################################################################
$aadServicePrincipal = Get-AzureRmADServicePrincipal -SearchString $azDevOpsAppName -ErrorAction SilentlyContinue
if( !$aadServicePrincipal ) {
	Write-Host 'Creating a new AAD Service Principal.'
	$aadServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId
}
Write-Host "AAD Service Principal: $($aadServicePrincipal.Id)"

################################################################################
### Add the service principal credentials to KeyVault
################################################################################

Set-AzureKeyVaultSecret -VaultName $kvName -Name $aadServicePrincipal.Id -SecretValue $aadClientSecret

Write-Host 'Finished'