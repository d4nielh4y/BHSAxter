#$ResourceGroup = "rds-eu2-rg"
#$NsgName       = "azprrds01-nic01"
#$Action        = "Deny"

param(
    [string]$ResourceGroup,
    [string]$NsgName,
    [string]$Action
)


$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    #"Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Name $NsgName

Set-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
-Name "Deny_Port_Any" `
-Description "Deny_Port_Any" `
-Access $Action `
-Protocol * `
-Direction Outbound `
-Priority 1000 `
-SourceAddressPrefix * `
-SourcePortRange * `
-DestinationAddressPrefix Internet `
-DestinationPortRange 80,443

Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg