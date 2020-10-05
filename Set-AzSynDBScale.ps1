<#PSScriptInfo
.VERSION 1.0
.GUID 23dd00fe-76a2-4113-be24-a9cdf5e77cdf
.AUTHOR dareynol (original), swilder (revisions)
.COMPANYNAME Microsoft Corporation
.COPYRIGHT (c) 2020 Microsoft. All rights reserved.
.TAGS Azure Data Warehouse Synapse
.LICENSEURI https://mit-license.org/
.PROJECTURI (none)
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES This project is modified from an original work at https://github.com/dcrreynolds/Set-AzureSQLDWState. It was changed to drop use of a deprecated module (Azure-Connection).
.PRIVATEDATA
#>

<#
    .SYNOPSIS
        Changes the scale of an Azure SQL Data Warehouse to the desired scale.
    .Description
        This routine is failsafe. Any attempt to underscale or overscale will be automatically handled with no data exception.
    .PARAMETER ResourceGroupName
        Name of the resource group that contains the data warehouse DB.
    .PARAMETER ServerName
        Name of the Azure SQL Server that controls the data warehouse DB.
    .PARAMETER DatabaseName
        Name of the data warehouse DB.
    .PARAMETER ScaleOperation
        Desired state of the data warehouse. Can be ScaleUp, ScaleDown, or ScaleObjective.
    .PARAMETER ScaleSteps
        Desired scale steps up or down from the current scale, default is 1, allowed range is 0..100. Ignored unless ScaleOperation is ScaleUp or ScaleDown.
    .PARAMETER ScaleObjective
        Desired scale objective by name. Will be confirmed against available ServiceObjectives list for database. Ignored unless ScaleOperation is ScaleObjective.
    .PARAMETER WhatIf
        Run the script but do not execute the scale action.
    .PARAMETER ShowPlan
        Show the current and target scale (service) levels. Automatically specified if you choose WhatIf, there is no error if you specify both.
    .PARAMETER $AzureEnvironment
        Azure Cloud environment which will be used in the connection. Default is AzureCloud. This script has not been tested on other Azure cloud environments.
#>

param
(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $ServerName,

    [Parameter(Mandatory = $true)]
    [string] $DatabaseName,

    [Parameter(Mandatory = $true)]
    [validateSet("ScaleUp","ScaleDown","ScaleObjective")]
    [string] $ScaleOperation,
    
    [validateRange(0,100)]
    [int]    $ScaleSteps = 1,
    
    [string] $ScaleObjective,

    [switch] $WhatIf,

    [switch] $ShowPlan,

    [string] $AzureEnvironment = "AzureCloud"
)

<#
    .SYNOPSIS
        Connects to Azure and sets the provided subscription. This function assumes that you have created the default automation connection on account creation.
#>

#region Login-AzureAutomation
function Login-AzureAutomation {
    try {
        
        $RunAsConnection = Get-AutomationConnection -Name 'AzureRunAsConnection' 
        write-verbose $RunAsConnection
        
        Write-Output "Logging in to Azure ($AzureEnvironment)..."
        
        if (!$RunAsConnection.ApplicationId) {
            $ErrorMessage = "Connection 'AzureRunAsConnection' is incompatible type."
            throw $ErrorMessage            
        }
        
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $RunAsConnection.TenantId `
            -ApplicationId $RunAsConnection.ApplicationId `
            -CertificateThumbprint $RunAsConnection.CertificateThumbprint `
            -Environment $(Get-AzureRmEnvironment -Name $AzureEnvironment)

        Select-AzureRmSubscription -SubscriptionId $RunAsConnection.SubscriptionID  | Write-Verbose
       
    } catch {
        if (!$RunAsConnection) {
            $RunAsConnection | fl | Write-Output
            Write-Output $_.Exception
            $ErrorMessage = "Connection 'AzureRunAsConnection' not found."
            throw $ErrorMessage
        }

        throw $_.Exception
    }
}
#endregion

Import-Module "AzureRM.Profile" -ErrorAction Stop
Import-Module "AzureRM.Sql" -ErrorAction Stop

# Use the built-in Azure connection to connect to Azure
try {
    Login-AzureAutomation
}
catch {
    throw $_.Exception
}

# Splat the parameters to pass to the DBW
$param = @{
    ResourceGroupName = $ResourceGroupName
    ServerName = $ServerName
    DatabaseName = $DatabaseName
    ErrorAction = "Stop"
}

$database = Get-AzureRmSqlDatabase @param

# We have to create custom collection because the default list isn't sortable...
$serviceObjectiveList = New-Object System.Collections.ArrayList

# Retrieve a table of the various service levels
# $serviceObjectives = Get-AzureRmSqlServerServiceObjective -Location $location | where Edition -eq DataWarehouse | select ServiceObjectiveName, Capacity | sort Capacity
try {
$serviceObjectiveSet = Get-AzureRmSqlServerServiceObjective `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $DatabaseName `
    | Where ServiceObjectiveName -like "DW*"
}
catch {
    write-output $_.Exception
}

# Build a trimmed, sortable Service Objective List we can index into...
foreach ($serviceObjective in $serviceObjectiveSet)
{ 
    $serviceObjective | Write-Verbose
    
    $thisObjective = New-Object System.Object
    $serviceObjectiveName = $serviceObjective.ServiceObjectiveName
    # if there's  a 'c' on the end of the capacity string, keep this record, otherwise silently discard it.
    if($serviceObjectiveName.EndsWith("c"))
    {
        $thisObjective | Add-Member -MemberType NoteProperty -Name "ServiceObjectiveName" -Value $serviceObjectiveName
    
        # We need to parse the capacity out of the serviceObjectiveName string, this will give us an ordinal to sort on.
        # Pattern:
        #     (\DW) -- matching group which always == DW
        #     (\d+) -- the capacity level (3-4 digits)
        #     (c*)  -- there may or may not be a 'c' on the end, we will need to filter out the ones with no 'c'
        # The matching group is 1-based because the default matching group (0) == the entire matched value

        # Without getting crazy about types, we need a sortable number value, so left pad with zeroes...
        $capacity = $($serviceObjectiveName | select-string -Pattern "^(\DW)(\d+)(c*)`$").Matches.Groups[2].Value.PadLeft(6,'0')
        $thisObjective | Add-Member -MemberType NoteProperty -Name "Capacity" -Value $capacity
        
        $serviceObjectiveList.Add($thisObjective) | Out-Null
    }
}

# Sort the list by Capacity to make sure the scale levels are in the right order
$serviceObjectiveList = $serviceObjectiveList | Sort Capacity

# Double-check the presence of the current item on the list, we are also going to use this to index in...
$currentObjectiveName = $database.CurrentServiceObjectiveName

$serviceObjectiveList | write-output
$database | write-output
$currentObjectiveName | write-output
$serviceObjectiveList.ServiceObjectiveName.IndexOf($currentObjectiveName) | write-output

# if(!($($serviceObjectiveList | where ServiceObjectiveName -eq $currentObjectiveName))){
#     throw "ERROR: Can't find the current scale option on the list of available service levels."
# }

# Figure out if we can scale up or down by indexing into the table of available serviceobjectivelevels
try {
    $currentObjectiveLevel = $serviceObjectiveList.ServiceObjectiveName.IndexOf($currentObjectiveName)
    "The current ServiceObjectiveLevel is verified as: $currentObjectiveLevel" | write-output
}
catch {
    throw "ERROR: Can't find the current scale option on the list of available service levels."
}

# Unless we have a valid new targetObjectiveLevel, stay where we are....
$targetObjectiveLevel = $currentObjectiveLevel
$maxObjectiveLevel = $serviceObjectiveList.Count - 1
$minObjectiveLevel = 0

write-output "Target objective level before: $targetObjectiveLevel"

# Based on the current ServiceObjectiveLevel, the switch will set a new targetObjectiveLevel. Some simple logic will test if we have a boundary exception...
switch($ScaleOperation) {
  "ScaleUp"       {if(($targetObjectiveLevel += $ScaleSteps) -gt $maxObjectiveLevel) {$targetObjectiveLevel = $maxObjectiveLevel}}
  "ScaleDown"     {if(($targetObjectiveLevel -+ $ScaleSteps) -lt $minObjectiveLevel) {$targetObjectiveLevel = $minObjectiveLevel}}
  "ScaleObjective" {
        switch($ScaleObjective){
            "Maximum" {$targetObjectiveLevel = $maxObjectiveLevel}
            "Minimum" {$targetObjectiveLevel = $minObjectiveLevel}
            default   {
                # Make sure the passed-in service objective ($ScaleObjective parameter) is in the list.
                if(!($serviceObjectiveList | where ServiceObjectiveName -eq $ScaleObjective)) 
                {
                    throw "ERROR: Specified scale objective was not found in the the list of available levels for this database."
                }
                else {
                    # find the index of the entry specified
                    $targetObjectiveLevel = $serviceObjectiveList.ServiceObjectiveName.IndexOf($ScaleObjective)
                }
            }
        }
    }
}

Write-Verbose "Target objective level after: $targetObjectiveLevel"

# This indexes into the table so we can figure out what the name of the new ServiceObjectiveLevel is...
$targetObjectiveName = $serviceObjectiveList[$targetObjectiveLevel].ServiceObjectiveName

if($database.Edition -ne "DataWarehouse")
{
    throw "ERROR: Only databases of type DataWarehouse support being scaled."
}

if ($WhatIf -or $ShowPlan) {
    Write-Output "Desired scale action is $ScaleOperation"
    Write-Output "Database $DatabaseName current service objective is: $currentObjectiveName, the desired service objective is $targetObjectiveName."
}

if ($WhatIf -or ($targetObjectiveLevel -eq $currentObjectiveLevel))
{
    write-output "No change was specified...the current service objective of $currentObjectiveName will not be changed."
}
else {
    try {
        # $status = Set-AzSqlDatabase -DatabaseName $DatabaseName -RequestedServiceObjectiveName $targetObjectiveName -ServerName $ServerName
         $status = Set-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -RequestedServiceObjectiveName $targetObjectiveName -ServerName $ServerName
    }
    catch {
        write-output "The scale attempt failed on $ServerName for $DatabaseName."
        throw $_.Exception
    }
    write-output $status
}
