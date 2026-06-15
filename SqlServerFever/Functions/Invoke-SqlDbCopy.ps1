<#
    .SYNOPSIS
        Invoke a SQL Server database copy.

    .DESCRIPTION
        This command will resolve the common use case of a database copy
        required to copy a production system database back to a test or
        development system.

    .EXAMPLE
        Invoke-SqlDbCopy -SourceSqlInstance 'SQL01' -SourceDatabaseName 'AdventureWorks' -DestinationSqlInstance 'SQL02'
        This command will copy the AdventureWorks database from SQL01 to SQL02.
        The destination database will keep the database name.

    .EXAMPLE
        Invoke-SqlDbCopy -SourceSqlInstance 'SQL01' -SourceDatabaseName 'AdventureWorks' -DestinationDatabaseName 'AdventureWorks_Test'
        This command will copy the AdventureWorks database within SQL01 to a
        new database named AdventureWorks_Test.

    .LINK
        https://github.com/claudiospizzi/SqlServerFever
#>
function Invoke-SqlDbCopy
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param
    (
        # Source SQL Server to copy the database from.
        [Parameter(Mandatory = $true)]
        [System.String]
        $SourceSqlInstance,

        # SQL credential to the source SQL Server. If not specified, use the
        # integrated Windows authentication.
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $SourceSqlCredential,

        # Name of the database to copy.
        [Parameter(Mandatory = $true)]
        [System.String]
        $SourceDatabaseName,

        # Destination SQL Server to copy the database too.
        [Parameter(Mandatory = $true)]
        [System.String]
        $DestinationSqlInstance,

        # SQL credential to the destination SQL Server. If not specified, use the
        # integrated Windows authentication.
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $DestinationSqlCredential,

        # Name of the restored database. If not specified, the name is equals to
        # the source database.
        [Parameter(Mandatory = $false)]
        [System.String]
        $DestinationDatabaseName,

        # Option to skip renaming the logical file names to match the physical
        # file names. By default, the logical file names are renamed to match
        # the physical file names to avoid issues with database files.
        [Parameter(Mandatory = $false)]
        [Switch]
        $SkipLogicalFileRename,

        # Option to skip changing the database owner to sa. By default, the
        # database owner is changed to sa to avoid issues with orphaned users.
        [Parameter(Mandatory = $false)]
        [Switch]
        $SkipOwnerChange
    )

    # Define and verify the connection splat to the source SQL Server.
    $sqlSource = @{
        SqlInstance = $SourceSqlInstance
    }
    if ($PSBoundParameters.ContainsKey('SourceSqlCredential'))
    {
        $sqlSource['SqlCredential'] = $SourceSqlCredential
    }
    $sqlSourceData = Test-SqlConnection @sqlSource -Verbose:$false

    # Define and verify the connection splat to the destination SQL Server.
    $sqlDestination = @{
        SqlInstance = $DestinationSqlInstance
    }
    if ($PSBoundParameters.ContainsKey('DestinationSqlCredential'))
    {
        $sqlDestination['SqlCredential'] = $DestinationSqlCredential
    }
    $sqlDestinationData = Test-SqlConnection @sqlDestination -Verbose:$false

    # Check if the destination database name was specified. If not, use the
    # source database name.
    if (-not $PSBoundParameters.ContainsKey('DestinationDatabaseName'))
    {
        if ($sqlSourceData.Server -eq $sqlDestinationData.Server)
        {
            throw 'Please specify the destination database name if the source and destination SQL Server is the same.'
        }

        $DestinationDatabaseName = $SourceDatabaseName
    }

    Write-Verbose "[Invoke-SqlDbCopy] Query last full and diff disk backup for database '$SourceDatabaseName' on SQL Server '$SourceSqlInstance'."

    # Get and check the last full backup for the source SQL Server.
    $fullBackup = Get-DbaDbBackupHistory @sqlSource -Database $SourceDatabaseName -DeviceType 'Disk' -LastFull
    if ($null -eq $fullBackup)
    {
        throw "Last full backup to disk not found for database '$SourceDatabaseName' on SQL Server '$SourceSqlInstance'."
    }

    # Get the last diff backup for the source SQL Server and check if it's after the full backup
    $diffBackup = Get-DbaDbBackupHistory @sqlSource -Database $SourceDatabaseName -DeviceType 'Disk' -LastDiff
    if ($null -ne $diffBackup)
    {
        if ($diffBackup.Start -lt $fullBackup.Start)
        {
            $diffBackup = $null
        }
    }

    $backupPaths = @($fullBackup.Path)
    if ($null -ne $diffBackup)
    {
        $backupPaths += $diffBackup.Path
    }

    if ($PSCmdlet.ShouldProcess("SQL Server: $DestinationSqlInstance, Database: $DestinationDatabaseName, Backups: $($backupPaths -join ', ')", "Restore Database (with replace)"))
    {
        Write-Verbose "[Invoke-SqlDbCopy] Restore database '$DestinationDatabaseName' to SQL Server '$DestinationSqlInstance' using path '$($backupPaths -join "', '")'."

        # Perform the database restore on the destination SQL Server.
        $restoreResult = Restore-DbaDatabase @sqlDestination -Path $fullBackup.Path -DatabaseName $DestinationDatabaseName -ReplaceDbNameInFile -WithReplace

        # Restore the owner to sa.
        if (-not $SkipOwnerChange.IsPresent)
        {
            Write-Verbose "[Invoke-SqlDbCopy] On SQL Server '$DestinationSqlInstance' update database '$DestinationDatabaseName' owner to 'sa'."

            Invoke-DbaQuery @sqlDestination -Database $DestinationDatabaseName -Query "ALTER AUTHORIZATION ON DATABASE::[$DestinationDatabaseName] TO [sa]"
        }

        # Get all files and rename their logical file names, if they do not match
        # the physical file name. Only if not skipped.
        if (-not $SkipLogicalFileRename.IsPresent)
        {
            $files = Get-DbaDbFile @sqlDestination -Database $DestinationDatabaseName
            foreach ($file in $files)
            {
                $actualLogicalName   = $file.LogicalName
                $expectedLogicalName = [System.IO.Path]::GetFileNameWithoutExtension($file.PhysicalName)
                if ($actualLogicalName -ne $expectedLogicalName)
                {
                    Write-Verbose "[Invoke-SqlDbCopy] On SQL Server '$DestinationSqlInstance' rename database '$DestinationDatabaseName' logical file '$actualLogicalName' to '$expectedLogicalName'."

                    Invoke-DbaQuery @sqlDestination -Database $DestinationDatabaseName -Query "ALTER DATABASE [$DestinationDatabaseName] MODIFY FILE (NAME=N'$actualLogicalName', NEWNAME=N'$expectedLogicalName')"
                }
            }
        }

        Write-Output $restoreResult
    }
}
