// =============================================================================
// ENTRA ID KERBEROS (AADKERB) - POST-DEPLOYMENT REQUIRED STEPS
// =============================================================================
// Bicep configures the storage account for AADKERB but the steps below are
// required ONCE per storage account after first deployment.
// Without these, users will see "not authorized" errors even with correct RBAC.
//
// ⚠️  REGIONAL NOTE FOR CLOUD-ONLY IDENTITIES:
//     Assigning RBAC to specific Entra cloud-only users/groups is only supported
//     in a LIMITED subset of Azure regions (NOT UK West or UK South).
//     Supported regions include: Australia Central, Brazil Southeast, France South,
//     Germany North, Norway West, Switzerland West, UAE Central, West India.
//     If your region is not in this list, use a DEFAULT share-level permission
//     (Storage File Data SMB Share Contributor for all authenticated users) instead
//     of per-group RBAC assignments, then enforce access via Windows ACLs.
//     MS Learn: https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable
//
// -----------------------------------------------------------------------------
// STEP 1 - REQUIRED: Grant Admin Consent to Azure Storage App
// -----------------------------------------------------------------------------
// The auto-generated Entra app for your storage account (named
// [Storage Account] <storageAccountName>.file.core.windows.net) requires
// tenant-wide admin consent for openid, profile, and User.Read permissions.
// This is a ONE-TIME step per Entra tenant — not per deployment.
// Skip if already granted for another AADKERB storage account in the same tenant.
//
// Option A - Azure Portal:
//   1. Open Entra ID > App registrations > All Applications
//   2. Find the app: [Storage Account] <storageAccountName>.file.core.windows.net
//   3. API permissions > Grant admin consent for <Directory Name>
//
// Option B - PowerShell:
// $azureStorageSPId = (Get-AzADServicePrincipal -ApplicationId 'e406a681-f3d4-42a8-90b6-c2b029497af1').Id
// $body = @{
//     clientId    = $azureStorageSPId
//     consentType = 'AllPrincipals'
//     resourceId  = $azureStorageSPId
//     scope       = 'User.Read'
// } | ConvertTo-Json
// Invoke-AzRestMethod -Uri 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants' -Method POST -Payload $body
//
// MS Learn: https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable
//
// -----------------------------------------------------------------------------
// STEP 2 - REQUIRED: Generate Kerberos Key
// -----------------------------------------------------------------------------
// This registers the storage account as a Kerberos service principal in Entra
// so it can issue tickets. Must be run after every fresh storage account deploy.
//
// New-AzStorageAccountKey `
//     -ResourceGroupName "<clientid>-<Region>-RG1" `
//     -AccountName "<storageAccountName>" `
//     -KeyName kerb1
//
// MS Learn: https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable
//
// -----------------------------------------------------------------------------
// STEP 3 - REQUIRED (AFTER RBAC PROPAGATES ~30 mins): Set NTFS Root Permissions
// -----------------------------------------------------------------------------
// ⚠️  CLOUD-ONLY IDENTITY WARNING: icacls does NOT work for cloud-only Entra
//     identities. Windows File Explorer ACL editing is also NOT supported.
//     For cloud-only users you MUST use one of the following methods:
//
//   Option A - Azure Portal:
//     Go to the file share > Browse > right-click folder > Manage access
//
//   Option B - RestSetAcls PowerShell module (recommended for automation):
//     Install-Module -Name RestSetAcls
//     # Connect using storage account key or SAS token, then set ACLs via REST
//
//   Option C - icacls / Windows File Explorer (HYBRID identities only):
//     Only works if users are synced from on-premises AD DS to Entra ID AND
//     the client has unimpeded connectivity to the on-premises domain controller.
//     Mount using storage account key, then:
//       icacls <MountedDriveLetter>: /grant "CREATOR OWNER:(OI)(CI)(IO)(M)"
//       icacls <MountedDriveLetter>: /grant "Authenticated Users:(RX)"
//       icacls <MountedDriveLetter>: /inheritance:r
//
// MS Learn (file-level permissions): https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-configure-file-level-permissions
// MS Learn (share-level permissions): https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-assign-share-level-permissions
// MS Learn (FSLogix + Entra ID):      https://learn.microsoft.com/en-us/fslogix/how-to-configure-profile-container-entra-id-hybrid
// =============================================================================


param clientid string
param Lowerclientid string = toLower(clientid)
param Region string //Region is used for namin context AZE, AZE2 and AZW
param LowerRegion string = toLower(Region) //Client naming for region to deploy to lowered to use for storage account name (AZE,AZE2,AZW)
param StorageAccountName string = '${Lowerclientid}${LowerRegion}files'
param location string = resourceGroup().location
param logAnalyticsWorkspaceId string = '/subscriptions/${subscription().subscriptionId}/resourcegroups/${clientid}-${Region}-RG1/providers/microsoft.operationalinsights/workspaces/${clientid}-${Region}-VMS-LAW'//Log analytics location to send the fileshare logs

//Backup components for file share deployment
param vaultname string = '${clientid}-${Region}-RSV'
param policyName string = '${clientid}-${Region}-FILE'

// RBAC - Azure Files share-level access
// Storage File Data SMB Share Elevated Contributor - for admins to set NTFS permissions
param adminGroupObjectId string
// Storage File Data SMB Share Contributor - for AVD end users
param avdUsersGroupObjectId string

var smbElevatedContributorRoleId = 'a7264617-510b-434b-a828-9731dc254ea7'
var smbContributorRoleId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'



resource StorageAccount_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: StorageAccountName
  location: location
  tags: {
    Company: clientid
    Technology: 'APF'
    Backup: '${clientid}files'
  }
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    largeFileSharesState: 'Enabled'
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
    }
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}


resource StorageAccountFileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: StorageAccount_resource
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {
        multichannel: {
          enabled: true
        }
        versions: 'SMB3.0;SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-128-GCM;AES-256-GCM'
      }
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 14
    }
  }
}


resource Fileshare_shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: StorageAccountFileService
  name: 'shares'
  properties: {
    accessTier: 'Premium'
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}


resource DiagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${clientid}${Region}sharediag'
  scope: StorageAccountFileService
  properties: {
    workspaceId: logAnalyticsWorkspaceId

    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Share-level RBAC - required for Entra ID Kerberos (AADKERB) access
// Elevated Contributor allows admins to mount and set NTFS/ACL permissions on the share
resource roleAssignment_admin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(StorageAccount_resource.id, adminGroupObjectId, smbElevatedContributorRoleId)
  scope: StorageAccount_resource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', smbElevatedContributorRoleId)
    principalId: adminGroupObjectId
    principalType: 'Group'
  }
}

// Contributor allows AVD users to read/write their profile data on the share
resource roleAssignment_avdUsers 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(StorageAccount_resource.id, avdUsersGroupObjectId, smbContributorRoleId)
  scope: StorageAccount_resource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', smbContributorRoleId)
    principalId: avdUsersGroupObjectId
    principalType: 'Group'
  }
}

//Backup of File share components if no backup needed comment these out

resource rsvault 'Microsoft.RecoveryServices/vaults@2024-10-01' existing = {
  name: vaultname
}

resource rsvault_policy 'Microsoft.RecoveryServices/vaults/backupPolicies@2024-10-01' existing = {
  parent: rsvault
  name: policyName
}

resource rsvault_policy_storageaccount 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2024-10-01' = {
  name: '${vaultname}/Azure/storagecontainer;Storage;${clientid}-${Region}-RG1;${StorageAccountName}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: StorageAccount_resource.id
  }

}

resource rsvault_policy_storageaccount_fileshare 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-10-01' = {
  parent: rsvault_policy_storageaccount
  name: 'AzureFileShare;shares'
  properties: {
    protectedItemType: 'AzureFileShareProtectedItem'
    sourceResourceId: StorageAccount_resource.id
    policyId: rsvault_policy.id
  }
  dependsOn: [
    StorageAccountFileService
    Fileshare_shares
  ]
}
