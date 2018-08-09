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

Function Get-BackupFiles($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table){
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
        $Cmd=new-object system.Data.SqlClient.SqlCommand("select * from [$Table] BR1", $Conn) 
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

Function Update-BackupFile($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table,$URI,$AccessTier,$BlobType,$Length,$Folder){
    try {
            <#
            $SQLCredential = $SQLCredential 
            $Database = $Database 
            $SqlServer = $SqlServer 
            $SqlServerPort = $SqlServerPort 
            $Table = $TableBackupRows 
            $URI = $Uri 
            $AccessTier = $AccessTier 
            $BlobType = $BlobType 
            $Length = $Length 
            $Folder = $Folder
            #>
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
            if($AccessTier -and $BlobType -and $Length -and $Folder){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$table]
                SET [AccessTier] = '$AccessTier'
                ,[BlobType] = '$BlobType'
                ,[Length] = '$Length'
                ,[Folder] = '$Folder'
                WHERE URI = '$URI'", $Conn)                
            }
            elseif($BlobType -and $Length -and $Folder){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$table]
                SET [BlobType] = '$BlobType'
                ,[Length] = '$Length'
                ,[Folder] = '$Folder'
                WHERE URI = '$URI'", $Conn)                
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

#$SQLCredential = Get-Credential

$SQLCredential       = Get-AutomationPSCredential -Name "paas-eu2-sql01"
$Database            = "BackupManagement"
$SqlServer           = "paas-eu2-sql01.database.windows.net"
$SqlServerPort       = "1433"
$TableBackupRows     = "BackupRows_v02"
$TableStorageAccount = "StorageAccount"

$StorageAccounts       = Get-StorageAccount -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableStorageAccount 
$StorageAccount        = $StorageAccounts | ?{$_.Name -eq "azprsqlsapstobackup"}
$StorageAccountContext = (Get-AzureRmStorageAccount -ResourceGroupName $StorageAccount.ResourceGroup -Name $StorageAccount.Name).Context

$BackupFilesinSto = Get-BackupFiles -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows

#$BackupFilesinSto = $BackupFilesinSto | ? {$_.URI -eq "https://azprsqlsapstobackup.blob.core.windows.net/ecc/ECP/20180404/ECP_20180404_090001.trn"}

$Containers       = @()
$Containers       += "ecc"
$Containers       += "general"
$Containers       += "collect"

$ChangeSetAzure   = @()

foreach($Container in $Containers){
    $AzureContainerFiles   = Get-AzureStorageBlob -Container $Container -Context $StorageAccountContext #-Blob "ECP/20180404/ECP_20180404_090001.trn"
    foreach($File in $AzureContainerFiles){
        $ChangeSet       = "{0}@{1}@{2}@{3}@{4}" -f $file.ICloudBlob.Uri.AbsoluteUri,$File.BlobType,$File.ICloudBlob.Properties.StandardBlobTier,[math]::Round($File.Length/1gb,5),$File.ICloudBlob.Parent.Prefix
        $ChangeSetAzure += $ChangeSet
    }
}

$ChangeSetSql = $BackupFilesinSto.ChangeSet 

$UriToUpdate = Compare-Object -ReferenceObject $ChangeSetSql -DifferenceObject $ChangeSetAzure 
$UriToUpdate = $UriToUpdate | ?{$_.SideIndicator -eq "=>"}
foreach($Update in $UriToUpdate.InputObject){
   $AccessTier = ''
   $Uri = $Update.Split('@')[0]
   $BlobType = $Update.Split('@')[1]
   if($Update.Split('@')[2]){
        $AccessTier = $Update.Split('@')[2]
   }
   #else{
   #    $AccessTier = "n/a"
   #}
   $Length = $Update.Split('@')[3]
   $Folder = $Update.Split('@')[4]
   Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -URI $Uri -AccessTier $AccessTier -BlobType $BlobType -Length $Length -Folder $Folder
}

if($AccessTier -and $BlobType -and $Length -and $Folder){
        Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -URI $Uri -AccessTier $AccessTier -BlobType $BlobType -Length $Length -Folder $Folder
   }
   elseif ($BlobType -and $Length -and $Folder){
        Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -URI $Uri -BlobType $BlobType -Length $Length -Folder $Folder
   }