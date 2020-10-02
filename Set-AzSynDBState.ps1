<#PSScriptInfo

.VERSION 1.0

.GUID e95af45c-3e0f-4b29-938a-752fd7ef176a

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
        Changes the state of an Azure SQL Data Warehouse to the desired state.

    .Description
        Changes the state of an Azure SQL Data Warehouse to the desired state.

    .PARAMETER ResourceGroupName
        Name of the resource group that contains the data warehouse.

    .PARAMETER ServerName
        Name of the Azure SQL Server that contains the data warehouse.

    .PARAMETER DatabaseName
        Name of the data warehouse database.

    .PARAMETER DesiredState
        Desired state of the data warehouse. Can be Paused or Online, default is Paused.

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

    [validateSet("Paused", "Online")]
    [string] $DesiredState = "Paused",

    [string] $AzureEnvironment = "AzureCloud"
)

<#
    .SYNOPSIS
        Connects to Azure and sets the provided subscription.
 #>
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

write-output $database

if($database.Edition -ne "DataWarehouse")
{
    throw "Only databases of type DataWarehouse support being paused."
}

Write-Output "Database $DatabaseName current state is $($database.Status), the desired state $DesiredState."

if(($DesiredState -eq "Paused") -and ($database.Status -eq "Online"))
{
    Write-Output "Pausing the database."
    Suspend-AzureRmSqlDatabase @param
}

if(($DesiredState -eq "Online") -and ($database.Status -eq "Paused"))
{
    Write-Output "Starting the database."
    Resume-AzureRmSqlDatabase @param
}
