<#
Functions:
    Public:
        CM01 - Add-PowerStigComputer
        CM02 - Get-PowerStigComputer
        CM03 - Set-PowerStigComputer
        CM04 - Remove-PowerStigComputer
#>

#region Private

#endregion Private

#region Public

#CM01
<#
.SYNOPSIS
Adds a new computer target to the PowerStig database

.DESCRIPTION
Adds a new computer target to the PowerStig database with the roles specified in the switches

.PARAMETER ServerName
Name of server to add

.PARAMETER OSVersion
Operating System installed on new server. Valid options are 2012R2 and 2016

.PARAMETER SqlInstance
SQL instance name that hosts the PowerStig database. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.PARAMETER DatabaseName
Name of the database that hosts the PowerStig tables. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.PARAMETER DomainController
Will flag the server as a domain controller. If member server is also marked, this switch will take precedence.

.PARAMETER MemberServer
Will flag the server as a member server. If domain controller is also marked, this switch will not take effect

.PARAMETER DNS
Will flag the server as a DNS server.

.PARAMETER IE
Will flag the server as having IE installed.

.EXAMPLE
Add-PowerStigComputer -ServerName DC2012Test -OSVersion 2012R2 -SqlInstance SQLTest -DatabaseName Master -DomainController -DNS -IE

#>
function Add-PowerStigComputer
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [switch]$DebugScript,

        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $sqlInstance -or $sqlInstance -eq '')
    {
        $sqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    

    $Query = "PowerSTIG.sproc_AddTargetComputer @TargetComputerName = `"$ServerName`""

    if($DebugScript)
    {
        Write-Host $query
    }
    $Results = Invoke-PowerStigSqlCommand -Query $Query -SqlInstance $SqlInstance -DatabaseName $DatabaseName
    return $Results 
    
}

#CM02
function Get-PowerStigComputer
{
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName="ByName")]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(ParameterSetName="GetAll")]
        [Switch]$All,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,
        
        [Parameter()]
        [String]$DatabaseName
        
    )
    DynamicParam {
        $ParameterName = 'Role'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.ParameterSetName = "ByRole"
        $AttributeCollection.Add($ParameterAttribute)
        $roleSet = Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin{
        $Role = $PSBoundParameters[$ParameterName]
    }

    process{
        $workingPath = Split-Path $PsCommandPath
        $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

        if($null -eq $SqlInstance -or $SqlInstance -eq '')
        {
            $SqlInstance = $iniVar.SqlInstanceName
        }
        if($null -eq $DatabaseName -or $DatabaseName -eq '')
        {
            $DatabaseName = $iniVar.DatabaseName
        }

    
        Switch($PSCmdlet.ParameterSetName)
        {
            "ByName" {
                $GetComputerName = "EXEC PowerSTIG.sproc_GetRolesPerServer @TargetComputer = $ServerName"
                if($DebugScript)
                {
                    Write-Host $GetComputerName
                }
                $RunGetComputerName = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $GetComputerName )
                $Output = $RunGetComputerName
            }
            "ByRole" {
                $Role = Convert-PowerStigRoleToSql -Role $Role
                $GetRoleData = "EXEC PowerSTIG.sproc_GetActiveRoles  @ComplianceType = $Role"
                if($DebugScript)
                {
                    Write-Host $GetRoleData
                }
                $RunGetRoleData = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $GetRoleData )
                $Output = $RunGetRoleData
            }
            "GetAll" {
                $GetAllServers = "EXEC PowerSTIG.sproc_GetActiveServers"
                if($DebugScript)
                {
                    Write-Host $GetAllServers
                }
                $RunGetAllServers = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $GetAllServers)
                $Output = $RunGetAllServers
            }
        }
        Return $OutPut
    }
}

#CM03
function Set-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter(Mandatory=$true,ParameterSetName="OS")]
        [ValidateSet('2012R2','2016','10')]
        [String]$osVersion,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,

        [Parameter()]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $SqlInstance -or $SqlInstance -eq '')
    {
        $SqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    elseif($PSCmdlet.ParameterSetName -eq "OS")
    {
        $UpdateComputer = "EXEC PowerSTIG.sproc_UpdateTargetOS @TargetComputer=`"$ServerName`",@OSName=`"$osVersion`""
        Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $UpdateComputer
    }
}

#CM04
function Remove-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter()]
        [Switch]$Force,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,

        [Parameter()]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $SqlInstance -or $SqlInstance -eq '')
    {
        $SqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    if(!($Force))
    {
        
        $readIn = Read-Host "This will remove $ServerName and all data related to the computer from the database. Continue?(Y/N)"
        do{
            if($readIn -eq "N")
            {
                Write-Host "Cancelling"
                Return
            }
            elseif($readIn -eq "Y")
            {
                $proceed = $true
            }
            else
            {
                $readIn = Read-Host "Invalid response. Do you want to remove $ServerName? (Y/N)"
            }
        }While($proceed -eq $false)
    }
    

    $deleteComputer = "EXEC PowerSTIG.sproc_DeleteTargetComputerAndData @TargetComputer = `'$ServerName`'"
    if($DebugScript)
    {
        Write-Host $deleteComputer
    }
    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $deleteComputer 

}


#endregion Public