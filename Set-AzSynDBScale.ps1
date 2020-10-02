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
        Desired state of the data warehouse. Can be NoChange, Up, Down, Maximum or Minimum, default is NoChange.
    .PARAMETER ScaleSteps
        Desired scale steps up or down from the current scale, default is 1. Only used if DesiredState is Up or Down.
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

    [validateSet("NoChange", "Up", "Down", "Maximum", "Minimum")]
    [string] $DesiredScale = "NoChange",
    
    [int] ScaleSteps = 1,

    [string] $AzureEnvironment = "AzureCloud"
)

<#
    .SYNOPSIS
        Connects to Azure and sets the provided subscription.
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

#the switch will set the new targetLevel. It will detect if we have an out of boundary exception and set the result to the minimum or maximum.

switch($DesiredScale) {
  "NoChange" {#do nothing, this option allows us to run the script to see the current level}
  "Up"       {$targetObjectiveLevel += $ScaleSteps; if($targetObjectiveLevel -gt $maxObjectiveLevel){$targetObjectiveLevel = $maxObjectiveLevel}}
  "Down"     {$targetObjectiveLevel -+ $ScaleSteps; if($targetObjectiveLevel -lt $minObjectiveLevel){$targetObjectiveLevel = $minObjectiveLevel}}
  "Maximum"  {$targetObjectiveLevel =  $maxObjectiveLevel}
  "Minimum"  {$targetObjectiveLevel =  $minObjectiveLevel}
}

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
    Set-AzSqlDatabase -DatabaseName $database.DatabaseName -RequestedServiceObjectiveName $targetObjectiveName -ServerName $ServerName
}
