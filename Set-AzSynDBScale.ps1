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
        Name of the resource group that contains the data warehouse.
    .PARAMETER ServerName
        Name of the Azure SQL Server that contains the data warehouse.
    .PARAMETER DatabaseName
        Name of the data warehouse database.
    .PARAMETER DesiredScale
        Desired state of the data warehouse. Can be NoChange, Up, Down, Maximum or Minimum, or ScaleObjective; default is NoChange.
    .PARAMETER ScaleSteps
        Desired scale steps up or down from the current scale, default is 1. Only used if DesiredState is Up or Down.
    .PARAMETER ScaleObjective
        Desired scale objective by name. Only used if DesiredScale is ScaleObjective.
    .PARAMETER $AzureEnvironment
        Azure Cloud environment which will be used in the connection. Default is AzureCloud.
#>

param
(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $ServerName,

    [Parameter(Mandatory = $true)]
    [string] $DatabaseName,

    [validateSet("NoChange", "Up", "Down", "Maximum", "Minimum", "ScaleObjective")]
    [string] $DesiredScale = "NoChange",
    
    [int] ScaleSteps = 1,
    
    [string] ScaleObjective,

    [string] $AzureEnvironment = "AzureCloud"
)

<#
    .SYNOPSIS
        Connects to Azure and sets the provided subscription. This function assumes that you have created the default automation connection on account creation.
 #>
function Login-AzureAutomation {
    try {
        $RunAsConnection = Get-AutomationConnection -Name "AzureRunAsConnection"

        Write-Output "Logging in to Azure ($AzureEnvironment)..."
        
        if (!$RunAsConnection.ApplicationId) {
            $ErrorMessage = "Connection 'AzureRunAsConnection' is incompatible type."
            throw $ErrorMessage            
        }
        
        Connect-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $RunAsConnection.TenantId `
            -ApplicationId $RunAsConnection.ApplicationId `
            -CertificateThumbprint $RunAsConnection.CertificateThumbprint `
            -Environment $AzureEnvironment

        Select-AzureRmSubscription -Subscription $RunAsConnection.SubscriptionID  | Write-Verbose
       
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
$location = $database.location

#Retrieve a table of the various service levels
$serviceObjectives = Get-AzSqlServerServiceObjective -Location $location | where Edition -eq DataWarehouse | select ServiceObjectiveName, Capacity | sort Capacity
$currentObjectiveName = $(serviceObjectives | where ServiceObjectiveName -eq $database.CurrentServiceObjectiveName)

# Figure out if we can scale up or down
$currentObjectiveLevel = $serviceObjectives.IndexOf($currentObjectiveName)
$targetObjectiveLevel = $currentObjectiveLevel
$maxObjectiveLevel = $serviceObjectives.GetUpperBound(0)
$minObjectiveLevel = 0

# Based on the current ServiceObjectiveLevel, the switch will set a new targetObjectiveLevel. Some simple logic will test if we have a boundary exception...
switch($DesiredScale) {
  "NoChange" {$targetObjectiveLevel = $currentObjectiveLevel}
  "Up"       {if(($targetObjectiveLevel += $ScaleSteps) -gt $maxObjectiveLevel) {$targetObjectiveLevel = $maxObjectiveLevel}}
  "Down"     {if(($targetObjectiveLevel -+ $ScaleSteps) -lt $minObjectiveLevel)) {$targetObjectiveLevel = $minObjectiveLevel}}
  "Maximum"  {$targetObjectiveLevel =  $maxObjectiveLevel}
  "Minimum"  {$targetObjectiveLevel =  $minObjectiveLevel}
  "ScaleObjective" {
    #make sure the passed-in service objective is in the list.
    if(!(serviceObjectives | where ServiceObjectiveName -eq $ServiceObjective))
    {
      throw "Specified scale objective was not found in $location."
    }
    else {
      # find the index of the entry specified
      $targetObjectiveLevel = $serviceObjectives.IndexOf($ServiceObjective)
    }
  }
}

# This indexes into the table so we can figure out what the name of the new ServiceObjectiveLevel is...
$targetObjective = $serviceObjectives[$targetObjectiveLevel]
$targetObjectiveName = $targetObjective.ServiceObjectiveName

if($database.SkuName -ne "DataWarehouse")
{
    throw "Only databases of type DataWarehouse support being scaled."
}

Write-Output "Database $DatabaseName current service objective is: $currentObjectiveName, the desired service objective is $targetObjectiveName."

if($targetObjectiveLevel -eq $currentObjectiveLevel)
{
    write-output "No change was specified...the current service objective of $currentObjectiveName will not be changed."
}
else 
{
    try {
        $status = Set-AzSqlDatabase -DatabaseName $DatabaseName -RequestedServiceObjectiveName $targetObjectiveName -ServerName $ServerName
    }
    catch {
        write-output "The scale attempt failed:"
        write-output "  Datebase Name: $($ServerName/$DatabaseName)
        throw $_.Exception
    }
    write-output $status
}
