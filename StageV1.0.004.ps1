
#############################################################################
# CenterEdge Software Support Stage Setup                                   #
# Written By: Aaron Adams(A2)                                               #
# Date Completed: Saturday July 22, 2017                                    #
#############################################################################


Set-Location Cert:/Localmachine/My
Function Get-IniContent {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$FilePath
    )
    Begin {
        $ini = New-Object System.Collections.Hashtable
    }
    Process {
        Try {
            Switch -regex -file $FilePath
            {
                '^\[(.+)\]$' # Match sections. Store name as key, create hashtable as value.
                {
                    $section = $matches[1]
                    $ini[$section] = New-Object System.Collections.Hashtable
                    $CommentCount = 0
                }
                '^(;.*)$' # Match comments and store them in a "No-Section" hashtable.
                {
                    If (!($section))
                    {
                        $section = 'No-Section'
                        $ini[$section] = New-Object System.Collections.Hashtable
                    }
                    $value = $matches[1]
                    $CommentCount = $CommentCount + 1
                    $name = 'Comment' + $CommentCount
                    $ini[$section][$name] = $value
                }
                '(.+?)\s*=\s*(.*)' # Match keys and store as a key/value pair in the section hashtable.
                {
                    If (!($section))
                    {
                        $section = 'No-Section'
                        $ini[$section] = New-Object System.Collections.Hashtable
                    }
                    $name = $matches[1]
                    $value = $matches[2]
                    $ini[$section][$name] = $value
                }
            }
            Return $ini
        }
        Catch {
            $ErrorTypeName = $_.Exception.GetType().Name
            $ErrorMessage = $_.Exception.Message
            $ErrorItem = $_.Exception.ItemName
        }
    }
    End {
    }
}
$PFSConnect = Get-inicontent C:\PFSCommon\PFSconnect.ini
$Password = $PFSConnect.SQL2000.Password
$Username = $PFSConnect.SQL2000.UserID
$Certificate = Get-ChildItem
$CertificateName = Read-Host -Prompt 'Enter Site Certificate Name'
$cert = $Certificate | Where {$_.Subject.Contains($CertificateName)} | Select-Object -First 1
If ($cert -eq $null) {
    write-host "Certificate $CertificateName Not Found"
} ElseIf ($cert.NotAfter -lt [DateTime]::Now) {
    Write-host "Certificate $CertificateName Expired"
    cd C:\PFSCommon
    Start-Process advcertinstall.exe
    exit
} Else {
    Write-Host "Certificate Found! Starting Stage Cert Config"
    cd C:/CenterEdge/Install
    ./StageCertConfig.ps1 $CertificateName   
function Invoke-SqlCommand() {
    [cmdletbinding(DefaultParameterSetName="integrated")]Param (
        [Parameter(Mandatory=$true)][Alias("Serverinstance")][string]$Server,
        [Parameter(Mandatory=$true)][string]$Database,
        [Parameter(Mandatory=$true, ParameterSetName="not_integrated")][string]$Username,
        [Parameter(Mandatory=$true, ParameterSetName="not_integrated")][string]$Password,
        [Parameter(Mandatory=$true)][string]$Query,
        [Parameter(Mandatory=$false)][int]$CommandTimeout=0
    )
    
    $connstring = "Server=$Server; Database=$Database; "
    If ($PSCmdlet.ParameterSetName -eq "not_integrated") { $connstring += "User ID=$username; Password=$password;" }
    ElseIf ($PSCmdlet.ParameterSetName -eq "integrated") { $connstring += "Trusted_Connection=Yes; Integrated Security=SSPI;" }
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connstring)
    $connection.Open()
    
    $command = $connection.CreateCommand()
    $command.CommandText = $Query
    $command.CommandTimeout = $CommandTimeout
    
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | out-null
    
    If ($dataset.Tables[0] -ne $null) {$table = $dataset.Tables[0]}
    ElseIf ($table.Rows.Count -eq 0) { $table = New-Object System.Collections.ArrayList }
    
    $connection.Close()
    return $table
}
$server = "localhost"
$db = "CenterEdge"
$sql = "TRUNCATE TABLE WebCloudUpdates"
$Insert = "insert into weboptions(keyno, optionname, optionvalue, typename) Values('1','CloudSyncCorpOnly','False', 'system.boolean')"
Invoke-SqlCommand -Server $server -Database $db -Query $sql | Format-Table
Invoke-Sqlcommand -Server $server -Database $db -Query $Insert | Format-Table
Start-Sleep 2
Clear
}
Clear