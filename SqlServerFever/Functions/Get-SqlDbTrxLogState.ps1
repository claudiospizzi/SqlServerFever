<#
    .SYNOPSIS
        Get the current state of a SQL Server database transaction log file.

    .DESCRIPTION
        This command will return the current state of a transaction log file,
        including the size and number of VLFs (Virtual Log Files).

    .EXAMPLE
        Get-SqlDbTrxLogState -SqlInstance 'SQL01' -Database 'AdventureWorks'
        This command will return the current state of the transaction log file
        of the AdventureWorks database on SQL01.

    .LINK
        https://github.com/claudiospizzi/SqlServerFever
#>
function Get-SqlDbTrxLogState
{
    [CmdletBinding()]
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

        # Database to get the transaction log state for.
        [Parameter(Mandatory = $true)]
        [System.String]
        $Database
    )

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

    # Query the SQL Server about the transaction log file.
    $logFile = Get-DbaDbFile @sqlConnection -Verbose:$false | Where-Object { $_.Type -eq 1 } | Select-Object -First 1
    $logInfo = Invoke-DbaQuery @sqlConnection -Query 'DBCC LOGINFO'

    # Show the current state of the database transaction log file.
    [PSCustomObject] @{
        PSTypeName  = 'SqlServerFever.DatabaseTransactionLogState'
        SqlInstance = $SqlInstance
        Database    = $Database
        LogFile     = $logFile.LogicalName
        VlfCount    = @($logInfo).Count
        FileSizeMB  = [System.Math]::Round($logFile.Size.Byte / 1MB, 2)
    }
}
