﻿function Get-DbaAgReplica {
<#
    .SYNOPSIS
        Outputs the Availability Group(s)' Replica object found on the server.

    .DESCRIPTION
        Default view provides most common set of properties for information on the Availability Group(s)' Replica.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances. Server version must be SQL Server version 2012 or higher.

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.

    .PARAMETER AvailabilityGroup
        Specify the Availability Group name that you want to get information on.

    .PARAMETER Replica
        Specify the replica to pull information on, is dependent up name that you want to get information on.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: AG, HA, AvailabilityGroup, Replica
        Author: Shawn Melton (@wsmelton) | Chrissy LeMaire (@ctrlb)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaAgReplica

    .EXAMPLE
        PS C:\> Get-DbaAgReplica -SqlInstance sqlserver2014a

        Returns basic information on all the Availability Group(s) replica(s) found on sqlserver2014a

    .EXAMPLE
        PS C:\> Get-DbaAgReplica -SqlInstance sqlserver2014a -AvailabilityGroup AG-a

        Shows basic information on the replica(s) found on Availability Group AG-a on sqlserver2014a

    .EXAMPLE
        Get-DbaAgReplica -SqlInstance sqlserver2014a | Select-Object *

        PS C:\> Returns full object properties on all Availability Group(s) replica(s) on sqlserver2014a

#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(ValueFromPipeline)]
        [object[]]$AvailabilityGroup,
        [object[]]$Replica,
        [Alias('Silent')]
        [switch]$EnableException
    )

    process {
        foreach ($serverName in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $serverName -SqlCredential $SqlCredential -MinimumVersion 11
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            if ($server.IsHadrEnabled -eq $false) {
                Stop-Function -Message "Availability Group (HADR) is not configured for the instance: $serverName" -Target $serverName -Continue
            }

            $ags = $server.AvailabilityGroups
            if ($AvailabilityGroup) {
                $ags = $ags | Where-Object Name -in $AvailabilityGroup
            }

            foreach ($ag in $ags) {
                $replicas = $ag.AvailabilityReplicas
                foreach ($currentReplica in $replicas) {
                    if ($Replica -and $currentReplica.Name -notmatch $Replica) {
                        continue
                    }

                    Add-Member -Force -InputObject $currentReplica -MemberType NoteProperty -Name ComputerName -value $server.ComputerName
                    Add-Member -Force -InputObject $currentReplica -MemberType NoteProperty -Name InstanceName -value $server.ServiceName
                    Add-Member -Force -InputObject $currentReplica -MemberType NoteProperty -Name SqlInstance -value $server.DomainInstanceName

                    $defaults = 'ComputerName', 'InstanceName', 'SqlInstance', 'Parent as AvailabilityGroup', 'Name as Replica', 'Role', 'ConnectionState', 'RollupSynchronizationState', 'AvailabilityMode', 'BackupPriority', 'EndpointUrl', 'SessionTimeout', 'FailoverMode', 'ReadonlyRoutingList'
                    Select-DefaultView -InputObject $currentReplica -Property $defaults
                }
            }
        }
    }
}