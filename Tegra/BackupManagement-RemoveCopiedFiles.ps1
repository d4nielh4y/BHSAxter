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

Function Update-BackupFile($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table,$URI,$NewLocation,$Status,$StorageAccount){
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
            if($NewLocation -and $StorageAccount -and $Status){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$Table]
                SET [Status] = '$Status'
                  ,[NewLocation] = '$NewLocation'
                  ,[StorageAccount] = '$StorageAccount'
                  ,[LastStatusModified] = '$Date'
                WHERE URI = '$URI'", $Conn) 
            }
            elseif($Status -and $StorageAccount){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$Table]
                SET [Status] = '$Status'
                  ,[StorageAccount] = '$StorageAccount'
                  ,[LastStatusModified] = '$Date'
                WHERE URI = '$URI'", $Conn) 
            }
            elseif($NewLocation){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$Table]
                SET [NewLocation] = '$NewLocation'
                ,[LastStatusModified] = '$Date'
                WHERE URI = '$URI'", $Conn)                
            } 
            elseif($StorageAccount){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$Table]
                SET [StorageAccount] = '$StorageAccount'
                ,[LastStatusModified] = '$Date'
                WHERE URI = '$URI'", $Conn)                
            }
            elseif($Status){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$Table]
                SET [Status] = '$Status'
                ,[LastStatusModified] = '$Date'
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

Function Compare-BackupFiles($ContainerName, $ContainerFiles, $StorageContext01, $Uri, $OldLocation){
    try {
        $File01 = $ContainerFiles | ? {$_.ICloudBlob.Uri.AbsoluteUri -eq ($Uri)}
        $File02 = $ContainerFiles | ? {$_.ICloudBlob.Uri.AbsoluteUri -eq ($OldLocation)}

        #$URIFile01 = 'https://azprsqlsapstobackup.blob.core.windows.net/ecc/ECP/20171014/ECP_20171014_180001.log'
        #$URIFile02 = 'https://azprsqlsapstobackuplong.blob.core.windows.net/ecc/ECP/20171014/ECP_20171014_180001.log'

        $result = [PSCustomObject]@{
                    Name           = $File01.Name
                    ErrorState     = "Failed"
                    Uri            = $File01
                    OldLocation    = $File02
                    }
        if($File02 -and $File01){
            if($File02.Length -eq $File01.Length){
                $result.ErrorState = "Success"
                return $result
            }
            else{
                return $result
            }
        }
    }
    catch {
        $result = [PSCustomObject]@{
                    Name           = $File01.Name
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

$StorageAccounts                = Get-StorageAccount -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableStorageAccount 
$StorageAccountShortTerm        = $StorageAccounts | ?{$_.Name -eq "azprsqlsapstobackup"}
$StorageAccountShortTermContext = (Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountShortTerm.ResourceGroup -Name $StorageAccountShortTerm.Name).Context

$AllFilesCopied = Get-BackupFiles -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -Status "Copied" #| ? {$_.Database -ne "ECP"}
$Containers     = $AllFilesCopied | select -Unique -Property ContainerName 

foreach($Container in $Containers.ContainerName){
    $ContainerFiles = Get-AzureStorageBlob -Container $Container -Context $StorageAccountShortTermContext 
    $AllFilesCopiedOfContainer = $AllFilesCopied | ?{$_.ContainerName -eq $Container}
    foreach($FileCopied in $AllFilesCopiedOfContainer){
        $CompareFile = Compare-BackupFiles -ContainerName $FileCopied.ContainerName -StorageContext01 $StorageAccountShortTermContext -Uri $FileCopied.URI -OldLocation $FileCopied.OldLocation -ContainerFiles $ContainerFiles
        if($CompareFile.ErrorState -eq "Success"){
            Remove-AzureStorageBlob -CloudBlob $CompareFile.OldLocation.ICloudBlob -Context $StorageAccountShortTermContext
            Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -URI $CompareFile.Uri.ICloudBlob.Uri.AbsoluteUri -Status "Reallocated" -storageaccount "azprsqlsapstobackup"
        }
    }
}
