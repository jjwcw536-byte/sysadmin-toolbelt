Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global state
$script:running = $false
$script:interval = 30
$script:timerDuration = 0
$script:elapsed = 0

# Use built-in Windows icon
$defaultIcon = [System.Drawing.SystemIcons]::Information

# --- FORM SETUP (Dark Mode) ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Keep Desktop Awake"
$form.Size = New-Object System.Drawing.Size(350,220)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$form.ForeColor = [System.Drawing.Color]::White

# Interval label
$lblInterval = New-Object System.Windows.Forms.Label
$lblInterval.Text = "Interval (seconds):"
$lblInterval.Location = New-Object System.Drawing.Point(10,20)
$lblInterval.ForeColor = $form.ForeColor
$form.Controls.Add($lblInterval)

# Interval numeric box
$numInterval = New-Object System.Windows.Forms.NumericUpDown
$numInterval.Location = New-Object System.Drawing.Point(150,18)
$numInterval.Minimum = 5
$numInterval.Maximum = 300
$numInterval.Value = 30
$form.Controls.Add($numInterval)

# Timer duration label
$lblTimer = New-Object System.Windows.Forms.Label
$lblTimer.Text = "Auto-stop after (minutes):"
$lblTimer.Location = New-Object System.Drawing.Point(10,60)
$lblTimer.ForeColor = $form.ForeColor
$form.Controls.Add($lblTimer)

# Timer duration numeric box
$numTimer = New-Object System.Windows.Forms.NumericUpDown
$numTimer.Location = New-Object System.Drawing.Point(150,58)
$numTimer.Minimum = 0
$numTimer.Maximum = 480
$numTimer.Value = 0
$form.Controls.Add($numTimer)

# Heartbeat indicator
$heartbeat = New-Object System.Windows.Forms.Label
$heartbeat.Text = "●"
$heartbeat.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$heartbeat.Location = New-Object System.Drawing.Point(300,10)
$heartbeat.ForeColor = [System.Drawing.Color]::DarkRed
$form.Controls.Add($heartbeat)

# Start/Stop button
$btnToggle = New-Object System.Windows.Forms.Button
$btnToggle.Text = "Start"
$btnToggle.Location = New-Object System.Drawing.Point(10,100)
$btnToggle.Size = New-Object System.Drawing.Size(310,30)
$form.Controls.Add($btnToggle)

# Stealth mode checkbox
$chkStealth = New-Object System.Windows.Forms.CheckBox
$chkStealth.Text = "Start in stealth mode (tray only)"
$chkStealth.Location = New-Object System.Drawing.Point(10,140)
$chkStealth.ForeColor = $form.ForeColor
$form.Controls.Add($chkStealth)

# --- TRAY ICON ---
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $defaultIcon
$tray.Visible = $true
$tray.Text = "Keep Desktop Awake"

# Tray menu
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemShow = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemShow.Text = "Show Window"
$menu.Items.Add($menuItemShow)

$menuItemExit = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemExit.Text = "Exit"
$menu.Items.Add($menuItemExit)

$tray.ContextMenuStrip = $menu

# Worker timer
$worker = New-Object System.Windows.Forms.Timer
$worker.Interval = 1000

# --- BUTTON LOGIC ---
$btnToggle.Add_Click({
    if (-not $script:running) {
        $script:running = $true
        $script:interval = [int]$numInterval.Value
        $script:timerDuration = [int]$numTimer.Value
        $script:elapsed = 0
        $btnToggle.Text = "Stop"
        $tray.ShowBalloonTip(1000, "Keep Awake", "Script started.", [System.Windows.Forms.ToolTipIcon]::Info)
        $worker.Start()
    } else {
        $script:running = $false
        $btnToggle.Text = "Start"
        $tray.ShowBalloonTip(1000, "Keep Awake", "Script stopped.", [System.Windows.Forms.ToolTipIcon]::Info)
        $worker.Stop()
        $heartbeat.ForeColor = [System.Drawing.Color]::DarkRed
    }
})

# --- TRAY MENU LOGIC ---
$menuItemShow.Add_Click({
    $form.Show()
    $form.WindowState = "Normal"
})

$menuItemExit.Add_Click({
    $tray.Visible = $false
    $form.Close()
})

# --- WORKER LOOP ---
$worker.Add_Tick({
    if ($script:running) {
        $script:elapsed++

        # Auto-stop timer
        if ($script:timerDuration -gt 0 -and ($script:elapsed / 60) -ge $script:timerDuration) {
            $script:running = $false
            $btnToggle.Text = "Start"
            $tray.ShowBalloonTip(1000, "Keep Awake", "Auto-stop timer reached.", [System.Windows.Forms.ToolTipIcon]::Info)
            $worker.Stop()
            return
        }

        # Pulse
        if ($script:elapsed % $script:interval -eq 0) {
            [System.Windows.Forms.SendKeys]::SendWait("{SCROLLLOCK}")

            # Heartbeat flash
            $heartbeat.ForeColor = [System.Drawing.Color]::LimeGreen
            Start-Sleep -Milliseconds 150
            $heartbeat.ForeColor = [System.Drawing.Color]::DarkRed
        }
    }
})

# --- STEALTH MODE ---
$form.Add_Shown({
    if ($chkStealth.Checked) {
        $form.Hide()
    }
})

# --- CLEAN EXIT ---
$form.Add_FormClosing({
    $tray.Visible = $false
})

# Run
[System.Windows.Forms.Application]::Run($form)