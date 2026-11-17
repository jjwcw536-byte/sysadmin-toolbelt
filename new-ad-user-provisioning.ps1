# Run on a domain-joined computer with the Active Directory module installed.
Import-Module ActiveDirectory


## Replace "Username","Full name", "Temporary password" with new user to create. Add/replace in quotes "" for groups to assign separated by a comma , between each "group name"

$username = Read-Host "Username"
$fullName = Read-Host "Full name"
$password = Read-Host "Temporary password" -AsSecureString
$groups = "SharePoint Users", "All Employees"

New-ADUser `
    -SamAccountName $username `
    -Name $fullName `
    -DisplayName $fullName `
    -Enabled $true `
    -AccountPassword $password `
    -ChangePasswordAtLogon $true

foreach ($group in $groups) {
    Add-ADGroupMember -Identity $group -Members $username
}
