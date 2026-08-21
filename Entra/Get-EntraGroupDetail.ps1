#Requires -Version 7
#Requires -Module Microsoft.Entra.Authentication
Function Get-EntraGroupDetail {
    <#
.SYNOPSIS
Get Entra 'cloud only' group report.

.DESCRIPTION
Get Entra 'cloud only' group report. Contains member and owner counts.

.NOTES
Author: 
    DS
Notes:
    Revision 01
Revision:
    V01: 2026.08.21 by DS :: First published iteration.
Call From:
    PowerShell v7 w/ Microsoft.Graph modules

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Get-EntraGroupDetail
Retrieves all Entra groups with member and owner counts.

.EXAMPLE
Get-EntraGroupDetail -SearchString 'Adobe'
Searches Entra for groups with name like 'Adobe', returns member and owner counts.

.EXAMPLE
Get-EntraGroupDetail -SearchString 'Adobe' -CloudOnly
Searches Entra for 'cloud only' groups with name like 'Adobe', returns member and owner counts.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [string]$SearchString,

        [Parameter(Mandatory = $False)]
        [switch]$CloudOnly = $false
    )

    # connect to Entra if not already
    try {
        Get-EntraTenantDetail -ErrorAction Stop | Out-Null
    }
    catch {
        try {
            Write-Verbose "Connect to Entra"
            Connect-Entra -Scopes Group.Read.All, GroupMember.Read.All
        }
        Catch {
            Write-Host "$($Error[0].Exception.Message)"
            return
        }
    }

    # retrieve groups
    $param = @{
        'All' = $true
    }
    if ($SearchString) {
        $param.Add('SearchString', $SearchString)
    }
    $select = @{
        'Property' = @(
            'DisplayName',
            'Description',
            'Id',
            'OnPremisesSyncEnabled',
            'GroupTypes',
            'MailEnabled',
            'MailNickname',
            'SecurityEnabled',
            'Owners',
            'Members'
        )
    }
    $groups = Get-EntraGroup @param | Select-Object @select

    # limit to 'cloud only'
    if ($CloudOnly -eq $true) {
        $groups = $groups | Where-Object { $_.OnPremisesSyncEnabled -ne $true } | Select-Object @select
    }
    
    # 'main' loop to retrieve owner and member count for each group
    $i = 0
    foreach ($g in $groups) {
        try {
            $i++
            Write-Progress "Processing '$($g.DisplayName)'" -PercentComplete ($i / $groups.Count * 100)
        }
        catch {}

        # convert 'GroupTypes' to multi-valued string w/ values separated by '; '
        $t = ""
        $g.GroupTypes | ForEach-Object {
            $t += "$_; "
        }
        $g.GroupTypes = $t.TrimEnd('; ')

        # owners count
        try {
            $g.Owners = (Get-EntraGroupOwner -All -GroupId $g.Id -ErrorAction Stop).Count
        }
        catch {
            $g.Owners = 0
        }

        # members count
        try {
            $g.Members = (Get-EntraGroupMember -All -GroupId $g.Id -ErrorAction Stop).Count
        }
        catch {
            $g.Members = 0
        }
    }
    if ($groups) {
        $groups
    }
    else {
        Write-Host "No Entra groups matching search criteria"
    }
}