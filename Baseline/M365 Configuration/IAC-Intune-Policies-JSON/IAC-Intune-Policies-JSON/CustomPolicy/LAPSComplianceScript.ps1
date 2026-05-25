#Script from https://www.linkedin.com/pulse/enabled-windows-laps-how-do-you-know-working-pieter-hancke/
#Where and How to Add Windows LAPS Compliance Reporting in Intune (https://learn.microsoft.com/en-us/intune/intune-service/protect/compliance-use-custom-settings)
#Discovery script: https://learn.microsoft.com/en-us/intune/intune-service/protect/compliance-custom-script


# Check for Windows LAPS processing
$Date = (Get-Date).AddDays(-2)
$LAPSSucceedEvents = Get-WinEvent -FilterHashtable @{ LogName='Microsoft-Windows-LAPS/Operational'; StartTime=$Date; Id='10004' } -ErrorAction SilentlyContinue
$LAPSSucceedEventsCount = $LAPSSucceedEvents.Count
If ($LAPSSucceedEventsCount -gt 0)
    {
        $LAPSProcessing = "true"
    }
    else
    {
        $LAPSProcessing = "false"
    }
# Output
$hash = @{WindowsLAPSProcessing = $LAPSProcessing}
return $hash | ConvertTo-Json -Compress