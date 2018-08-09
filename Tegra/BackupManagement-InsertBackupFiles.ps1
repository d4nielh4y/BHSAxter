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

Function Get-ContainerFileList($ContainerName, $StorageContext, $CurrentFiles){
    <#
    $ContainerName = $Container.Name 
    $StorageContext = $StorageAccountContext 
    $CurrentFiles = $AllCurrentFiles
    #>
    $Entries = @()
    $Files = Get-AzureStorageBlob -Container $ContainerName -Context $StorageContext | ? {$_.ICloudBlob.Uri.AbsoluteUri -notin ($CurrentFiles)}
    foreach($File in $Files){
        #$File.Name.Split('/').count
        if($File.Name.Split('/').count -eq 3 -and $File.Name.Split('/')[2] -notlike '*1.txt*'){
            #write-host $File.Name
            $Entry = [PSCustomObject]@{
                ContainerName  = $Container.Name
                Database       = $File.Name.Split('/')[0]
                Name           = $File.Name.Split('/')[2]
                Folder         = $File.ICloudBlob.Parent.Prefix
                BackupDate     = ([datetime]::Parse(($File.Name.Split('/')[1].Substring(0,4)+"/"+($File.Name.Split('/')[1]).Substring(4,2)+"/"+($File.Name.Split('/')[1]).Substring(6,2)))).ToUniversalTime()
                LastModified   = $File.LastModified.DateTime
                Length         = [math]::Round($file.Length/1gb,5)
                BlobType       = $File.BlobType
                FileType       = $File.Name.Split('.')[$File.Name.Split('.').count -1]
                URI            = $File.ICloudBlob.Uri.AbsoluteUri
                AccessTier     = $File.ICloudBlob.Properties.StandardBlobTier
                StorageAccount = $File.Context.StorageAccountName
            }
            $Entries += $Entry
        }
        elseif($File.Name.Split('/').count -eq 4 -and $File.Name.Split('/')[2] -notlike '*1.txt*'){
            $Entry = [PSCustomObject]@{
                ContainerName  = $Container.Name
                Database       = $File.Name.Split('/')[0]
                Name           = $File.Name.Split('/')[3]
                Folder         = $File.ICloudBlob.Parent.Prefix
                BackupDate     = ([datetime]::Parse(($File.Name.Split('/')[2].Substring(0,4)+"/"+($File.Name.Split('/')[2]).Substring(4,2)+"/"+($File.Name.Split('/')[2]).Substring(6,2)))).ToUniversalTime()
                LastModified   = $File.LastModified.DateTime
                Length         = [math]::Round($file.Length/1gb,5)
                BlobType       = $File.BlobType
                FileType       = $File.Name.Split('.')[$File.Name.Split('.').count -1]
                URI            = $File.ICloudBlob.Uri.AbsoluteUri
                AccessTier     = $File.ICloudBlob.Properties.StandardBlobTier
                StorageAccount = $File.Context.StorageAccountName
            }
            $Entries += $Entry
        }
    }
    $Entries = $Entries | Sort-Object -Property FileAge -Descending
    $Databases = $Entries | select -ExpandProperty Database -Unique
    return $Entries | Sort-Object -Property FileAge -Descending
}

Function New-SQLRow($Rows,$SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table){
    
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
    foreach($Row in $Backups){
        $ContainerName  = $Row.ContainerName
        $Database       = $Row.Database
        $Name           = $Row.Name
        $Folder         = $Row.Folder
        [datetime]$BackupDate     = $Row.BackupDate
        [datetime]$LastModified = $Row.LastModified
        $Length         = $Row.Length
        $BlobType       = $Row.BlobType
        $FileType       = $Row.FileType
        $URI            = $Row.URI
        $AccessTier     = $Row.AccessTier
        $StorageAccount = $Row.StorageAccount

        # Define the SQL command to run. In this case we are getting the number of rows in the table 
        $Cmd=new-object system.Data.SqlClient.SqlCommand("INSERT INTO [dbo].[$table]
        (  [ContainerName]
           ,[Database]
           ,[Name]
           ,[Folder]
           ,[BackupDate]
           ,[LastModified]
           ,[Length]
           ,[BlobType]
           ,[FileType]
           ,[URI]
           ,[Status]
           ,[StorageAccount]
           ,[AccessTier])
         VALUES
               ('$ContainerName'
               ,'$Database'
               ,'$Name'
               ,'$Folder'
               ,'$BackupDate'
               ,'$LastModified'
               ,'$Length'
               ,'$BlobType'
               ,'$FileType'
               ,'$URI'
               ,'New'
               ,'$StorageAccount'
               ,'$AccessTier')", $Conn) 
        $Cmd.CommandTimeout=120 
 
        # Execute the SQL command 
        $Ds=New-Object system.Data.DataSet 
        $Da=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd) 
        [void]$Da.fill($Ds) 
    }
    $Conn.Close()
}

Function Get-AllUriFiles($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table){
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

    $Cmd=new-object system.Data.SqlClient.SqlCommand("SELECT URI from [dbo].[$Table]", $Conn) 
    $Cmd.CommandTimeout=120 
    $Ds=New-Object system.Data.DataSet 
    $Da=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd) 
    [void]$Da.fill($Ds) 
    $result = $ds.Tables[0].Uri
    $Conn.Close()
    return $result
}

Function Get-AllOldUriFiles($SQLCredential,$Database,$SqlServer,$SqlServerPort,$Table){
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

    $Cmd=new-object system.Data.SqlClient.SqlCommand("select oldLocation from [dbo].[$Table] where oldlocation is not null", $Conn) 
    $Cmd.CommandTimeout=120 
    $Ds=New-Object system.Data.DataSet 
    $Da=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd) 
    [void]$Da.fill($Ds) 
    $result = $ds.Tables[0].oldLocation
    $Conn.Close()
    return $result
}

#$Id = "682893f7-a26f-4a93-8e74-0ed5d34d466a"
#Select-AzureRmSubscription -SubscriptionId $Id

$StorageAccountName          = "azprsqlsapstobackup"
$StorageAccountResourceGroup = "sqlsap-pr-rg"
$StorageAccount              = Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name $StorageAccountName
$StorageAccountContext       = $StorageAccount.Context
$StorageAccountContaneirs    = Get-AzureStorageContainer -Context $StorageAccountContext
$Database                    = "BackupManagement"
$SqlServer                   = "paas-eu2-sql01.database.windows.net"
$SqlServerPort               = "1433"
$Table                       = "BackupRows_v02"

$Backups = @()

$SQLCredential = Get-AutomationPSCredential -Name "paas-eu2-sql01"
#$SQLCredential = get-credential
$AllCurrentFiles = Get-AllUriFiles -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $Table
$AllOldUriFiles  = Get-AllOldUriFiles -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $Table
$AllCurrentFiles += $AllOldUriFiles

foreach($Container in $StorageAccountContaneirs){
    $Files = Get-ContainerFileList -ContainerName $Container.Name -StorageContext $StorageAccountContext -CurrentFiles $AllCurrentFiles
    
    $Backups += $Files
}
#Get-AzureStorageBlob -Container $Container -Context $StorageAccountShortTermContext $con
#$SQLCredential = Get-Credential
#$SQLCredential = Get-AutomationPSCredential -Name "SQLDaniel"

New-SQLRow -Rows $Backups -SQLCredential $SQLCredential -Database $Database -SqlServer $SqlServer -SqlServerPort $SqlServerPort -Table $Table