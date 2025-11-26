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

# Configuration
$usernames = @(
"Max Mustermann",
"Max Musterfrau"
)

# Environment creation settings
$defaultLocation = "unitedstates"  # Change to your preferred location (e.g., "unitedstates", "europe", "asia")
$defaultCurrency = "USD"     # Change to your preferred currency code

# Function to create developer environment
function Create-DeveloperEnvironment {
    param (
        [string]$Username,
        [string]$Location = "europe",
        [string]$CurrencyName = "EUR"
    )
    
    try {
        $envDisplayName = "$Username - Developer Environment"
        
        Write-Host "  Creating developer environment for $Username..." -ForegroundColor Yellow
        Write-Host "    Display Name: $envDisplayName" -ForegroundColor Gray
        Write-Host "    Location: $Location" -ForegroundColor Gray
        Write-Host "    Currency: $CurrencyName" -ForegroundColor Gray
        
        # Create the environment
        $newEnv = New-AdminPowerAppEnvironment `
            -DisplayName $envDisplayName `
            -EnvironmentSku "Developer" `
            -Location $Location `
            -CurrencyName $CurrencyName `
            -ProvisionDatabase
        
        if ($newEnv) {
            Write-Host "  ✓ Developer environment created successfully!" -ForegroundColor Green
            Write-Host "    Environment ID: $($newEnv.EnvironmentName)" -ForegroundColor Gray
            return $newEnv
        } else {
            Write-Host "  ✗ Failed to create environment (no error thrown but no environment returned)" -ForegroundColor Red
            return $null
        }
        
    } catch {
        Write-Host "  ✗ ERROR: Failed to create developer environment" -ForegroundColor Red
        Write-Host "    Error details: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to check for developer environments and create if missing
function Check-AndCreateDeveloperEnvironments {
    param (
        [string[]]$Usernames,
        [string]$Location = "europe",
        [string]$CurrencyName = "EUR",
        [switch]$AutoCreate
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
                    Action = "Already Exists"
                }
                $results += $envDetails
                
                Write-Host "  ✓ Found developer environment: $($env.DisplayName)" -ForegroundColor Green
            }
        } else {
            Write-Host "  ✗ No developer environment found" -ForegroundColor Red
            
            # Ask if user wants to create environment
            if ($AutoCreate) {
                $createEnv = "Y"
            } else {
                $createEnv = Read-Host "  Would you like to create a developer environment for $username? (Y/N)"
            }
            
            if ($createEnv -eq "Y") {
                $newEnv = Create-DeveloperEnvironment -Username $username -Location $Location -CurrencyName $CurrencyName
                
                if ($newEnv) {
                    $envDetails = [PSCustomObject]@{
                        Username = $username
                        HasDeveloperEnvironment = $true
                        EnvironmentName = $newEnv.DisplayName
                        EnvironmentId = $newEnv.EnvironmentName
                        CreatedTime = $newEnv.CreatedTime
                        Location = $newEnv.Location
                        State = $newEnv.EnvironmentState
                        Action = "Created"
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
                        Action = "Creation Failed"
                    }
                }
            } else {
                Write-Host "  Skipping environment creation for $username" -ForegroundColor Yellow
                $envDetails = [PSCustomObject]@{
                    Username = $username
                    HasDeveloperEnvironment = $false
                    EnvironmentName = "N/A"
                    EnvironmentId = "N/A"
                    CreatedTime = "N/A"
                    Location = "N/A"
                    State = "N/A"
                    Action = "Skipped"
                }
            }
            
            $results += $envDetails
        }
    }
    
    return $results
}

# Execute the check and create
# Set -AutoCreate to automatically create environments without prompting
$report = Check-AndCreateDeveloperEnvironments `
    -Usernames $usernames `
    -Location $defaultLocation `
    -CurrencyName $defaultCurrency
    # -AutoCreate  # Uncomment this line to auto-create without prompts

# Display summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
$report | Format-Table -AutoSize
