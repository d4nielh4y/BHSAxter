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

Function Get-BackupFiles($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table,$BlobType){
    try {
        if ($SqlCredential -eq $null) 
        { 
            throw "Could not retrieve '$SqlCredentialAsset' credential asset. Check that you created this first in the Automation service." 
        }   
        # Get the username and password from the SQL Credential 
        $SqlUsername = $SqlCredential.UserName 
        $SqlPass     = $SqlCredential.GetNetworkCredential().Password
     
        # Define the connection to the SQL Database 
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$SqlServer,$SqlServerPort;Database=$Database;User ID=$SqlUsername;Password=$SqlPass;Trusted_Connection=False;Encrypt=True;Connection Timeout=30;") 
    
        # Open the SQL connection 
        $Conn.Open() 
        $Cmd=new-object system.Data.SqlClient.SqlCommand("select * from [$Table]
                                                        where (status = 'Retention 5 Years'
                                                        or status = 'Retention 1 Year'
                                                        or status = 'Reallocated')
                                                        and [BlobType] = '$BlobType' 
                                                        and [AccessTier] <> 'Archive'", $Conn) 
        $Cmd.CommandTimeout=120 
        $Ds=New-Object system.Data.DataSet 
        $Da=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd) 
        [void]$Da.fill($Ds) 
        $result = $ds.Tables[0].Rows
        $Conn.Close()
        return $result
    }
    catch {
        $result = [PSCustomObject]@{
                    Name           = $FileName
                    ErrorState     = "Failed"
                    ErrorMessage   = "$($_.Exception.Message)"
                    }
        return $result
    }
}

$SQLCredential = Get-AutomationPSCredential -Name "paas-eu2-sql01"

$Database            = "BackupManagement"
$SqlServer           = "paas-eu2-sql01.database.windows.net"
$SqlServerPort       = "1433"
$TableBackupRows     = "BackupRows_v02"
$TableStorageAccount = "StorageAccount"
$AgeControl          = "15"
$localpath           = "E:\Temp"

$FilesToApplyArchive = Get-BackupFiles -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -BlobType "BlockBlob"

foreach($File in $FilesToApplyArchive){
    $JSON = @{
        "UriBlob" = $file.URI
        "AccessTier" = "Archive"
        "ContainerName" = $file.ContainerName
    } | ConvertTo-Json

    Invoke-WebRequest -Uri "https://paas-eu2-fapp1.azurewebsites.net/api/SetBlobTier?code=VmwqrqQ1x1tMbOXbnqjB/BnNffrjvGTsDWMUzCQtbgYjsAwhJMuZcw==" -Method Post -Body $JSON -ContentType Application/Json -UseBasicParsing
}
