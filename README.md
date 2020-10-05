# Azure Synapse DataWarehouse Pause and Scale automation scripts 

Included with this project are two Azure Synapse automation scripts which are designed to work in an Azure Automation account:

|**Script Name**|**Description**|
|:---|:---|
| **Set-AzSynDBState** | Allows automating the startup and shutdown of Azure Synapse DW DBs from Azure Automation.|
| **Set-AzSynDBScale** | Allows throttling up or down the scale of Azure Synapse DW DBs from Azure Automation. This script has been validated in a working environment but may still have some rough edges.|

Each script has parameters which are self-documenting.

## Azure Automation account requirements
You need to create an Azure Automation account in your subscription.
> **Note ** See the [instructions](instructions.md) for more information on how to set up an automation account.

An Azure automation object called AzureRunAsConnection must exist. It should have at least Contributor level permissions on the resource group containing the DB pools you want to control. (It may be possible to grant more fine grained control if needed.) There are additional details in the instructions document.

## Azure Runbook Installation
TBD

## Azure Runbook Scheduling
TBD