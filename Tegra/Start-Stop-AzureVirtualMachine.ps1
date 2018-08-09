param(
    [string]$VMName,
    [string]$RGName,
    [string]$Action
)
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    
    if($action -eq "Start"){
        Write-Output "Start Azure VM: $VMName"
        Start-azurermvm -Name $VMName -ResourceGroupName $RGName
    }
    elseif($action -eq "Stop"){
        Write-Output "Stop Azure VM: $VMName"
        Stop-azurermvm -Name $VMName -ResourceGroupName $RGName -force
    }
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

