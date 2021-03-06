<#
    .SYNOPSIS
        Test the SQL connection to a target SQL Server.

    .DESCRIPTION
        Test the connection to a SQL Server. Currently only the .NET SqlClient
        provider is supported. In the quiet mode, the command only returns $true
        if the connection was successful or $false if any error occured. In the
        normal mode, a result object with details about the SQL Server is
        returned or an exception will be thrown.

    .INPUTS
        None.

    .OUTPUTS
        SqlServerFever.TestConnectionResult. Result of the test connection.

    .EXAMPLE
        PS C:\> Test-SqlConnection -ComputerName 'SQL01'
        Test the SQL connection to SQL01 with Windows authentication.

    .EXAMPLE
        PS C:\> Test-SqlConnection -ComputerName 'SQL01' -Credential 'sa'
        Test the SQL connection to SQL01 with SQL authentication.

    .EXAMPLE
        PS C:\> Test-SqlConnection -ComputerName 'SQL01' -Database 'Demo0'
        Test the SQL connection to SQL01 to the database Demo0.

    .EXAMPLE
        PS C:\> Test-SqlConnection -ComputerName 'SQL01' -Encrypt
        Test the SQL connection to SQL01 with encryption.

    .LINK
        https://github.com/claudiospizzi/SqlServerFever
#>
function Test-SqlConnection
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param
    (
        # SQL instance name.
        [Parameter(Mandatory = $true)]
        [System.String]
        $SqlInstance,

        # SQL Login. If not specified, use integrated security.
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $SqlCredential,

        # Database to connect, be default master.
        [Parameter(Mandatory = $false)]
        [System.String]
        $Database = 'master',

        # The SQL client provider to use for the test.
        [Parameter(Mandatory = $false)]
        [ValidateSet('SqlClient')]
        [System.String]
        $Provider,

        # Option to enable encryption for the SQL Server connection.
        [Parameter(Mandatory = $false)]
        [Switch]
        $Encrypt,

        # Option to return only true or false.
        [Parameter(Mandatory = $false)]
        [Switch]
        $Quiet
    )

    # Default connection string with target server and database.
    $connectionStringReal = 'Data Source={0}; Initial Catalog={1}' -f $SqlInstance, $Database
    $connectionStringInfo = $connectionStringReal

    # Depending on the credential parameter, append the user id and password or
    # the integrated security note.
    if ($PSBoundParameters.ContainsKey('SqlCredential'))
    {
        $connectionStringReal += '; User ID={0}; Password={1}' -f $SqlCredential.UserName, $SqlCredential.GetNetworkCredential().Password
        $connectionStringInfo += '; User ID={0}; Password=***' -f $SqlCredential.UserName
    }
    else
    {
        $connectionStringReal += '; Integrated Security=true'
        $connectionStringInfo += '; Integrated Security=true'
    }

    # Finally, force an encrypted connection.
    if ($Encrypt.IsPresent)
    {
        $connectionStringReal += '; Encrypt=true'
        $connectionStringInfo += '; Encrypt=true'
    }

    Write-Verbose "SQL Connection String: $connectionStringInfo"

    $result = $null

    try
    {
        $sqlConnection = New-Object -TypeName 'System.Data.SqlClient.SqlConnection' -ArgumentList $connectionStringReal
        $sqlConnection.Open()

        try
        {
            $sqlCommandSession = New-Object -TypeName 'System.Data.SqlClient.SqlCommand' -ArgumentList "SELECT @@SPID, SYSTEM_USER, USER, @@SERVERNAME, @@SERVICENAME, @@VERSION, SERVERPROPERTY('Edition'), (SELECT create_date FROM sys.databases WHERE name = 'tempdb')", $sqlConnection
            $sqlReaderSession = $sqlCommandSession.ExecuteReader()

            if ($sqlReaderSession.Read())
            {
                if ($Quiet.IsPresent)
                {
                    return $true
                }
                else
                {
                    $result = [PSCustomObject] @{
                        PSTypeName       = 'SqlServerFever.TestConnectionResult'
                        ConnectionString = $connectionStringInfo
                        Id               = $sqlReaderSession[0]
                        Login            = $sqlReaderSession[1]
                        User             = $sqlReaderSession[2]
                        Protocol         = ''
                        Encryption       = ''
                        Server           = $sqlReaderSession[3]
                        Instance         = $sqlReaderSession[4]
                        Version          = ($sqlReaderSession[5] -as [System.String]).Split("`n")[0]
                        Edition          = $sqlReaderSession[6]
                        StartDate        = $sqlReaderSession[7]
                        Uptime           = [System.DateTime]::Now - $sqlReaderSession[7]
                    }
                }
            }
        }
        catch
        {
            if (-not $Quiet.IsPresent)
            {
                throw $_
            }
        }
        finally
        {
            if ($null -ne $sqlReaderSession)
            {
                $sqlReaderSession.Close()
                $sqlReaderSession.Dispose()
            }
        }

        if (-not $Quiet.IsPresent)
        {
            try
            {
                $sqlCommandConnection = New-Object -TypeName 'System.Data.SqlClient.SqlCommand' -ArgumentList "SELECT auth_scheme, encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID", $sqlConnection
                $sqlReaderConnection = $sqlCommandConnection.ExecuteReader()

                if ($sqlReaderConnection.Read())
                {
                    $result.Protocol   = $sqlReaderConnection[0]
                    $result.Encryption = $sqlReaderConnection[1]
                }
            }
            catch
            {
                Write-Warning "Error occured while getting connection information: $_"
            }
            finally
            {
                if ($null -ne $sqlReaderConnection)
                {
                    $sqlReaderConnection.Close()
                    $sqlReaderConnection.Dispose()
                }
            }
        }
    }
    catch
    {
        if (-not $Quiet.IsPresent)
        {
            throw $_
        }
    }
    finally
    {
        if ($null -ne $sqlConnection)
        {
            $sqlConnection.Close()
            $sqlConnection.Dispose()
        }
    }

    if ($Quiet.ISPresent)
    {
        return $false
    }
    elseif ($null -ne $result)
    {
        return $result
    }
}
