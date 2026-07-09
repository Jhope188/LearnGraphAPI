<#
.SYNOPSIS
    Creates EDM schemas and SITs for Financial and Medical demo labels.

.DESCRIPTION
    Creates two Exact Data Match (EDM) sensitive information types:
        1. EDM - Financial Customer Record
           Primary: AccountNumber (mapped to Credit Card Number SIT)
           Supporting: SSN, FirstName, LastName, DateOfBirth, AccountType

        2. EDM - Patient Medical Record
           Primary: PatientID (mapped to custom MRN pattern)
           Supporting: SSN, FirstName, LastName, DateOfBirth, DiagnosisCode, ProviderNPI

    EDM is a multi-phase process. This script handles Phase 1 (schema + SIT creation).
    You must complete Phase 2 (data upload + indexing) manually or via EDMUploadAgent.

    PHASES OVERVIEW:
        Phase 1 - This script: Create schema + SIT definition
        Phase 2 - Manual:      Hash and upload sensitive data table via EDM Upload Agent
        Phase 3 - Manual:      Index uploaded data (auto-triggers after upload)
        Phase 4 - This script: Verify SIT is live (Get-DlpSensitiveInformationType)

    IMPORTANT CONSTRAINT:
        EDM SITs cannot be used ALONE in auto-labeling policies.
        They must be paired with at least one non-EDM built-in SIT.
        This is enforced by Purview — labels with only EDM conditions have
        auto-labeling silently disabled.
        See: Create-AutoLabelingPolicies.ps1 for the correct combined rule syntax.

.PARAMETER TenantDomain
    Your tenant's onmicrosoft.com domain.

.PARAMETER DryRun
    Shows what would be created without making changes.

.EXAMPLE
    .\Create-EDMSchemas.ps1 -TenantDomain "contoso.onmicrosoft.com"
    .\Create-EDMSchemas.ps1 -TenantDomain "contoso.onmicrosoft.com" -DryRun

.NOTES
    Author:   IAC
    Date:     2026-06-24
    Requires: ExchangeOnlineManagement v3+
    Roles:    Compliance Administrator or Information Protection Administrator

    EDM Upload Agent download:
    https://go.microsoft.com/fwlink/?linkid=2088639

    EDM full workflow reference:
    https://learn.microsoft.com/en-us/purview/sit-get-started-exact-data-match-based-sits-overview
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC EDM Schema & SIT Creation" -ForegroundColor Cyan
Write-Host "  Financial + Medical Demo" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow }
Write-Host ""

# ============================================================================
# CONNECT
# ============================================================================
try {
    Get-DlpSensitiveInformationType -ErrorAction Stop | Out-Null
    Write-Host "[OK] Already connected to Security & Compliance" -ForegroundColor Green
} catch {
    Write-Host "[..] Connecting to Security & Compliance PowerShell..." -ForegroundColor Yellow
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "[OK] Connected" -ForegroundColor Green
}

if (-not $TenantDomain) {
    $TenantDomain = ((Get-ConnectionInformation | Select-Object -First 1).UserPrincipalName).Split('@')[1]
    Write-Host "[OK] TenantDomain derived: $TenantDomain" -ForegroundColor Green
}

# ============================================================================
# HELPER
# ============================================================================
function Test-EDMSchemaExists {
    param([string]$SchemaName)
    try {
        $existing = Get-DlpEdmSchema -Identity $SchemaName -ErrorAction SilentlyContinue
        return ($null -ne $existing)
    } catch {
        return $false
    }
}

function Test-SITExists {
    param([string]$SITName)
    $existing = Get-DlpSensitiveInformationType -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $SITName }
    return ($null -ne $existing)
}

# ============================================================================
# PHASE 1A — FINANCIAL EDM SCHEMA
# ============================================================================
Write-Host ""
Write-Host "--- [1/2] Financial EDM Schema ---" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Schema Name  : EDM-FinancialCustomerRecord" -ForegroundColor Gray
Write-Host "  Primary Field: AccountNumber (Credit Card Number SIT)" -ForegroundColor Gray
Write-Host "  Supporting   : SSN, FirstName, LastName, DateOfBirth, AccountType" -ForegroundColor Gray
Write-Host ""

# EDM schema XML — defines the data table structure
# Primary field AccountNumber is mapped to built-in Credit Card Number SIT (GUID)
# This is required: primary fields must map to a strongly-defined built-in SIT
$financialSchemaXml = @"
<EdmSchema xmlns="http://schemas.microsoft.com/office/2018/edm">
  <DataStore name="FinancialCustomerRecord" description="Financial customer account and identity data for EDM detection" version="1">
    <Field name="AccountNumber" searchable="true" coreField="true" ignoredDelimiters="-" />
    <Field name="SSN" searchable="true" ignoredDelimiters="-" />
    <Field name="FirstName" searchable="false" />
    <Field name="LastName" searchable="false" />
    <Field name="DateOfBirth" searchable="false" ignoredDelimiters="-/." />
    <Field name="AccountType" searchable="false" />
  </DataStore>
</EdmSchema>
"@

$financialRulePackageXml = @"
<?xml version="1.0" encoding="utf-8"?>
<RulePackage xmlns="http://schemas.microsoft.com/office/2018/edm">
  <RulePack id="$(New-Guid)">
    <Version major="1" minor="0" build="0" revision="0" />
    <Publisher id="$(New-Guid)" />
    <Details defaultLangCode="en-us">
      <LocalizedDetails langcode="en-us">
        <PublisherName>IAC</PublisherName>
        <Name>EDM Financial Customer Record Package</Name>
        <Description>EDM SIT for detecting financial account records matched against customer database</Description>
      </LocalizedDetails>
    </Details>
  </RulePack>
  <Rules>
    <!-- High confidence: AccountNumber + 2 supporting fields -->
    <ExactMatch id="$(New-Guid)" patternsProximity="300" dataStore="FinancialCustomerRecord" recommendedConfidence="85">
      <Pattern confidenceLevel="85">
        <idMatch field="AccountNumber" classification="Credit Card Number" />
        <Match field="SSN" minCount="1" />
        <Match field="LastName" minCount="1" />
      </Pattern>
      <!-- Medium confidence: AccountNumber + 1 supporting field -->
      <Pattern confidenceLevel="75">
        <idMatch field="AccountNumber" classification="Credit Card Number" />
        <Match field="LastName" minCount="1" />
      </Pattern>
    </ExactMatch>
    <LocalizedStrings>
      <Resource idRef="$(New-Guid)">
        <Name default="true" langcode="en-us">EDM - Financial Customer Record</Name>
        <Description default="true" langcode="en-us">
          Detects financial account numbers exactly matched against customer records.
          Primary: Account Number. Supporting: SSN, Name, DOB.
        </Description>
      </Resource>
    </LocalizedStrings>
  </Rules>
</RulePackage>
"@

if (Test-EDMSchemaExists -SchemaName "FinancialCustomerRecord") {
    Write-Host "  [EXISTS] EDM schema 'FinancialCustomerRecord' already present — skipping" -ForegroundColor Gray
} elseif ($DryRun) {
    Write-Host "  [DRY RUN] Would create EDM schema: FinancialCustomerRecord" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Would create EDM SIT:    EDM - Financial Customer Record" -ForegroundColor Yellow
} else {
    Write-Host "  [..] Creating Financial EDM schema..." -ForegroundColor Yellow

    # Write schema XML to temp file
    $financialSchemaPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '_financial_schema.xml'
    $financialSchemaXml | Out-File -FilePath $financialSchemaPath -Encoding UTF8

    $financialRulePath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '_financial_rules.xml'
    $financialRulePackageXml | Out-File -FilePath $financialRulePath -Encoding UTF8

    try {
        New-DlpEdmSchema -FileData ([System.IO.File]::ReadAllBytes($financialSchemaPath)) -Confirm:$false
        Write-Host "  [OK] Financial EDM schema created" -ForegroundColor Green

        New-DlpSensitiveInformationTypeRulePackage -FileData ([System.IO.File]::ReadAllBytes($financialRulePath)) -Confirm:$false
        Write-Host "  [OK] Financial EDM SIT rule package created" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Failed to create Financial EDM schema: $_" -ForegroundColor Red
    } finally {
        Remove-Item $financialSchemaPath, $financialRulePath -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# PHASE 1B — MEDICAL EDM SCHEMA
# ============================================================================
Write-Host ""
Write-Host "--- [2/2] Medical EDM Schema ---" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Schema Name  : EDM-PatientMedicalRecord" -ForegroundColor Gray
Write-Host "  Primary Field: PatientID (custom MRN pattern — format: MRN-YYYY-NNNNN)" -ForegroundColor Gray
Write-Host "  Supporting   : SSN, FirstName, LastName, DateOfBirth, DiagnosisCode, ProviderNPI" -ForegroundColor Gray
Write-Host ""
Write-Host "  NOTE: PatientID uses a custom MRN format not covered by a built-in SIT." -ForegroundColor Yellow
Write-Host "  A custom SIT for MRN detection is created below and used as the primary classifier." -ForegroundColor Yellow
Write-Host ""

# Custom SIT for MRN pattern (MRN-YYYY-NNNNN format used in demo data)
# This becomes the primary element classifier for the Medical EDM schema
$mrnSITXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<RulePackage xmlns="http://schemas.microsoft.com/office/2011/mce">
  <RulePack id="$(New-Guid)">
    <Version major="1" minor="0" build="0" revision="0"/>
    <Publisher id="$(New-Guid)"/>
    <Details defaultLangCode="en-us">
      <LocalizedDetails langcode="en-us">
        <PublisherName>IAC</PublisherName>
        <Name>IAC Medical Record Number Package</Name>
        <Description>Custom SIT detecting Medical Record Numbers in MRN-YYYY-NNNNN format</Description>
      </LocalizedDetails>
    </Details>
  </RulePack>
  <Rules>
    <Entity id="$(New-Guid)" patternsProximity="300" recommendedConfidence="85">
      <!-- High confidence: MRN pattern + supporting keyword -->
      <Pattern confidenceLevel="85">
        <IdMatch idRef="Regex_MRN_Format"/>
        <Match idRef="Keyword_MRN_Indicators"/>
      </Pattern>
      <!-- Medium confidence: MRN pattern only -->
      <Pattern confidenceLevel="65">
        <IdMatch idRef="Regex_MRN_Format"/>
      </Pattern>
    </Entity>
    <!-- MRN format: MRN-YYYY-NNNNN (e.g. MRN-2024-00142) -->
    <Regex id="Regex_MRN_Format">\bMRN-\d{4}-\d{5}\b</Regex>
    <Keyword id="Keyword_MRN_Indicators">
      <Group matchStyle="word">
        <Term>patient id</Term>
        <Term>patient identifier</Term>
        <Term>medical record number</Term>
        <Term>medical record no</Term>
        <Term>MRN</Term>
        <Term>chart number</Term>
        <Term>patient number</Term>
      </Group>
    </Keyword>
    <LocalizedStrings>
      <Resource idRef="$(New-Guid)">
        <Name default="true" langcode="en-us">Medical Record Number (MRN)</Name>
        <Description default="true" langcode="en-us">
          Detects Medical Record Numbers in MRN-YYYY-NNNNN format.
          Used as primary element classifier for Medical EDM SIT.
        </Description>
      </Resource>
    </LocalizedStrings>
  </Rules>
</RulePackage>
"@

$medicalSchemaXml = @"
<EdmSchema xmlns="http://schemas.microsoft.com/office/2018/edm">
  <DataStore name="PatientMedicalRecord" description="Patient identity and medical record data for EDM detection" version="1">
    <Field name="PatientID" searchable="true" coreField="true" />
    <Field name="SSN" searchable="true" ignoredDelimiters="-" />
    <Field name="FirstName" searchable="false" />
    <Field name="LastName" searchable="false" />
    <Field name="DateOfBirth" searchable="false" ignoredDelimiters="-/." />
    <Field name="DiagnosisCode" searchable="true" ignoredDelimiters="." />
    <Field name="ProviderNPI" searchable="false" />
  </DataStore>
</EdmSchema>
"@

$medicalRulePackageXml = @"
<?xml version="1.0" encoding="utf-8"?>
<RulePackage xmlns="http://schemas.microsoft.com/office/2018/edm">
  <RulePack id="$(New-Guid)">
    <Version major="1" minor="0" build="0" revision="0" />
    <Publisher id="$(New-Guid)" />
    <Details defaultLangCode="en-us">
      <LocalizedDetails langcode="en-us">
        <PublisherName>IAC</PublisherName>
        <Name>EDM Patient Medical Record Package</Name>
        <Description>EDM SIT for detecting patient medical records matched against patient database</Description>
      </LocalizedDetails>
    </Details>
  </RulePack>
  <Rules>
    <!-- High confidence: PatientID + SSN + Diagnosis -->
    <ExactMatch id="$(New-Guid)" patternsProximity="300" dataStore="PatientMedicalRecord" recommendedConfidence="85">
      <Pattern confidenceLevel="85">
        <idMatch field="PatientID" classification="Medical Record Number (MRN)" />
        <Match field="SSN" minCount="1" />
        <Match field="DiagnosisCode" minCount="1" />
      </Pattern>
      <!-- Medium confidence: PatientID + name -->
      <Pattern confidenceLevel="75">
        <idMatch field="PatientID" classification="Medical Record Number (MRN)" />
        <Match field="LastName" minCount="1" />
      </Pattern>
    </ExactMatch>
    <LocalizedStrings>
      <Resource idRef="$(New-Guid)">
        <Name default="true" langcode="en-us">EDM - Patient Medical Record</Name>
        <Description default="true" langcode="en-us">
          Detects patient medical records exactly matched against patient database.
          Primary: PatientID (MRN). Supporting: SSN, Diagnosis Code, Name, DOB.
        </Description>
      </Resource>
    </LocalizedStrings>
  </Rules>
</RulePackage>
"@

if (Test-EDMSchemaExists -SchemaName "PatientMedicalRecord") {
    Write-Host "  [EXISTS] EDM schema 'PatientMedicalRecord' already present — skipping" -ForegroundColor Gray
} elseif ($DryRun) {
    Write-Host "  [DRY RUN] Would create custom SIT: Medical Record Number (MRN)" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Would create EDM schema:  PatientMedicalRecord" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Would create EDM SIT:     EDM - Patient Medical Record" -ForegroundColor Yellow
} else {
    Write-Host "  [..] Creating MRN custom SIT..." -ForegroundColor Yellow

    $mrnSITPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '_mrn_sit.xml'
    $mrnSITXml | Out-File -FilePath $mrnSITPath -Encoding UTF8

    $medicalSchemaPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '_medical_schema.xml'
    $medicalSchemaXml | Out-File -FilePath $medicalSchemaPath -Encoding UTF8

    $medicalRulePath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '_medical_rules.xml'
    $medicalRulePackageXml | Out-File -FilePath $medicalRulePath -Encoding UTF8

    try {
        # Create MRN custom SIT first — required as primary classifier for Medical EDM
        if (-not (Test-SITExists -SITName "Medical Record Number (MRN)")) {
            New-DlpSensitiveInformationTypeRulePackage -FileData ([System.IO.File]::ReadAllBytes($mrnSITPath)) -Confirm:$false
            Write-Host "  [OK] MRN custom SIT created" -ForegroundColor Green
        } else {
            Write-Host "  [EXISTS] MRN custom SIT already present — skipping" -ForegroundColor Gray
        }

        Start-Sleep -Seconds 5  # Allow SIT to propagate before EDM references it

        New-DlpEdmSchema -FileData ([System.IO.File]::ReadAllBytes($medicalSchemaPath)) -Confirm:$false
        Write-Host "  [OK] Medical EDM schema created" -ForegroundColor Green

        New-DlpSensitiveInformationTypeRulePackage -FileData ([System.IO.File]::ReadAllBytes($medicalRulePath)) -Confirm:$false
        Write-Host "  [OK] Medical EDM SIT rule package created" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Failed to create Medical EDM schema: $_" -ForegroundColor Red
    } finally {
        Remove-Item $mrnSITPath, $medicalSchemaPath, $medicalRulePath -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# NEXT STEPS — DATA UPLOAD INSTRUCTIONS
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  PHASE 2: Upload Sensitive Data Tables" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "  EDM schemas are created. You must now hash and upload your" -ForegroundColor White
Write-Host "  sensitive data tables before the EDM SITs can detect content." -ForegroundColor White
Write-Host ""
Write-Host "  FOR DEMO: Use the provided sample CSV files:" -ForegroundColor Cyan
Write-Host "    Financial : EDM-Financial-SampleData.csv" -ForegroundColor Cyan
Write-Host "    Medical   : EDM-Medical-SampleData.csv" -ForegroundColor Cyan
Write-Host ""
Write-Host "  UPLOAD METHOD 1 — EDM Upload Agent (recommended for large tables):" -ForegroundColor White
Write-Host "    1. Download EDM Upload Agent:" -ForegroundColor Gray
Write-Host "       https://go.microsoft.com/fwlink/?linkid=2088639" -ForegroundColor Gray
Write-Host "    2. Hash the data:" -ForegroundColor Gray
Write-Host "       EdmUploadAgent.exe /CreateHash /DataStoreName FinancialCustomerRecord \" -ForegroundColor Gray
Write-Host "         /DataFile EDM-Financial-SampleData.csv /HashLocation C:\EDMHashes\" -ForegroundColor Gray
Write-Host "    3. Upload the hash:" -ForegroundColor Gray
Write-Host "       EdmUploadAgent.exe /UploadHash /DataStoreName FinancialCustomerRecord \" -ForegroundColor Gray
Write-Host "         /HashLocation C:\EDMHashes\" -ForegroundColor Gray
Write-Host "    4. Repeat for PatientMedicalRecord / EDM-Medical-SampleData.csv" -ForegroundColor Gray
Write-Host ""
Write-Host "  UPLOAD METHOD 2 — Purview Portal (easiest for demo):" -ForegroundColor White
Write-Host "    Purview portal → Information Protection → Classifiers → EDM Classifiers" -ForegroundColor Gray
Write-Host "    Select each EDM SIT → Upload data → upload the CSV file directly" -ForegroundColor Gray
Write-Host ""
Write-Host "  Wait ~1 hour after upload before testing or enabling auto-labeling." -ForegroundColor Yellow
Write-Host ""
Write-Host "  VERIFY UPLOAD:" -ForegroundColor White
Write-Host "    Get-DlpEdmSchema | FT Name, State" -ForegroundColor Gray
Write-Host "    # State should show 'Completed' once indexing is done" -ForegroundColor Gray
Write-Host ""
Write-Host "  THEN RUN:" -ForegroundColor White
Write-Host "    .\Create-AutoLabelingPolicies.ps1 -TenantDomain `"$TenantDomain`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  EDM Schema Creation Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Verify SITs  : Get-DlpSensitiveInformationType | Where Name -like '*EDM*' | FT Name, Publisher" -ForegroundColor Gray
Write-Host "  Verify schema: Get-DlpEdmSchema | FT Name, Description" -ForegroundColor Gray
Write-Host "  Disconnect   : Disconnect-ExchangeOnline -Confirm:`$false" -ForegroundColor Gray
Write-Host ""
