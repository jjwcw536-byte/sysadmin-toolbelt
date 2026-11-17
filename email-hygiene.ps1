# Email Hygiene Dashboard
# Version: 1.0
# Author: Jay Walsh
# Created: 2026-07-29
# Purpose:
# Daily Exchange Online quarantine analysis,
# VT enrichment, historical tracking,
# and phishing investigation support.

# NOTE:
# QuarantineHistory.csv is intentionally appended on every run.
# Duplicate entries are expected and used for trend analysis.
# The file is not intended to be a deduplicated forensic record.

### Connect to Exchange

Connect-IPPSSession -EnableSearchOnlySession

### Pull Last 24 hours of Quarantine

$Start = (Get-Date).AddDays(-2)
$End   = Get-Date

$messages = Get-QuarantineMessage `
    -StartReceivedDate $Start `
    -EndReceivedDate $End `
    -PageSize 1000

### Threat Summary

$ThreatSummary = $messages |
    Group-Object Type |
    Sort-Object Count -Descending |
    Select-Object Count, Name

### Extract Sender Domains

$Domains = $messages | ForEach-Object {

    $Domain = ($_.SenderAddress -split "@")[-1]

    [PSCustomObject]@{
        Domain = $Domain
    }

}

### Allow List

$KnownGoodDomains = @(
    "microsoft.com",
    "microsoftonline.com",
    "office.com",
    "adobe.com",
    "docusign.net",
    "amazon.com"
)

$Domains = $Domains | Where-Object {
    $_.Domain -notin $KnownGoodDomains
}

### Top Domains

$TopDomains = $Domains |
    Group-Object Domain |
    Sort-Object Count -Descending |
    Select-Object Count, Name -First 20

### Top Recipients

$TopRecipients = $messages |
    Group-Object RecipientAddress |
    Sort-Object Count -Descending |
    Select-Object Count, Name -First 20

### Top Subjects

$TopSubjects = $messages |
    Group-Object Subject |
    Sort-Object Count -Descending |
    Select-Object Count, Name -First 20

### High Confidence Phish

$HighPhish = $messages |
    Where-Object {
        $_.Type -eq "High Confidence Phish"
    } |
    Select-Object `
        ReceivedTime,
        SenderAddress,
        RecipientAddress,
        Subject


### VirusTotal

$VTApiKey = "60ed0e5a8fd0a2797e26a57125ccf4b1345e3fc7d4012349ad92e08e7f7a421e"

function Get-VTDomainInfo {

    param($Domain)

    try {

        $Result = Invoke-RestMethod `
            -Uri "https://www.virustotal.com/api/v3/domains/$Domain" `
            -Headers @{
                "x-apikey" = $VTApiKey
            }

        [PSCustomObject]@{
            Domain     = $Domain
            Malicious  = $Result.data.attributes.last_analysis_stats.malicious
            Suspicious = $Result.data.attributes.last_analysis_stats.suspicious
        }

    }
    catch {

        [PSCustomObject]@{
            Domain     = $Domain
            Malicious  = "0"
            Suspicious = "0"
        }

    }

}

$VTResults = foreach ($Domain in $TopDomains.Name) {
    Get-VTDomainInfo $Domain
}

### Risk Scores

$RiskScores = foreach ($Result in $VTResults) {

    $Count = (
        $TopDomains |
        Where-Object {
            $_.Name -eq $Result.Domain
        }
    ).Count

    $Risk = ($Count * 2) + `
        ($Result.Malicious * 5) + `
        ($Result.Suspicious * 3)

    [PSCustomObject]@{
        Domain     = $Result.Domain
        Messages   = $Count
        Malicious  = $Result.Malicious
        Suspicious = $Result.Suspicious
        RiskScore  = $Risk
    }

}

$RiskScores = $RiskScores |
    Sort-Object RiskScore -Descending

$HighRiskFindings = $RiskScores |
    Where-Object {
        $_.RiskScore -ge 10
    } |
    Sort-Object RiskScore -Descending

### Historical Logging

$HistoryFile = "C:\Temp\Reports\QuarantineHistory.csv"

$History = Import-Csv `
    "C:\Temp\Reports\QuarantineHistory.csv"
$HistoricalTopDomains = $History |
    ForEach-Object {

        [PSCustomObject]@{
            Domain = ($_.SenderAddress -split "@")[-1]
        }

    } |
    Group-Object Domain |
    Sort-Object Count -Descending |
    Select-Object Count, Name -First 20

$HistoricalDomains = $History |
    ForEach-Object {
        ($_.SenderAddress -split "@")[-1]
    } |
    Select-Object -Unique
$TodayDomains = $Domains.Domain |
    Select-Object -Unique

$NewDomains = $TodayDomains |
    Where-Object {
        $_ -notin $HistoricalDomains
    } |
    Sort-Object

if (Test-Path $HistoryFile) {
    $messages | Export-Csv $HistoryFile -Append -NoTypeInformation
}
else {
    $messages | Export-Csv $HistoryFile -NoTypeInformation
}

### HTML Report

$HTML = @"

<html>

<head>

<style>

body {
    font-family: Segoe UI;
    margin: 20px;
}

table {
    border-collapse: collapse;
    width: 100%;
    margin-bottom: 20px;
}

th {
    background-color: #0078D4;
    color: white;
}

th, td {
    border: 1px solid #cccccc;
    padding: 8px;
}

h1 {
    color: #0078D4;
}

</style>

</head>

<body>

<h1>Email Hygiene Report</h1>

<h2>Threat Summary</h2>

$($ThreatSummary | ConvertTo-Html -Fragment)

<h2>VirusTotal Domain Reputation</h2>
$($VTResults | ConvertTo-Html -Fragment)
<h2>Risk Scoring</h2>

$($RiskScores | ConvertTo-Html -Fragment)

<h2>High Risk Findings</h2>

$($HighRiskFindings | ConvertTo-Html -Fragment)

<h2>Top Sender Domains</h2>

$($TopDomains | ConvertTo-Html -Fragment)

<h2>Top Recipients</h2>

$($TopRecipients | ConvertTo-Html -Fragment)

<h2>Top Subjects</h2>

$($TopSubjects | ConvertTo-Html -Fragment)

<h2>Recent High Confidence Phish</h2>

$($HighPhish | Select-Object -First 25 | ConvertTo-Html -Fragment)

<h2>Header Intelligence (Sample Phish)</h2>

$($HeaderIntel | ConvertTo-Html -Fragment)

</body>

</html>

"@

### Save Report

$ReportFolder = "C:\Temp\Reports"

if (-not (Test-Path $ReportFolder)) {
    New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
}

$HTML | Out-File "$ReportFolder\EmailHygiene.html"

Write-Host "Report saved to $ReportFolder\EmailHygiene.html"

$History = Import-Csv "C:\Temp\Reports\QuarantineHistory.csv"
$HistoricalRecipients = $History |
    Group-Object RecipientAddress |
    Sort-Object Count -Descending |
    Select-Object Count, Name -First 20

### High Confidence Phish

$HighPhish = $messages |
    Where-Object {
        $_.Type -eq "High Confidence Phish"
    } |
    Select-Object `
        ReceivedTime,
        SenderAddress,
        RecipientAddress,
        Subject

$FirstPhish = $messages |
    Where-Object {
        $_.Type -eq "High Confidence Phish"
    } |
    Select-Object -First 1

if ($FirstPhish) {

    $Header = Get-QuarantineMessageHeader `
        -Identity $FirstPhish.Identity

}

function Get-VTIPInfo {

    param($IP)

    try {

        $Result = Invoke-RestMethod `
            -Uri "https://www.virustotal.com/api/v3/ip_addresses/$IP" `
            -Headers @{
                "x-apikey" = $VTApiKey
            }

        [PSCustomObject]@{
            IP         = $IP
            Malicious  = $Result.data.attributes.last_analysis_stats.malicious
            Suspicious = $Result.data.attributes.last_analysis_stats.suspicious
        }

    }
    catch {

        [PSCustomObject]@{
            IP         = $IP
            Malicious  = 0
            Suspicious = 0
        }

    }

}

### VirusTotal
