# Creates a Microsoft Intune Cloud PKI Root Certification Authority
# for conditionalaccess.tech.
#
# Requires: Microsoft.Graph.Authentication module
# Scope:    DeviceManagementConfiguration.ReadWrite.All

Connect-MgGraph -Scopes DeviceManagementConfiguration.ReadWrite.All

$body = @{
  commonName                                 = "ConditionalAccess.Tech Root CA"
  displayName                                = "ConditionalAccessTechRootCA"
  cloudCertificationAuthorityType            = "rootCertificationAuthority"
  certificationAuthorityIssuerId             = $null
  validityPeriodInYears                      = 10
  certificateKeySize                         = "rsa4096"
  cloudCertificationAuthorityHashingAlgorithm = "sha512"
  organizationName                           = "ConditionalAccess.Tech"
  organizationUnit                           = "IT"
  countryName                                = "US"
  stateName                                  = "Virginia"
  localityName                               = "Richmond"
  roleScopeTagIds                            = @(
    "0"
  )
  extendedKeyUsages                          = @(
    @{
      name              = "Server auth"
      objectIdentifier  = "1.3.6.1.5.5.7.3.1"
    }
    @{
      name              = "Client auth"
      objectIdentifier  = "1.3.6.1.5.5.7.3.2"
    }
    @{
      name              = "Code signing"
      objectIdentifier  = "1.3.6.1.5.5.7.3.3"
    }
  )
}

Invoke-MgGraphRequest -Method POST `
  -Uri "/beta/deviceManagement/cloudCertificationAuthority" `
  -Body $body `
  -ContentType "application/json"
