<#
    .SYNOPSIS
        Invoke the SQL Server database transaction log shrink process.

    .DESCRIPTION
        This command will resolve the common use case of a transaction log
        shrink required to shrink a transaction log file to a target size. As
        the shrinking requires a process of transaction log backup and shrink
        operations, they are combined in this command.

        This command relies on the SQL Maintenance Solution by Ola Hallengren to
        perform the transaction log backup. If the SQL Maintenance Solution is
        not installed, the command will fail.

    .EXAMPLE
        Invoke-SqlDbTrxShrink -SqlInstance 'SQL01' -Database 'AdventureWorks' -TargetSize 8GB
        This command will shrink the transaction log file of the AdventureWorks
        database on SQL01 to 8GB.

    .LINK
        https://github.com/claudiospizzi/SqlServerFever
#>
function Invoke-SqlDbTrxShrink
{
    [CmdletBinding(SupportsShouldProcess = $true,  ConfirmImpact = 'High')]
    param
    (
        # SQL instance name.
        [Parameter(Mandatory = $true)]
        [System.String]
        $SqlInstance,

        # SQL credential. If not specified, use the integrated Windows
        # authentication.
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $SqlCredential,

        # Database to shrink the transaction log for.
        [Parameter(Mandatory = $true)]
        [System.String]
        $Database,

        # The target size of the transaction log file.
        [Parameter(Mandatory = $true)]
        [System.Int64]
        $TargetSize,

        # Database where SQL Maintenance Solution Jobs by Ola Hallengren are
        # stored in.
        [Parameter(Mandatory = $false)]
        [System.String]
        $MaintenanceSolutionDatabase = 'DBATools',

        # Auto-shrink to the target size.
        [Parameter(Mandatory = $false)]
        [Switch]
        $Auto
    )

    if ($TargetSize % 64KB -ne 0)
    {
        Write-Warning "[Invoke-SqlDbTrxShrink] The target size should be a valid multiple of the recommended block size (64KB). "
    }

    # Define and verify the connection splat to the SQL Server.
    $sqlConnection = @{
        SqlInstance = $SqlInstance
        Database    = $Database
    }
    if ($PSBoundParameters.ContainsKey('SqlCredential'))
    {
        $sqlConnection['SqlCredential'] = $SqlCredential
    }
    Test-SqlConnection @sqlConnection -Verbose:$false | Out-Null

    $databaseLogFileName = Get-DbaDbFile @sqlConnection -Verbose:$false | Where-Object { $_.Type -eq 1 } | Select-Object -First 1 -ExpandProperty 'LogicalName'

    # Prepare the transaction log backup query.
    $queryBackup  = "EXECUTE [{0}].[dbo].[DatabaseBackup] @Databases = '{1}', @BackupType = 'LOG', @Compress = 'Y', @Verify = 'Y', @CheckSum = 'Y', @LogToTable = 'Y'" -f $MaintenanceSolutionDatabase, $Database
    $queryShrink  = "DBCC SHRINKFILE('{0}', 1)" -f $databaseLogFileName
    $queryResize  = "ALTER DATABASE [{0}] MODIFY FILE ( NAME = N'{1}', SIZE = {2}KB )" -f $Database, $databaseLogFileName, (($TargetSize / 1KB) -as [System.Int64])

    # Get and show the transaction log state
    $state = Get-SqlDbTrxLogState @sqlConnection
    Write-Output $state

    while (($state.FileSize -gt $TargetSize -or $state.VlfCount -gt 8) -and ($Auto.IsPresent -or $PSCmdlet.ShouldProcess($state.LogFile, $queryShrink)))
    {
        Write-Verbose '[Invoke-SqlDbTrxShrink] Invoke database transaction log backup'
        Invoke-DbaQuery @sqlConnection -Query $queryBackup | Out-Null

        Write-Verbose '[Invoke-SqlDbTrxShrink] Invoke transaction log shrink command'
        Invoke-DbaQuery @sqlConnection -Query $queryShrink | Out-Null

        # Get and show the transaction log state
        $state = Get-SqlDbTrxLogState @sqlConnection
        Write-Output $state
    }

    if ($state.FileSize -lt $TargetSize -and ($Auto.IsPresent -or $PSCmdlet.ShouldProcess($state.Logfile, $queryResize)))
    {
        Write-Verbose '[Invoke-SqlDbTrxShrink] Set database transaction log to the target'
        Invoke-DbaQuery @sqlConnection -Query $queryResize

        # Get and show the transaction log state
        $state = Get-SqlDbTrxLogState @sqlConnection
        Write-Output $state
    }
}
