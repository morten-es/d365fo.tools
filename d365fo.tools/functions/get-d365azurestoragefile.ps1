﻿
<#
    .SYNOPSIS
        Get a file from Azure
        
    .DESCRIPTION
        Get all files from an Azure Storage Account
        
    .PARAMETER AccountId
        Storage Account Name / Storage Account Id where you want to look for files
        
    .PARAMETER AccessToken
        The token that has the needed permissions for the search action
        
    .PARAMETER Container
        Name of the blob container inside the storage account you want to look for files
        
    .PARAMETER Name
        Name of the file you are looking for
        
        Accepts wildcards for searching. E.g. -Name "Application*Adaptor"
        
        Default value is "*" which will search for all packages
        
    .PARAMETER Latest
        Instruct the cmdlet to only fetch the latest file from the Azure Storage Account
        
    .EXAMPLE
        PS C:\> Get-D365AzureStorageFile -AccountId "miscfiles" -AccessToken "xx508xx63817x752xx74004x30705xx92x58349x5x78f5xx34xxxxx51" -Container "backupfiles"
        
        Will get all files in the blob container
        
    .EXAMPLE
        PS C:\> Get-D365AzureStorageFile -AccountId "miscfiles" -AccessToken "xx508xx63817x752xx74004x30705xx92x58349x5x78f5xx34xxxxx51" -Container "backupfiles" -Name "*UAT*"
        
        Will get all files in the blob container that fits the "*UAT*" search value
        
    .NOTES
        Tags: Azure, Azure Storage, Token, Blob, File, Container
        
        Author: Mötz Jensen (@Splaxi)
#>
function Get-D365AzureStorageFile {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory = $false)]
        [string] $AccountId = $Script:AccountId,

        [Parameter(Mandatory = $false)]
        [string] $AccessToken = $Script:AccessToken,

        [Parameter(Mandatory = $false)]
        [string] $SAS = $Script:SAS,

        [Parameter(Mandatory = $false)]
        [Alias('Blob')]
        [Alias('Blobname')]
        [string] $Container = $Script:Container,

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [Alias('FileName')]
        [string] $Name = "*",

        [Parameter(Mandatory = $true, ParameterSetName = 'Latest')]
        [Alias('GetLatest')]
        [switch] $Latest
    )

    if (([string]::IsNullOrEmpty($AccountId) -eq $true) -or
        ([string]::IsNullOrEmpty($Container)) -or
        (([string]::IsNullOrEmpty($AccessToken)) -and ([string]::IsNullOrEmpty($SAS)))) {
        Write-PSFMessage -Level Host -Message "It seems that you are missing some of the parameters. Please make sure that you either supplied them or have the right configuration saved."
        Stop-PSFFunction -Message "Stopping because of missing parameters"
        return
    }

    Invoke-TimeSignal -Start

    if ([string]::IsNullOrEmpty($SAS)) {
        Write-PSFMessage -Level Verbose -Message "Working against Azure Storage Account with AccessToken"

        $storageContext = new-AzureStorageContext -StorageAccountName $AccountId.ToLower() -StorageAccountKey $AccessToken
    }
    else {
        Write-PSFMessage -Level Verbose -Message "Working against Azure Storage Account with SAS"

        $conString = $("BlobEndpoint=https://{0}.blob.core.windows.net/;QueueEndpoint=https://{0}.queue.core.windows.net/;FileEndpoint=https://{0}.file.core.windows.net/;TableEndpoint=https://{0}.table.core.windows.net/;SharedAccessSignature={1}" -f $AccountId.ToLower(), $SAS)
        $storageContext = new-AzureStorageContext -ConnectionString $conString
    }

    $cloudStorageAccount = [Microsoft.WindowsAzure.Storage.CloudStorageAccount]::Parse($storageContext.ConnectionString)

    $blobClient = $cloudStorageAccount.CreateCloudBlobClient()

    $blobcontainer = $blobClient.GetContainerReference($Container);

    try {
        $files = $blobcontainer.ListBlobs() | Sort-Object -Descending { $_.Properties.LastModified }

        if ($Latest) {
            $files | Select-Object -First 1
        }
        else {
    
            foreach ($obj in $files) {
                if ($obj.Name -NotLike $Name) { continue }

                $obj
            }
        }
    }
    catch {
        Write-PSFMessage -Level Warning -Message "Something broke" -ErrorRecord $_
    }
}