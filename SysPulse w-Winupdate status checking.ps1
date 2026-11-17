Invoke-Command -ComputerName "COMPUTER" -ScriptBlock {
    $healthReport = @{}

   
    # Safely fetch OS info
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os) {
        # CPU Usage
        $cpuLoad = Get-Counter '\Processor(_Total)\% Processor Time'
        $healthReport["CPU Usage (%)"] = [math]::Round($cpuLoad.CounterSamples[0].CookedValue, 2)

        # Memory Usage
        $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeMem = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $healthReport["Total Memory (GB)"] = $totalMem
        $healthReport["Free Memory (GB)"] = $freeMem
        $healthReport["Memory Usage (%)"] = if ($totalMem -ne 0) {
            [math]::Round((1 - ($freeMem / $totalMem)) * 100, 2)
        } else {
            "N/A"
        }
    }

    # Disk Info
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $diskReport = foreach ($drive in $drives) {
        if ($drive.Size -ne 0) {
            [PSCustomObject]@{
                Drive        = $drive.DeviceID
                FreeSpaceGB  = [math]::Round($drive.FreeSpace / 1GB, 2)
                TotalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
                UsagePercent = [math]::Round((1 - ($drive.FreeSpace / $drive.Size)) * 100, 2)
            }
        }
    }
    $healthReport["Disk Info"] = $diskReport

    # Network Ping Test
    $netConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }
    $gateway = if ($netConfig) { $netConfig[0].IPv4DefaultGateway.NextHop } else { $null }
    if ($gateway) {
        $ping = Test-Connection -ComputerName $gateway -Count 1 -Quiet
    } else {
        $ping = $false
    }
    $healthReport["Network Connectivity"] = if ($ping) { "OK" } else { "FAILED" }

    # Critical Event Logs
    $criticalEvents = @()
    foreach ($log in @("System", "Application", "Security")) {
        try {
            $events = Get-WinEvent -LogName $log -FilterHashtable @{
                Level     = 1
                StartTime = (Get-Date).AddHours(-24)
            } -ErrorAction SilentlyContinue

            if ($events) {
                $criticalEvents += $events | Select-Object -First 5 | ForEach-Object {
                    $msg = if ($_.Message) {
                        $_.Message.Substring(0, [math]::Min($_.Message.Length, 150)) + "..."
                    } else {
                        "No message available."
                    }
                    @{
                        Log     = $log
                        Time    = $_.TimeCreated
                        Source  = $_.ProviderName
                        EventID = $_.Id
                        Message = $msg
                    }
                }
            }
        } catch {
            # Silent continue
        }
    }

    # Dell Command | Update pending updates
try {
    $dcuPath = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
    if (Test-Path $dcuPath) {
        $dcuResult = & "$dcuPath" /list
        $pendingUpdates = ($dcuResult | Select-String "Recommended Update" -SimpleMatch).Count

        if ($pendingUpdates -gt 0) {
            $healthReport["Dell Command Updates"] = "$pendingUpdates update(s) available"
        } else {
            $healthReport["Dell Command Updates"] = "Up to date"
        }
    } else {
        $healthReport["Dell Command Updates"] = "DCU CLI not found"
    }
} catch {
    $healthReport["Dell Command Updates"] = "Unable to check"
}

    # Windows Update Status
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")

        if ($searchResult.Updates.Count -eq 0) {
            $healthReport["Windows Update Status"] = "Up to date"
        } else {
            $healthReport["Windows Update Status"] = "$($searchResult.Updates.Count) pending update(s)"
        }
    } catch {
        $healthReport["Windows Update Status"] = "Unable to check"
    }

    # Pending Restart Check
try {
    $rebootRequired = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "RebootRequired" -ErrorAction SilentlyContinue
    if ($rebootRequired) {
        $healthReport["Pending Restart"] = "Yes"
    } else {
        $healthReport["Pending Restart"] = "No"
    }
} catch {
    $healthReport["Pending Restart"] = "Unable to check"
}


    $healthReport["Critical Event Logs (24hrs)"] = $criticalEvents.Count
    $healthReport["Recent Critical Events"] = $criticalEvents

    return $healthReport
}