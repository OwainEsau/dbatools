﻿#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Stop-DbaEndpoint {
<#
    .SYNOPSIS
        Stops endpoints on a SQL Server instance.

    .DESCRIPTION
        Stops endpoints on a SQL Server instance.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances. This can be a collection and receive pipeline input to allow the function
        to be executed against multiple SQL Server instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Endpoint
        Only stop specific endpoints.

    .PARAMETER AllEndpoints
        Stop all endpoints on an instance, ignoring the packaged endpoints: AlwaysOn_health, system_health, telemetry_xevents.

    .PARAMETER InputObject
        Internal parameter to support piping from Get-Endpoint

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Endpoint
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Stop-DbaEndpoint

    .EXAMPLE
        PS C:\> Stop-DbaEndpoint -SqlInstance sqlserver2012 -AllEndpoints

        Stops all endpoints on the sqlserver2014 instance.

    .EXAMPLE
        PS C:\> Stop-DbaEndpoint -SqlInstance sqlserver2012 -Endpoint endpoint1,endpoint2

        Stops the endpoint1 and endpoint2 endpoints.

    .EXAMPLE
        PS C:\> Get-Endpoint -SqlInstance sqlserver2012 -Endpoint endpoint1 | Stop-DbaEndpoint

        Stops the endpoints returned from the Get-Endpoint function.

#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string[]]$EndPoint,
        [switch]$AllEndpoints,
        [parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Endpoint[]]$InputObject,
        [switch]$EnableException
    )

    process {
        if ((Test-Bound -ParameterName SqlInstance) -And (Test-Bound -Not -ParameterName Endpoint, AllEndpoints)) {
            Stop-Function -Message "You must specify AllEndpoints or Endpoint when using the SqlInstance parameter."
            return
        }
        foreach ($instance in $SqlInstance) {
            $InputObject += Get-DbaEndpoint -SqlInstance $instance -SqlCredential $SqlCredential -EndPoint $Endpoint
        }

        foreach ($ep in $InputObject) {
            try {
                if ($Pscmdlet.ShouldProcess($ep.Parent.Name, "Stopping $ep")) {
                    $ep.Stop()
                    $ep
                }
            }
            catch {
                Stop-Function -Message "Failure" -ErrorRecord $_ -Continue
            }
        }
    }
}