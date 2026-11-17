

# use this to initiate the remote session in Powershell and run SFC /scannow w/o prompting on remote computer
Enter-PSSession -Computer dedham01



#### Configure what to clean (one time)
cleanmgr /sageset:1

######
Start-Process cleanmgr.exe -ArgumentList "/sagerun:1" -WindowStyle Hidden

#### TO CONFIRM IT RAN ###
tasklist | findstr cleanmgr

### Temp Cleanup
del /f /s /q %TEMP%\*
del /f /s /q C:\Windows\Temp\*



### TO CHECK IF RAN
Get-PSDrive C

###CHECK Component store
DISM /Online /Cleanup-Image /AnalyzeComponentStore

#### CLEANUP Component Store
DISM /Online /Cleanup-Image /StartComponentCleanup


####### Find waht is taking up space.....
PowerShell
Get-ChildItem C:\ -Directory |
ForEach-Object {
$size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
Measure-Object Length -Sum).Sum
[PSCustomObject]@{
Folder = $_.FullName
SizeGB = "{0:N2}" -f ($size / 1GB)
}
} | Sort-Object SizeGB -Descending



##### USE THIS TO CHECK WINDOWS UPDATE CACHING

(Get-ChildItem "C:\Windows\SoftwareDistribution\Download" -Recurse -Force -ErrorAction SilentlyContinue |
Measure-Object Length -Sum).Sum / 1GB


### Check profile size
Get-ChildItem C:\Users -Directory | ForEach-Object {
$size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
Measure-Object Length -Sum).Sum
 
[PSCustomObject]@{
User = $_.Name
SizeGB = [math]::Round($size / 1GB, 2)
}
} | Sort-Object SizeGB -Descending


#### Run against Edge profile

Get-ChildItem "C:\Users\USERProfile\AppData\Local\Microsoft\Edge\User Data" -Directory |
ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum).Sum

    [PSCustomObject]@{
        Folder = $_.Name
        SizeGB = [math]::Round($size / 1GB,, 2)
    }
} | Sort-Object SizeGB -Descending


##### Checking C

Get-ChildItem C:\ -Directory | ForEach-Object {
$size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
Measure-Object Length -Sum).Sum
 
[PSCustomObject]@{
User = $_.Name
SizeGB = [math]::Round($size / 1GB, 2)
}
} | Sort-Object SizeGB -Descending