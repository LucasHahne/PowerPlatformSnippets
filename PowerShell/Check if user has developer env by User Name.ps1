# Install required module if not already installed
# Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force -AllowClobber -Scope CurrentUser

# Remove module if already loaded to ensure clean import
Remove-Module Microsoft.PowerApps.Administration.PowerShell -ErrorAction SilentlyContinue

# Import the module with force to ensure all commands are loaded
Import-Module Microsoft.PowerApps.Administration.PowerShell -Force -DisableNameChecking

# Verify module is loaded
Write-Host "Verifying module is loaded..." -ForegroundColor Cyan
$module = Get-Module -Name Microsoft.PowerApps.Administration.PowerShell
if ($null -eq $module) {
    Write-Host "ERROR: Module failed to load. Please install it first using:" -ForegroundColor Red
    Write-Host "Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force -AllowClobber -Scope CurrentUser" -ForegroundColor Yellow
    exit
} else {
    Write-Host "✓ Module loaded successfully!" -ForegroundColor Green
}

# Force interactive login with popup
Write-Host "A login window will appear. Please sign in with your Power Platform Admin account..." -ForegroundColor Cyan
Write-Host "Launching login popup..." -ForegroundColor Yellow

# Connect with interactive login (this forces the popup)
try {
    Add-PowerAppsAccount -Endpoint "prod" -ErrorAction Stop
    Write-Host "✓ Login successful!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Login failed. Please try again." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Verify admin access
Write-Host "`nVerifying admin permissions..." -ForegroundColor Yellow
try {
    $testEnv = Get-AdminPowerAppEnvironment -WarningAction SilentlyContinue | Select-Object -First 1
    
    if ($null -eq $testEnv) {
        Write-Host "WARNING: Unable to retrieve environments. You may not have admin permissions." -ForegroundColor Red
        $continue = Read-Host "Do you want to continue anyway? (Y/N)"
        if ($continue -ne "Y") {
            Write-Host "Script terminated." -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "✓ Admin access confirmed!" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Failed to verify admin access. Please ensure you're logged in as an admin." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Array of usernames to check
$usernames = @(
"Max Mustermann",
"Max Musterfrau"
)

# Function to check for developer environments
function Check-DeveloperEnvironments {
    param (
        [string[]]$Usernames
    )
    
    # Get all environments
    Write-Host "Retrieving all environments..." -ForegroundColor Cyan
    $allEnvironments = Get-AdminPowerAppEnvironment
    
    $results = @()
    
    foreach ($username in $Usernames) {
        Write-Host "`nChecking environments for: $username" -ForegroundColor Yellow
        
        # Filter environments that contain the username and are Developer type
        $userEnvironments = $allEnvironments | Where-Object {
            $_.DisplayName -like "*$username*" -and
            $_.EnvironmentType -eq "Developer"
        }
        
        if ($userEnvironments) {
            foreach ($env in $userEnvironments) {
                $envDetails = [PSCustomObject]@{
                    Username = $username
                    HasDeveloperEnvironment = $true
                    EnvironmentName = $env.DisplayName
                    EnvironmentId = $env.EnvironmentName
                    CreatedTime = $env.CreatedTime
                    Location = $env.Location
                    State = $env.EnvironmentState
                }
                $results += $envDetails
                
                Write-Host "  ✓ Found developer environment: $($env.DisplayName) -ForegroundColor Green
            }
        } else {
            $envDetails = [PSCustomObject]@{
                Username = $username
                HasDeveloperEnvironment = $false
                EnvironmentName = "N/A"
                EnvironmentId = "N/A"
                CreatedTime = "N/A"
                Location = "N/A"
                State = "N/A"
                Currency = "N/A"
                CurrencyName = "N/A"
                CurrencyCode = "N/A"
            }
            $results += $envDetails
            
            Write-Host "  ✗ No developer environment found" -ForegroundColor Red
        }
    }
    
    return $results
}

# Execute the check
$report = Check-DeveloperEnvironments -Usernames $usernames

# Display summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
$report | Format-Table -AutoSize
