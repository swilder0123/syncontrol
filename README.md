# syncontrol
Some Azure Synapse automation scripts

- Set-AzSynDBState - allows automating the startup and shutdown of Azure Synapse DW DBs from Azure Automation. 
- Set-AzSynDBScale - (pending) allows throttling up or down the scale of Azure Synapse DW DBs from Azure Automation. THIS SCRIPT IS STILL UNDER CONSTRUCTION.

An Azure automation object called AzureRunAsConnection must exist. It should have at least Contributor level permissions on the resource group containing the DB pools you want to control. (It may be possible to grant more fine grained control if needed.)

Each script has parameters which are self-documenting.
