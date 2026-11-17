# 1. Connect with the correct delegated permissions
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.AccessAsUser.All" -UseDeviceCode

# 2. Define the user and the new password change account to reflect org
$userId = "ACCOUNT@DOMAIN.com"

$params = @{
    passwordProfile = @{
        password = "Tiger7@Moon"
        forceChangePasswordNextSignIn = $false
    }
}

# 3. Apply the password update
Update-MgUser -UserId $userId -BodyParameter $params



### CHANGE password to desired length and complexity
$params = @{
    passwordProfile = @{
        password = "Tiger7@Moon"
        forceChangePasswordNextSignIn = $false
    }
}
#### Change account to reflect #2
Update-MgUser -UserId "ACCOUNT@DOMAIN.com" -BodyParameter $params



