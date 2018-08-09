Function Check-Backupdate($Date){
    [datetime]$Temp = Get-Date -Year $date.Year -Month $date.Month -Day 1
    $Temp = $Temp.AddMonths(1)
    $lastday = $Temp.AddDays(-1)
    if(($date.Year -eq $lastday.Year) -and ($date.Month -eq $lastday.Month) -and ($date.Day -eq $lastday.Day)){
        return $true
    }
    else{
        return $false
    }
}

Function Get-BackupFolders($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table,$DatabaseName,$ContainerName){
    try {
    <#
    $SQLCredential = $SQLCredential 
    $Database = $Database 
    $SqlServer = $SqlServer 
    $SqlServerPort = $SqlServerPort 
    $Table = $TableBackupRows 
    $Age = $AgeControl 
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
    
        # Open the SQL connection 
        $Conn.Open() 

        $Cmd=new-object system.Data.SqlClient.SqlCommand("select Distinct [ContainerName],[Database],Folder,backupdate
        from [$Table] BR1
        where status = 'Reallocated'
        or status like '%Retention%'", $Conn) 
       
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

Function Update-BackupFile($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table,$ContainerName,$DatabaseName,$Folder,$Status){
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
            if($ContainerName -and $DatabaseName -and $Folder -and $Status){
                $Cmd=new-object system.Data.SqlClient.SqlCommand("UPDATE [dbo].[$Table]
                SET [status] = '$Status'
                  ,[LastStatusModified] = '$Date'
                WHERE [ContainerName] = '$ContainerName'
                  and [Database] = '$DatabaseName'
                  and [Folder] = '$Folder'", $Conn) 
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
    
    #$SQLCredentialPassword = gc "C:\Scripts\Credential\paas-eu2-sql01-svc-backupmanagement.txt" | ConvertTo-SecureString
    #$SQLCredentialUser     = "adm.azure"
    #$SQLCredential = new-object -typename System.Management.Automation.PSCredential -argumentlist $SQLCredentialUser,$SQLCredentialPassword
    #$SQLCredential = Get-Credential
    $SQLCredential = Get-AutomationPSCredential -Name "paas-eu2-sql01"

    $Database            = "BackupManagement"
    $SqlServer           = "paas-eu2-sql01.database.windows.net"
    $SqlServerPort       = "1433"
    $TableBackupRows     = "BackupRows_v02"
    $TableStorageAccount = "StorageAccount"

    $BackupFolders       = Get-BackupFolders -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows

    #$updates = @()
    foreach($BackupFolder in $BackupFolders){
        $check = Check-Backupdate -Date $BackupFolder.backupdate
        if($check -eq $true){
            #$updates += $BackupFolder
            if(((get-date) - $BackupFolder.backupdate).days -lt 1095){#1825
                Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -ContainerName $BackupFolder.ContainerName -DatabaseName $BackupFolder.Database -Folder $BackupFolder.Folder -Status "Retention 3 Years"
            }
            else{
                Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -ContainerName $BackupFolder.ContainerName -DatabaseName $BackupFolder.Database -Folder $BackupFolder.Folder -Status "Retention expired"
            }
        }
        elseif($check -eq $false){
            if(((get-date) - $BackupFolder.backupdate).days -lt 30){#1825
                Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -ContainerName $BackupFolder.ContainerName -DatabaseName $BackupFolder.Database -Folder $BackupFolder.Folder -Status "Retention 30 Days"
            }
            else{
                Update-BackupFile -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $TableBackupRows -ContainerName $BackupFolder.ContainerName -DatabaseName $BackupFolder.Database -Folder $BackupFolder.Folder -Status "Retention expired"
            }
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
