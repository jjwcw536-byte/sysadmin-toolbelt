Import-Module ActiveDirectory

Get-ADUser -Filter { Enabled -eq $true }
    Select-Object DisplayName,SamAccountName,EmailAddress,Department,LastLogonDate |
    Export-Csv -Path "C:\Reports\ActiveUsers.csv" -NoTypeInformation -Encoding UTF8




##################  USE THE BELOW FOR JUST USER FULL NAMES

Import-Module ActiveDirectory

Get-ADUser -Filter "Enabled -eq 'True'" -Properties DisplayName,EmailAddress,Department,LastLogonDate |
    Select-Object DisplayName |
    Export-Csv -Path "C:\Temp\Reports\ActiveUsers.csv" -NoTypeInformation -Encoding UTF8



############## REMOVE Duplicates from the list
$master     = Import-Csv "C:\Temp\Reports\Master.csv"
$responded  = Import-Csv "C:\Temp\Reports\Responded.csv"

# Get only names from responded list
$respondedNames = $responded.DisplayName

# Filter master list to exclude responded users
$notResponded = $master | Where-Object { $_.DisplayName -notin $respondedNames }

# Export final list
$notResponded | Export-Csv "C:\Temp\Reports\NotResponded.csv" -NoTypeInformation
