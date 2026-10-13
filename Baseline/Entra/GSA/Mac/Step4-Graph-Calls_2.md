# Step 4 - GSA macOS deployment: Graph calls, one at a time

Run in order. Every call is beta. Stop at the first error and paste it. Nothing here touches existing Defender or other policies:
reads are GETs, writes create four new objects with new names, and the only DELETEs are in the rollback section for those four objects.

Placeholders: `<TARGET_GROUP_ID>` (pilot group), `<BREAKGLASS_GROUP_ID>` (exclusion group), `<ID>` (id returned by the create call).
Intune supports excluding a user group only when the target is also a USER group.
Permissions: DeviceManagementConfiguration.ReadWrite.All, DeviceManagementScripts.ReadWrite.All, Group.Read.All.

## 0. Read-only checks
| # | Method | Path | Why |
|---|---|---|---|
| 0a | GET | `https://graph.microsoft.com/beta/groups?$filter=displayName eq 'SG-Intune-AUG-MAC-Pilot-Users'&$select=id,displayName` | get `<TARGET_GROUP_ID>` |
| 0b | GET | `https://graph.microsoft.com/beta/groups?$filter=displayName eq 'SG-Entra-AUG-CAP-BreakglassAccounts'&$select=id,displayName` | get `<BREAKGLASS_GROUP_ID>` |
| 0c | GET | `https://graph.microsoft.com/beta/groups/<TARGET_GROUP_ID>/members?$select=id,displayName,userPrincipalName` | confirm only the test user is in the pilot group, and that no break-glass account is |
| 0d | GET | `https://graph.microsoft.com/beta/groups/<BREAKGLASS_GROUP_ID>/members?$select=id,displayName,userPrincipalName` | see who gets excluded |
| 0e | GET | `https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?$select=id,name&$top=200` | look at existing system extension policies (e.g. Defender) before adding another |
| 0f | GET | `https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?$select=id,displayName&$top=200` | confirm none of the new names exist |

## 1. System extensions policy (portal, not Graph)
Devices > Configuration > Create > macOS > Settings catalog > System Configuration > System Extensions > Allowed System Extensions:
`com.microsoft.globalsecureaccess.tunnel` = `UBF8T346G9`, `com.microsoft.globalsecureaccess` = `UBF8T346G9`.
Name: `Mac - System - D - GSA System Extensions`. Assign to the same group with the same exclusion.
(The Settings catalog Graph body is unverified, so it is not included here.)

## 2. Transparent proxy profile
`POST https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations`
```json
{
  "@odata.type": "#microsoft.graph.macOSCustomConfiguration",
  "displayName": "Mac - Network - D - GSA Transparent Proxy",
  "description": "Approves the Global Secure Access transparent app proxy (Learn macOS client page).",
  "payloadName": "Global Secure Access Proxy Configuration",
  "payloadFileName": "GlobalSecureAccessProxy.mobileconfig",
  "payload": "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NUWVBFIHBsaXN0IFBVQkxJQyAiLS8vQXBwbGUvL0RURCBQTElTVCAxLjAvL0VOIiAiaHR0cDovL3d3dy5hcHBsZS5jb20vRFREcy9Qcm9wZXJ0eUxpc3QtMS4wLmR0ZCI+CjxwbGlzdCB2ZXJzaW9uPSIxLjAiPgogIDxkaWN0PgogICAgPGtleT5QYXlsb2FkVVVJRDwva2V5PgogICAgPHN0cmluZz44N2NiYjQyNC02YWY3LTQ3NDgtOWQ0My1mMWM1ZGRhN2EwYTY8L3N0cmluZz4KICAgIDxrZXk+UGF5bG9hZFR5cGU8L2tleT4KICAgIDxzdHJpbmc+Q29uZmlndXJhdGlvbjwvc3RyaW5nPgogICAgPGtleT5QYXlsb2FkT3JnYW5pemF0aW9uPC9rZXk+CiAgICA8c3RyaW5nPk1pY3Jvc29mdCBDb3Jwb3JhdGlvbjwvc3RyaW5nPgogICAgPGtleT5QYXlsb2FkSWRlbnRpZmllcjwva2V5PgogICAgPHN0cmluZz5jb20ubWljcm9zb2Z0Lmdsb2JhbHNlY3VyZWFjY2Vzczwvc3RyaW5nPgogICAgPGtleT5QYXlsb2FkRGlzcGxheU5hbWU8L2tleT4KICAgIDxzdHJpbmc+R2xvYmFsIFNlY3VyZSBBY2Nlc3MgUHJveHkgQ29uZmlndXJhdGlvbjwvc3RyaW5nPgogICAgPGtleT5QYXlsb2FkRGVzY3JpcHRpb248L2tleT4KICAgIDxzdHJpbmc+QWRkIEdsb2JhbCBTZWN1cmUgQWNjZXNzIFByb3h5IENvbmZpZ3VyYXRpb248L3N0cmluZz4KICAgIDxrZXk+UGF5bG9hZFZlcnNpb248L2tleT4KICAgIDxpbnRlZ2VyPjE8L2ludGVnZXI+CiAgICA8a2V5PlBheWxvYWRFbmFibGVkPC9rZXk+CiAgICA8dHJ1ZS8+CiAgICA8a2V5PlBheWxvYWRSZW1vdmFsRGlzYWxsb3dlZDwva2V5PgogICAgPHRydWUvPgogICAgPGtleT5QYXlsb2FkU2NvcGU8L2tleT4KICAgIDxzdHJpbmc+U3lzdGVtPC9zdHJpbmc+CiAgICA8a2V5PlBheWxvYWRDb250ZW50PC9rZXk+CiAgICA8YXJyYXk+CiAgICAgIDxkaWN0PgogICAgICAgIDxrZXk+UGF5bG9hZFVVSUQ8L2tleT4KICAgICAgICA8c3RyaW5nPjA0ZTEzMDYzLTJiYjgtNGI3Mi1iMWVkLTQ1MjkwZjkxYWY2ODwvc3RyaW5nPgogICAgICAgIDxrZXk+UGF5bG9hZFR5cGU8L2tleT4KICAgICAgICA8c3RyaW5nPmNvbS5hcHBsZS52cG4ubWFuYWdlZDwvc3RyaW5nPgogICAgICAgIDxrZXk+UGF5bG9hZE9yZ2FuaXphdGlvbjwva2V5PgogICAgICAgIDxzdHJpbmc+TWljcm9zb2Z0IENvcnBvcmF0aW9uPC9zdHJpbmc+CiAgICAgICAgPGtleT5QYXlsb2FkSWRlbnRpZmllcjwva2V5PgogICAgICAgIDxzdHJpbmc+Y29tLm1pY3Jvc29mdC5nbG9iYWxzZWN1cmVhY2Nlc3M8L3N0cmluZz4KICAgICAgICA8a2V5PlBheWxvYWREaXNwbGF5TmFtZTwva2V5PgogICAgICAgIDxzdHJpbmc+R2xvYmFsIFNlY3VyZSBBY2Nlc3MgUHJveHkgQ29uZmlndXJhdGlvbjwvc3RyaW5nPgogICAgICAgIDxrZXk+UGF5bG9hZERlc2NyaXB0aW9uPC9rZXk+CiAgICAgICAgPHN0cmluZy8+CiAgICAgICAgPGtleT5QYXlsb2FkVmVyc2lvbjwva2V5PgogICAgICAgIDxpbnRlZ2VyPjE8L2ludGVnZXI+CiAgICAgICAgPGtleT5UcmFuc3BhcmVudFByb3h5PC9rZXk+CiAgICAgICAgPGRpY3Q+CiAgICAgICAgICA8a2V5PkF1dGhlbnRpY2F0aW9uTWV0aG9kPC9rZXk+CiAgICAgICAgICA8c3RyaW5nPlBhc3N3b3JkPC9zdHJpbmc+CiAgICAgICAgICA8a2V5Pk9yZGVyPC9rZXk+CiAgICAgICAgICA8aW50ZWdlcj4xPC9pbnRlZ2VyPgogICAgICAgICAgPGtleT5Qcm92aWRlckJ1bmRsZUlkZW50aWZpZXI8L2tleT4KICAgICAgICAgIDxzdHJpbmc+Y29tLm1pY3Jvc29mdC5nbG9iYWxzZWN1cmVhY2Nlc3MudHVubmVsPC9zdHJpbmc+CiAgICAgICAgICA8a2V5PlByb3ZpZGVyRGVzaWduYXRlZFJlcXVpcmVtZW50PC9rZXk+CiAgICAgICAgICA8c3RyaW5nPmlkZW50aWZpZXIgImNvbS5taWNyb3NvZnQuZ2xvYmFsc2VjdXJlYWNjZXNzLnR1bm5lbCIgYW5kIGFuY2hvciBhcHBsZSBnZW5lcmljIGFuZCBjZXJ0aWZpY2F0ZSAxW2ZpZWxkLjEuMi44NDAuMTEzNjM1LjEwMC42LjIuNl0gLyogZXhpc3RzICovIGFuZCBjZXJ0aWZpY2F0ZSBsZWFmW2ZpZWxkLjEuMi44NDAuMTEzNjM1LjEwMC42LjEuMTNdIC8qIGV4aXN0cyAqLyBhbmQgY2VydGlmaWNhdGUgbGVhZltzdWJqZWN0Lk9VXSA9IFVCRjhUMzQ2Rzk8L3N0cmluZz4KICAgICAgICAgIDxrZXk+UHJvdmlkZXJUeXBlPC9rZXk+CiAgICAgICAgICA8c3RyaW5nPmFwcC1wcm94eTwvc3RyaW5nPgogICAgICAgICAgPGtleT5SZW1vdGVBZGRyZXNzPC9rZXk+CiAgICAgICAgICA8c3RyaW5nPjEwMC42NC4wLjA8L3N0cmluZz4KICAgICAgICA8L2RpY3Q+CiAgICAgICAgPGtleT5Vc2VyRGVmaW5lZE5hbWU8L2tleT4KICAgICAgICA8c3RyaW5nPkdsb2JhbCBTZWN1cmUgQWNjZXNzIFByb3h5IENvbmZpZ3VyYXRpb248L3N0cmluZz4KICAgICAgICA8a2V5PlZQTlN1YlR5cGU8L2tleT4KICAgICAgICA8c3RyaW5nPmNvbS5taWNyb3NvZnQuZ2xvYmFsc2VjdXJlYWNjZXNzPC9zdHJpbmc+CiAgICAgICAgPGtleT5WUE5UeXBlPC9rZXk+CiAgICAgICAgPHN0cmluZz5UcmFuc3BhcmVudFByb3h5PC9zdHJpbmc+CiAgICAgIDwvZGljdD4KICAgIDwvYXJyYXk+CiAgPC9kaWN0Pgo8L3BsaXN0Pgo=",
  "deploymentChannel": "deviceChannel"
}
```

Portal check afterwards: Deployment channel must read "Device channel".

`POST https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/<ID>/assign`
```json
{
  "assignments": [
    {
      "target": {
        "@odata.type": "#microsoft.graph.groupAssignmentTarget",
        "groupId": "<TARGET_GROUP_ID>"
      }
    },
    {
      "target": {
        "@odata.type": "#microsoft.graph.exclusionGroupAssignmentTarget",
        "groupId": "<BREAKGLASS_GROUP_ID>"
      }
    }
  ]
}
```


## 3. Client settings profile
`POST https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations`
```json
{
  "@odata.type": "#microsoft.graph.macOSCustomAppConfiguration",
  "displayName": "Mac - Network - D - GSA Client Settings",
  "description": "Global Secure Access client menu settings. LockDownClient=False",
  "bundleId": "com.microsoft.globalsecureaccess",
  "fileName": "com.microsoft.globalsecureaccess.plist",
  "configurationXml": "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz48IURPQ1RZUEUgcGxpc3QgUFVCTElDICItLy9BcHBsZS8vRFREIFBMSVNUIDEuMC8vRU4iICJodHRwOi8vd3d3LmFwcGxlLmNvbS9EVERzL1Byb3BlcnR5TGlzdC0xLjAuZHRkIj48cGxpc3QgdmVyc2lvbj0iMS4wIj48ZGljdD48a2V5PkhpZGVEaXNhYmxlQnV0dG9uPC9rZXk+PGZhbHNlLz48a2V5PkhpZGVQYXVzZUJ1dHRvbjwva2V5PjxmYWxzZS8+PGtleT5IaWRlRGlzYWJsZVByaXZhdGVBY2Nlc3NCdXR0b248L2tleT48dHJ1ZS8+PGtleT5IaWRlUXVpdEJ1dHRvbjwva2V5Pjx0cnVlLz48L2RpY3Q+PC9wbGlzdD4="
}
```

`POST https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/<ID>/assign` with the same assignments body as step 2.

## 4. Install script (only after steps 1-3 are done and assigned)
`POST https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts`
```json
{
  "@odata.type": "#microsoft.graph.deviceShellScript",
  "displayName": "Mac - Network - D - GSA Client Install",
  "description": "Installs the Global Secure Access client. Approvals come from the two GSA MDM profiles.",
  "fileName": "Mac-GSA-Client-Install.sh",
  "runAsAccount": "system",
  "retryCount": 3,
  "blockExecutionNotifications": true,
  "executionFrequency": "P1D",
  "scriptContent": "IyEvYmluL2Jhc2gKIyBNYWMgLSBOZXR3b3JrIC0gRCAtIEdTQSBDbGllbnQgSW5zdGFsbAojCiMgSW5zdGFsbHMgdGhlIEdsb2JhbCBTZWN1cmUgQWNjZXNzIGNsaWVudCBvbiBtYWNPUy4gUnVuIGFzIHJvb3QgKEludHVuZSBzaGVsbCBzY3JpcHQsICJydW4gYXMgc2lnbmVkLWluIHVzZXIiID0gTm8pLgojCiMgSU1QT1JUQU5UOiB0aGlzIHNjcmlwdCBkb2VzIE5PVCBhcHByb3ZlIHRoZSBzeXN0ZW0gZXh0ZW5zaW9uIG9yIHRoZSB0cmFuc3BhcmVudCBhcHAgcHJveHkuCiMgVGhvc2UgYXBwcm92YWxzIGNvbWUgZnJvbSB0d28gTURNIHByb2ZpbGVzIHRoYXQgbXVzdCByZWFjaCB0aGUgTWFjIGZpcnN0OgojICAgLSBTZXR0aW5ncyBjYXRhbG9nOiBBbGxvd2VkIFN5c3RlbSBFeHRlbnNpb25zICh0ZWFtIFVCRjhUMzQ2RzksIGJ1bmRsZSBJRHMgLi4uZ2xvYmFsc2VjdXJlYWNjZXNzLnR1bm5lbCAvIC4uLmdsb2JhbHNlY3VyZWFjY2VzcykKIyAgIC0gQ3VzdG9tIHByb2ZpbGU6IEdsb2JhbCBTZWN1cmUgQWNjZXNzIHRyYW5zcGFyZW50IHByb3h5IHBheWxvYWQKIyBXaXRob3V0IHRoZW0gdGhlIHVzZXIgc2VlcyAiU3lzdGVtIEV4dGVuc2lvbiBCbG9ja2VkIiAvICJ3b3VsZCBsaWtlIHRvIGFkZCBwcm94eSBjb25maWd1cmF0aW9ucyIgcHJvbXB0cy4KIyBTb3VyY2U6IGh0dHBzOi8vbGVhcm4ubWljcm9zb2Z0LmNvbS9lbi11cy9lbnRyYS9nbG9iYWwtc2VjdXJlLWFjY2Vzcy9ob3ctdG8taW5zdGFsbC1tYWNvcy1jbGllbnQKIwojIFNpbGVudCBpbnN0YWxsIGNvbW1hbmQgcGVyIExlYXJuOiBpbnN0YWxsZXIgLXBrZyA8ZmlsZT4gLXRhcmdldCAvCgojIC0tLS0gc2V0dGluZ3MgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIFRoaXMgYWthLm1zIHNob3J0IGxpbmsgaXMgTk9UIG9uIHRoZSBMZWFybiBtYWNPUyBpbnN0YWxsIHBhZ2UgKExlYXJuIHNheXMgZG93bmxvYWQgZnJvbQojIEVudHJhIGFkbWluIGNlbnRlciA+IEdsb2JhbCBTZWN1cmUgQWNjZXNzID4gQ29ubmVjdCA+IENsaWVudCBkb3dubG9hZCkuIFZlcmlmeSBpdCBiZWZvcmUgcGlsb3QgdXNlOgojICAgY3VybCAtc0lMICJodHRwczovL2FrYS5tcy9HbG9iYWxTZWN1cmVBY2Nlc3MtbWFjT1MiIHwgaGVhZCAtMjAKUEtHX1VSTD0iaHR0cHM6Ly9ha2EubXMvR2xvYmFsU2VjdXJlQWNjZXNzLW1hY09TIgpBUFBfRElSPSIvQXBwbGljYXRpb25zL0dsb2JhbFNlY3VyZUFjY2Vzc0NsaWVudCIgICAjIHBhdGggZnJvbSBMZWFybidzIHVuaW5zdGFsbCBjb21tYW5kCk1JTl9NQUNPU19NQUpPUj0xNCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICMgTGVhcm4gcHJlcmVxdWlzaXRlOiBtYWNPUyAxNCBvciBsYXRlcgpNU19URUFNX0lEPSJVQkY4VDM0Nkc5IiAgICAgICAgICAgICAgICAgICAgICAgICAgICAjIE1pY3Jvc29mdCB0ZWFtIElEIGZyb20gTGVhcm4ncyBleHRlbnNpb24gdGFibGUKQ0hFQ0tfU0lHTkFUVVJFPTEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIyAxID0gcmVmdXNlIHRoZSBwYWNrYWdlIHVubGVzcyBwa2d1dGlsIHNob3dzIHRoZSBNaWNyb3NvZnQgdGVhbSBJRApSRVFVSVJFX1BST0ZJTEVTPTAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAjIDEgPSBleGl0IDEgKHJldHJ5IGxhdGVyKSBpZiB0aGUgR1NBIHByb2ZpbGVzIGFyZSBub3Qgb24gdGhlIE1hYyB5ZXQKTE9HPSIvdmFyL2xvZy9nc2EtY2xpZW50LWluc3RhbGwubG9nIgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQoKZXhlYyA+PiAiJExPRyIgMj4mMQplY2hvICI9PT0gJChkYXRlICcrJVktJW0tJWQgJUg6JU06JVMnKSBHU0EgY2xpZW50IGluc3RhbGwgc3RhcnQgPT09IgoKaWYgWyAiJChpZCAtdSkiIC1uZSAwIF07IHRoZW4gZWNobyAiTXVzdCBydW4gYXMgcm9vdC4iOyBleGl0IDE7IGZpCgpNQUpPUj0iJChzd192ZXJzIC1wcm9kdWN0VmVyc2lvbiB8IGN1dCAtZC4gLWYxKSIKaWYgWyAiJE1BSk9SIiAtbHQgIiRNSU5fTUFDT1NfTUFKT1IiIF07IHRoZW4KICBlY2hvICJtYWNPUyAkTUFKT1IgaXMgYmVsb3cgdGhlIHJlcXVpcmVkICRNSU5fTUFDT1NfTUFKT1IuIFNraXBwaW5nLiIKICBleGl0IDAKZmkKCmlmIFsgLWQgIiRBUFBfRElSIiBdOyB0aGVuCiAgZWNobyAiQ2xpZW50IGFscmVhZHkgaW5zdGFsbGVkIGF0ICRBUFBfRElSLiBOb3RoaW5nIHRvIGRvLiIKICBleGl0IDAKZmkKCiMgU29mdCBjaGVjazogYXJlIHRoZSBhcHByb3ZhbCBwcm9maWxlcyBwcmVzZW50PyAob3V0cHV0IGZvcm1hdCBub3QgdmVyaWZpZWQ7IHRyZWF0IGEgbWlzcyBhcyBhIHdhcm5pbmcgYnkgZGVmYXVsdCkKaWYgISAvdXNyL2Jpbi9wcm9maWxlcyBzaG93IC1hbGwgMj4vZGV2L251bGwgfCBncmVwIC1xaSAiY29tLm1pY3Jvc29mdC5nbG9iYWxzZWN1cmVhY2Nlc3MiOyB0aGVuCiAgZWNobyAiV0FSTklORzogbm8gcHJvZmlsZSBtZW50aW9uaW5nIGNvbS5taWNyb3NvZnQuZ2xvYmFsc2VjdXJlYWNjZXNzIGZvdW5kLiBVc2VycyBtYXkgc2VlIGFwcHJvdmFsIHByb21wdHMuIgogIGlmIFsgIiRSRVFVSVJFX1BST0ZJTEVTIiAtZXEgMSBdOyB0aGVuIGVjaG8gIlJFUVVJUkVfUFJPRklMRVM9MSwgZXhpdGluZyBzbyBJbnR1bmUgcmV0cmllcy4iOyBleGl0IDE7IGZpCmZpCgpQS0c9IiQobWt0ZW1wIC90bXAvR2xvYmFsU2VjdXJlQWNjZXNzQ2xpZW50LlhYWFhYWCkucGtnIgp0cmFwICdybSAtZiAiJFBLRyInIEVYSVQKCmVjaG8gIkRvd25sb2FkaW5nICRQS0dfVVJMIgppZiAhIC91c3IvYmluL2N1cmwgLS1mYWlsIC0tbG9jYXRpb24gLS1zaWxlbnQgLS1zaG93LWVycm9yIC0tbWF4LXRpbWUgOTAwIC1vICIkUEtHIiAiJFBLR19VUkwiOyB0aGVuCiAgZWNobyAiRG93bmxvYWQgZmFpbGVkLiI7IGV4aXQgMQpmaQppZiBbICEgLXMgIiRQS0ciIF07IHRoZW4gZWNobyAiRG93bmxvYWRlZCBmaWxlIGlzIGVtcHR5LiI7IGV4aXQgMTsgZmkKCmlmIFsgIiRDSEVDS19TSUdOQVRVUkUiIC1lcSAxIF07IHRoZW4KICBpZiAhIC91c3Ivc2Jpbi9wa2d1dGlsIC0tY2hlY2stc2lnbmF0dXJlICIkUEtHIiB8IGdyZXAgLXEgIiRNU19URUFNX0lEIjsgdGhlbgogICAgZWNobyAiUGFja2FnZSBzaWduYXR1cmUgZG9lcyBub3Qgc2hvdyB0ZWFtIElEICRNU19URUFNX0lELiBSZWZ1c2luZyB0byBpbnN0YWxsLiIKICAgIC91c3Ivc2Jpbi9wa2d1dGlsIC0tY2hlY2stc2lnbmF0dXJlICIkUEtHIgogICAgZXhpdCAxCiAgZmkKICBlY2hvICJQYWNrYWdlIHNpZ25hdHVyZSBjaGVjayBwYXNzZWQgKHRlYW0gSUQgJE1TX1RFQU1fSUQpLiIKZmkKCmVjaG8gIkluc3RhbGxpbmcuLi4iCmlmIC91c3Ivc2Jpbi9pbnN0YWxsZXIgLXBrZyAiJFBLRyIgLXRhcmdldCAvOyB0aGVuCiAgZWNobyAiSW5zdGFsbCBjb21wbGV0ZWQuIgogIGV4aXQgMAplbHNlCiAgUkM9JD8KICBlY2hvICJpbnN0YWxsZXIgZXhpdGVkIHdpdGggJFJDIgogIGV4aXQgIiRSQyIKZmkK"
}
```

`POST https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/<ID>/assign`
```json
{
  "deviceManagementScriptAssignments": [
    {
      "target": {
        "@odata.type": "#microsoft.graph.groupAssignmentTarget",
        "groupId": "<TARGET_GROUP_ID>"
      }
    },
    {
      "target": {
        "@odata.type": "#microsoft.graph.exclusionGroupAssignmentTarget",
        "groupId": "<BREAKGLASS_GROUP_ID>"
      }
    }
  ]
}
```


## 5. Read-back
`GET https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/<ID>/assignments`, `GET https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/<ID>/assignments`:
each must list the include group and the exclusion group. If an assign body is rejected, assign that object in the portal and tell me the error.

## 6. Rollback (only the four new objects)
`DELETE https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/<ID>` / `DELETE https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/<ID>` (x2) / the portal policy.
Deleting a profile removes it from the Mac. Deleting the install script does not uninstall the client; use Learn's uninstall command or the Uninstall app.
