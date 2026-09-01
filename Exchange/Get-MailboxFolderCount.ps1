#Requires -Module ExchangeOnlineManagement
Function Get-MailboxFolderCount {
    <#
.SYNOPSIS
Retrieve mailbox folder count and sizes for the specified mailbox.

.DESCRIPTION
Retrieve mailbox folder count and sizes for the specified mailbox.

.NOTES
Author: 
    DS
Notes:
    Revision 03
Revision:
    V01: 2021.11.10 by DS :: First revision.
    V02: 2022.02.15 by DS :: Updated for on-prem Exchange, added script header.
    V03: 2026.09.01 by DS :: Back to Exchange online. Minor overhaul for first GitHub publish.
Call From:
    PowerShell v5.1+ w/ ExchangeOnlineManagement module

.PARAMETER Identity
Target mailbox for which to retrieve folder count and sizes.

.PARAMETER Archive
Specifies that archive mailbox will be targeted.

.PARAMETER Detail
Return detailed list of folder structure and size for mailbox.

.EXAMPLE
Get-MailboxFolderCount -Identity James.Kirk@starfleet.gov
Retrieve the mailbox folder count and sizes for the mailbox 'James.Kirk@starfleet.gov'

.EXAMPLE
Get-MailboxFolderCount -Identity James.Kirk@starfleet.gov -Archive
Retrieve the archive mailbox folder count and sizes for the mailbox 'James.Kirk@starfleet.gov'

.EXAMPLE
Get-MailboxFolderCount -Identity James.Kirk@starfleet.gov -Detail
Retrieve detailed mailbox folder list and sizes for the mailbox 'James.Kirk@starfleet.gov'
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        $Identity,

        [Parameter(Mandatory = $False)]
        [switch]$Archive = $False,

        [Parameter(Mandatory = $False)]
        [switch]$Detail = $False
    )

    # connect to exchange online if needed
    if (!(Get-Command -Name 'Get-Mailbox')) {
        Connect-ExchangeOnline
    }

    # parameters for 'Get-MailboxStatistics' and 'Get-MailboxFolderStatistics'
    $param = @{
        'Identity' = $Identity
    }
    if ($Archive) {
        $param.Add('Archive', $true)
    }

    # mailbox/archive stats
    try {
        $mailbox = Get-MailboxStatistics @param
    }
    catch {
        throw $Error[0].Exception.Message
    }

    # mailbox/archive folder stats
    try {
        $folders = Get-MailboxFolderStatistics @param
    }
    catch {
        throw $Error[0].Exception.Message
    }

    # mailbox/archive folders and count
    if ($Detail -eq $False) {
        $select = @{
            'Property' = @(
                @{N = "Mailbox"; E = { $Identity } },
                @{N = "FolderCount"; E = { $folders.Count } },
                @{N = "InboxFolderCount"; E = {
                        ($folders | Where-Object { $_.FolderPath -like "`/Inbox`/*" }).Count } 
                },
                @{N = "TotalItemSize"; E = { $_.TotalItemSize } },
                @{N = "InboxSize"; E = {
                        ($folders | Where-Object { $_.FolderPath -eq "`/Inbox" }).FolderAndSubfolderSize
                    } 
                }
            )
        }
        $mailbox | Select-Object @select
    }

    # detailed list of folder sizes for mailbox/archive
    Elseif ($Detail -eq $True) {
        $select = @{
            'Property' = @(
                'FolderPath',
                'ItemsInFolderAndSubfolders',
                @{N = "FolderAndSubfolderSizeMB"; E = {
                        [Math]::Round(
                            (($_.FolderAndSubfolderSize.ToString().Split('(') | Where-Object {
                                    $_ -like "*bytes*"
                                }).Replace('bytes)', '').Replace(',', '')) / 1MB
                        )
                    } 
                }
            )
        }
        $folders | Select-Object @select
    }
}