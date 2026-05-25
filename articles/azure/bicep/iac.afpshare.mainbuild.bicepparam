using './cpm.afpshare.mainbuild.bicep'

param clientid = 'IAC'
param Region = 'AZE2'
param adminGroupObjectId = '' // Object ID of your admin/IT group - grants Storage File Data SMB Share Elevated Contributor
param avdUsersGroupObjectId = '' // Object ID of your AVD users group - grants Storage File Data SMB Share Contributor

