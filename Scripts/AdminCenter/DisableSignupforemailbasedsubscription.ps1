# Connect to Microsoft Graph with required scopes
Connect-MgGraph -Scopes "Policy.Read.All", "Policy.ReadWrite.Authorization"

# Get the current authorization policy
$authPolicy = Get-MgBetaPolicyAuthorizationPolicy -AuthorizationPolicyId "authorization"  consistencyLevel eventual

# Display current value
$currentSetting = $authPolicy.AllowedToSignUpEmailBasedSubscriptions
Write-Host "Current setting for 'allowedToSignUpEmailBasedSubscriptions': $currentSetting"

# Check and update if needed
if ($currentSetting -ne $false) {
    Write-Host "Turning off 'allowedToSignUpEmailBasedSubscriptions'..."
    
    Update-MgPolicyAuthorizationPolicy -AuthorizationPolicyId "authorization" `
        -AllowedToSignUpEmailBasedSubscriptions:$false

    Write-Host "Setting updated successfully."
} else {
    Write-Host "Setting is already set to false. No change needed."
}
