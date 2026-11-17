<#
    Cloud Spray Detection (Error-Code Driven)
    - Works in Entra P1
    - Detects cloud-origin password spray using ResultType 50053 / 50126
    - Correlates cloud failures with AD lockouts (4740)
#>

param(
    [int]$HoursBack = 12,
    [int]$CorrelationMinutes = 10
)

# --- Time window ---
$StartTime = (Get-Date).AddHours(-$HoursBack)
$StartIso  = $StartTime.ToString("o")

Write-Host "Scanning cloud + AD events since $StartTime" -ForegroundColor Cyan

# --- Connect to Graph ---
Import-Module Microsoft.Graph.Reports -ErrorAction SilentlyContinue
Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue

Connect-MgGraph -Scopes "AuditLog.Read.All" | Out-Null

# --- Pull cloud failures (50053 + 50126) ---
Write-Host "Pulling cloud failures (50053 / 50126)..." -ForegroundColor Yellow

$CloudFailures = Get-MgAuditLogSignIn -Filter "createdDateTime ge $StartIso" -All |
    Where-Object { $_.ResultType -in @("50053","50126") } |
    ForEach-Object {
        [PSCustomObject]@{
            Source       = "Cloud"
            TimeCreated  = $_.CreatedDateTime
            UserPrincipalName = $_.UserPrincipalName
            ResultType   = $_.ResultType
            ResultDesc   = $_.ResultDescription
            ClientApp    = $_.ClientAppUsed
            IPAddress    = $_.IpAddress
            Location     = $_.Location
            Resource     = $_.ResourceDisplayName
        }
    }

Write-Host "Cloud failures found: $($CloudFailures.Count)" -ForegroundColor Green

# --- Pull AD lockouts (4740) ---
Write-Host "Pulling AD lockouts (4740)..." -ForegroundColor Yellow

$DCs = (Get-ADDomainController -Filter *).Hostname

$ADLockouts = foreach ($DC in $DCs) {
    Get-WinEvent -ComputerName $DC -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4740
        StartTime = $StartTime
    } -ErrorAction SilentlyContinue |
    ForEach-Object {
        $xml  = [xml]$_.ToXml()
        $data = $xml.Event.EventData.Data
        $TargetUser = ($data | Where-Object Name -eq 'TargetUserName').'#text'

        [PSCustomObject]@{
            Source       = "OnPrem"
            TimeCreated  = $_.TimeCreated
            DC           = $_.MachineName
            Account      = $TargetUser
            Message      = $_.Message
        }
    }
}

Write-Host "AD lockouts found: $($ADLockouts.Count)" -ForegroundColor Green

# --- Correlate cloud failures to AD lockouts ---
Write-Host "Correlating cloud failures to AD lockouts..." -ForegroundColor Yellow

$Correlated = foreach ($lockout in $ADLockouts) {
    $matches = $CloudFailures |
        Where-Object {
            $_.UserPrincipalName -like "*$($lockout.Account)*" -and
            [math]::Abs((New-TimeSpan -Start $_.TimeCreated -End $lockout.TimeCreated).TotalMinutes) -le $CorrelationMinutes
        }

    foreach ($cf in $matches) {
        [PSCustomObject]@{
            Account          = $lockout.Account
            LockoutTime      = $lockout.TimeCreated
            LockoutDC        = $lockout.DC
            CloudFailureTime = $cf.TimeCreated
            CloudUPN         = $cf.UserPrincipalName
            CloudResult      = $cf.ResultType
            CloudClientApp   = $cf.ClientApp
            CloudIP          = $cf.IPAddress
            CloudLocation    = $cf.Location
            CloudResource    = $cf.Resource
        }
    }
}

Write-Host "Correlated cloud→AD lockouts: $($Correlated.Count)" -ForegroundColor Green

# --- Output ---
$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$basePath  = $env:TEMP

$cloudCsv      = Join-Path $basePath "CloudFailures_$timestamp.csv"
$adCsv         = Join-Path $basePath "ADLockouts_$timestamp.csv"
$correlatedCsv = Join-Path $basePath "CloudToAD_$timestamp.csv"

$CloudFailures  | Export-Csv $cloudCsv -NoTypeInformation
$ADLockouts     | Export-Csv $adCsv -NoTypeInformation
$Correlated     | Export-Csv $correlatedCsv -NoTypeInformation

Write-Host "Reports generated:" -ForegroundColor Cyan
Write-Host "  Cloud failures:   $cloudCsv"
Write-Host "  AD lockouts:      $adCsv"
Write-Host "  Correlated:       $correlatedCsv"
