Function Get-StorageAccount($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table){
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
        $Cmd=new-object system.Data.SqlClient.SqlCommand("SELECT * FROM [dbo].[StorageAccount]", $Conn)  
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

Function Get-BackupFiles($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table, $Status){
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
        $Cmd=new-object system.Data.SqlClient.SqlCommand("select * from [$table] BR1 where [Status] = '$Status'", $Conn) 
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

Function Update-BackupFile($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table,$Status,$uri){
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

            $Date = get-date
            # Open the SQL connection 
            $Conn.Open() 
            if($uri -and $status){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$Table]
                SET [status] = '$Status'
                  ,[LastStatusModified] = '$Date'
                WHERE [uri] = '$uri'", $Conn) 
            }
            else{
                return "Missing parameters"
                break
            }
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

    
    #$sqlcredential = get-credential
    $SQLCredential       = Get-AutomationPSCredential -Name "paas-eu2-sql01"
    $StatusToRemove      = "Retention expired"
    $Database            = "BackupManagement"
    $SqlServer           = "paas-eu2-sql01.database.windows.net"
    $SqlServerPort       = "1433"
    $TableBackupRows     = "BackupRows_v02"
    $TableStorageAccount = "StorageAccount"

    $StorageAccounts                = Get-StorageAccount -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableStorageAccount 
    $StorageAccountShortTerm        = $StorageAccounts | ?{$_.Name -eq "azprsqlsapstobackup"}
    $StorageAccountShortTermContext = (Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountShortTerm.ResourceGroup -Name $StorageAccountShortTerm.Name).Context

    $AllFilesExpired = Get-BackupFiles -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -Status $StatusToRemove #| ? {$_.Database -ne "ECP"}
    $Containers      = $AllFilesExpired | select -Unique -Property ContainerName 

    foreach($File in $AllFilesExpired){
        $FileAux = Get-AzureStorageBlob -Container $File.ContainerName -Context $StorageAccountShortTermContext -Prefix ("{0}{1}" -f $file.folder,$file.Name)
        if($FileAux -and ($FileAux | Measure-Object).Count -eq 1){
            Write-Output "Existe" $FileAux.ICloudBlob.Uri.AbsoluteUri
            
            Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -URI $FileAux.ICloudBlob.Uri.AbsoluteUri -Status "Removing"
            Remove-AzureStorageBlob -CloudBlob $FileAux.ICloudBlob -Context $StorageAccountShortTermContext -ErrorAction Stop
            Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -URI $FileAux.ICloudBlob.Uri.AbsoluteUri -Status "Removed"
        }
        elseif(!$FileAux){
            Write-Output "Não Existe" $file.URI
            Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -URI $File.URI -Status "Removed"
        }
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

