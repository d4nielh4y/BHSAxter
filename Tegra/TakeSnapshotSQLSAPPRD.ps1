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

$Servers = @()
$Server = [PSCustomObject]@{
        Name          = "azprsqlsap1"
        ResourceGroup = "sqlsap-pr-rg"
}

$Servers += $Server

$Server = [PSCustomObject]@{
        Name          = "azprsqlsap2"
        ResourceGroup = "sqlsap-pr-rg"
}
$Servers += $Server
$date = get-date -Format dd-MM-yyyy
$Servers

foreach($Server in $Servers){

    $vm = Get-AzureRmVM -ResourceGroupName $Server.ResourceGroup -Name $Server.Name
    $Disks  = $vm.StorageProfile.DataDisks.Name
    $Disks += $vm.StorageProfile.OsDisk.Name
    foreach($dsk in $Disks){
        $disk     = Get-AzureRmDisk -ResourceGroupName $Server.ResourceGroup -DiskName $dsk
        $snapshot = New-AzureRmSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $disk.Location -SkuName StandardLRS
        $snapshotName = $dsk +"_"+ $date
        New-AzureRmSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $vm.ResourceGroupName
    }
}

