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

$date = get-date

$AllCurrentSnapshots = Get-AzureRmSnapshot -ResourceGroupName "SQLSAP-PR-RG"

foreach($CurrentSnapshot in $AllCurrentSnapshots){
    
    if(($date - $CurrentSnapshot.TimeCreated).days -ge 1){
        Write-Output ("Snapshot" + $CurrentSnapshot.Name + " " + $CurrentSnapshot.TimeCreated + " " + $date)
        Write-Output ("Remover Snapshot" + $CurrentSnapshot.Name)
        Remove-AzureRmSnapshot -ResourceGroupName $CurrentSnapshot.ResourceGroupName -SnapshotName $CurrentSnapshot.Name -Force
    }
}