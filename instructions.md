# Creating the Automation Account

Runbooks are hosted within an Azure Automation account. You can create an automation account in a new or existing Resource Group. The following table discusses each option in a little more detail:

# Creating the Automation Account

Runbooks are hosted within an Azure Automation account. You can create an automation account in a new or existing Resource Group. The following table discusses each option in a little more detail:
| Item | Description |
|:---|:---|
| **Name** |  Use a descriptive name which meets Azure general naming requirements |
| **Subscription** | Will default to your current subscription. If you have another subscription under your user context, they will appear in the pulldown menu |
| **Resource Group**| Choose an existing Resource Group from the pulldown menu or click **Create**|
| **Location** | Select the Location (Azure Region) for your new account. Note that if you want to pair your Automation Account with an existing Log Analytics namespace, you need to select the location where the existing Log Analytics workspace resides.|
| **Create Azure Run As account**| Select Yes to automatically grant your runbooks permissions to perform common Azure administrative tasks.|

**NOTE:** In many cases this option will not succeed because of access privileges in Azure, Azure AD, or both. In this case, the automation account will be created but the security principal will need to be added manually. **Read the security recommendations in the next section.**

## Understanding the Runbook User Context

A runbook can be run in two ways:

- On an Azure provided runbook worker (suitable for Azure cloud service automation tasks)
- On a hybrid runbook worker (suitable for any cloud service automation or on-prem automation task)

In either case, a runbook will be dispatched to a host system which does not have access to the user context you would use to test a script on your local console. A Powershell script which runs on your local console without problems will typically fail on Azure Automation unless you:

1. Use an Azure Automation Run As account (or other service principal)
2. Grant access for that principal to make changes on the item(s) you are trying to manage in Azure.

If there is a need to create an Automatino Run As account manually, or if you would like to review other aspects of managing these accounts, please consult this reference: [Manage an Azure Automation Run As account](https://docs.microsoft.com/en-us/azure/automation/manage-runas-account).

## Managing Run As Account Scope

By default, the automation account is given Contributor access at the subscription level. Because only a subscription owner can create an account with this permission and scope, it may be necessary to create the account manually.

It may also be desirable to &quot;de-scope&quot; the automation account. This can be done by:

- Erasing or de-privileging the account at subscription scope (e.g., removing the role permission assignment for the subscription)
- Establishing permissions at a more granular scope level (e.g., granting the Contributor role assignment at the resource group level)

# Configuring the Runbooks

Once the Automation account is set up, and the automation Run As account and connection are ready, it&#39;s time to load the runbook. To do so, simply click the Runbooks option in the left side menu.

\&gt;\&gt; Then on the top menu bar, click **Create a runbook:**

Enter the appropriate settings. Make sure the runbook type is PowerShell, not PowerShell workflow:

Once the runbook is created, you can copy script into it. To do so, find and click:

Finally, paste the script into the editing window. You can make edits, save, publish and/or run (test) the workbook in this view:

|**Item**|**Description**|
|:---|:---|
|**Name**|Use a descriptive name which meets Azure general naming requirements|
|**Subscription**|Will default to your current subscription. If you have another subscription under your user context, they will appear in the pulldown menu|
|**Resource Group**|Choose an existing Resource Group from the pulldown menu or click **Create new**|
|**Location**|Select the Location (Azure Region) for your new account. Note that if you want to pair your Automation Account with an existing Log Analytics namespace, you need to select the location where the existing Log Analytics workspace resides.|
|**Create Azure Run As account**|Select Yes to automatically grant your runbooks permissions to perform common Azure administrative tasks.|

**NOTE:** In many cases this option will not succeed because of access privileges in Azure, Azure AD, or both. In this case, the automation account will be created but the security principal will need to be added manually.**

**Read the security recommendations in the next section.**

## Understanding the Runbook User Context

A runbook can be run in two ways:

- On an Azure provided runbook worker (suitable for Azure cloud service automation tasks)
- On a hybrid runbook worker (suitable for any cloud service automation or on-prem automation task)

In either case, a runbook will be dispatched to a host system which does not have access to the user context you would use to test a script on your local console. A Powershell script which runs on your local console without problems will typically fail on Azure Automation unless you:

1. Use an Azure Automation Run As account (or other service principal)
2. Grant access for that principal to make changes on the item(s) you are trying to manage in Azure.

If there is a need to create an Automatino Run As account manually, or if you would like to review other aspects of managing these accounts, please consult this reference: [Manage an Azure Automation Run As account](https://docs.microsoft.com/en-us/azure/automation/manage-runas-account).

## Managing Run As Account Scope

By default, the automation account is given Contributor access at the subscription level. Because only a subscription owner can create an account with this permission and scope, it may be necessary to create the account manually.

It may also be desirable to &quot;de-scope&quot; the automation account. This can be done by:

- Erasing or de-privileging the account at subscription scope (e.g., removing the role permission assignment for the subscription)
- Establishing permissions at a more granular scope level (e.g., granting the Contributor role assignment at the resource group level)

# Configuring the Runbooks

Once the Automation account is set up, and the automation Run As account and connection are ready, it&#39;s time to load the runbook. To do so, simply click the Runbooks option in the left side menu.

\&gt;\&gt; Then on the top menu bar, click **Create a runbook:**

Enter the appropriate settings. Make sure the runbook type is PowerShell, not PowerShell workflow.

Once the runbook is created, you can copy script into it. To do so, find and click the Edit button (pencil).

Finally, paste the script into the editing window. You can make edits, save, publish and/or run (test) the workbook in this view.


