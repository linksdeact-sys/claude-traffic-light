Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ClaudeTrafficLightWin32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@

$script:root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:stateFile = Join-Path $script:root "state.txt"
$script:instancesDir = Join-Path $script:root "instances"
$script:mutex = $null
$script:lastSignature = ""
$script:sessionItems = @{}

$createdNew = $false
$script:mutex = [System.Threading.Mutex]::new($true, "ClaudeTrafficLightDashboard", [ref]$createdNew)
if (-not $createdNew) { exit 0 }

function New-Brush([string]$hex) {
    return [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($hex))
}

function Get-StateStyle([string]$state) {
    switch -Regex ($state) {
        "ACTION" {
            return [pscustomobject]@{ Accent = "#FFCC00"; Soft = "#FFF9DE"; Text = "ACTION"; Hint = "needs you" }
        }
        "RUNNING" {
            return [pscustomobject]@{ Accent = "#34C759"; Soft = "#F2FFF6"; Text = "RUNNING"; Hint = "working" }
        }
        default {
            return [pscustomobject]@{ Accent = "#0A84FF"; Soft = "#F7FAFF"; Text = "DONE"; Hint = "idle" }
        }
    }
}

function Test-ProcessAlive([object]$pidValue) {
    try {
        if ($null -eq $pidValue) { return $false }
        $processId = [int]$pidValue
        return $null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Get-SessionRecords {
    if (-not (Test-Path -LiteralPath $script:instancesDir)) {
        New-Item -ItemType Directory -Force -Path $script:instancesDir | Out-Null
    }

    $records = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $script:instancesDir -File -Filter "*.json" -ErrorAction SilentlyContinue)) {
        try {
            $record = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
            $alive = Test-ProcessAlive $record.ownerPid
            if (-not $alive) {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
                continue
            }
            $record | Add-Member -NotePropertyName filePath -NotePropertyValue $file.FullName -Force
            $records += $record
        } catch {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    return @($records | Sort-Object createdAt)
}

function Focus-ClaudeSession([object]$record) {
    $candidatePids = @()
    foreach ($pidName in @("ownerPid", "parentPid")) {
        if ($record.PSObject.Properties.Name -contains $pidName -and $record.$pidName) {
            $candidatePids += [int]$record.$pidName
        }
    }

    $current = if ($record.ownerPid) { [int]$record.ownerPid } else { $null }
    for ($i = 0; $i -lt 8 -and $current; $i++) {
        try {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$current" -ErrorAction Stop
            if ($proc.ParentProcessId) {
                $candidatePids += [int]$proc.ParentProcessId
                $current = [int]$proc.ParentProcessId
            } else {
                break
            }
        } catch {
            break
        }
    }

    foreach ($candidatePid in @($candidatePids | Select-Object -Unique)) {
        try {
            $process = Get-Process -Id $candidatePid -ErrorAction Stop
            if ($process.MainWindowHandle -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
                [ClaudeTrafficLightWin32]::ShowWindowAsync($process.MainWindowHandle, 9) | Out-Null
                [ClaudeTrafficLightWin32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
                return
            }
        } catch {}
    }
}

function New-SessionRow([object]$record, [int]$index) {
    $style = Get-StateStyle ([string]$record.state)

    $row = New-Object System.Windows.Controls.Border
    $row.Height = 26
    $row.Margin = [System.Windows.Thickness]::new(0, 5, 0, 0)
    $row.CornerRadius = [System.Windows.CornerRadius]::new(11)
    $row.BorderThickness = [System.Windows.Thickness]::new(1)
    $row.BorderBrush = New-Brush "#E4EAF2"
    $row.Background = New-Brush $style.Soft
    $row.Cursor = [System.Windows.Input.Cursors]::Hand
    $row.Tag = $record

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = [System.Windows.Thickness]::new(8, 0, 8, 0)
    $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(8) })) | Out-Null
    $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })) | Out-Null
    $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(58) })) | Out-Null

    $bar = New-Object System.Windows.Shapes.Rectangle
    $bar.Width = 5
    $bar.Height = 16
    $bar.RadiusX = 3
    $bar.RadiusY = 3
    $bar.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $bar.Fill = New-Brush $style.Accent
    [System.Windows.Controls.Grid]::SetColumn($bar, 0)

    $name = if ($record.title) { [string]$record.title } else { "Claude" }
    $shortId = if ($record.id) { ([string]$record.id).Substring(0, [Math]::Min(6, ([string]$record.id).Length)) } else { "session" }
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = "#{0} {1}" -f $index, $name
    $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $label.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    $label.FontFamily = "Segoe UI"
    $label.FontSize = 11
    $label.Foreground = New-Brush "#293142"
    $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetColumn($label, 1)

    $statusText = New-Object System.Windows.Controls.TextBlock
    $statusText.Text = $style.Text
    $statusText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $statusText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $statusText.FontFamily = "Segoe UI"
    $statusText.FontSize = 9
    $statusText.FontWeight = [System.Windows.FontWeights]::Bold
    $statusText.Foreground = New-Brush $style.Accent
    [System.Windows.Controls.Grid]::SetColumn($statusText, 2)

    $tooltip = "id: $shortId`npid: $($record.ownerPid)`nworkspace: $($record.workspace)"
    $row.ToolTip = $tooltip

    $grid.Children.Add($bar) | Out-Null
    $grid.Children.Add($label) | Out-Null
    $grid.Children.Add($statusText) | Out-Null
    $row.Child = $grid

    $row.Add_MouseEnter({ $this.BorderBrush = New-Brush "#C9D4E4" })
    $row.Add_MouseLeave({ $this.BorderBrush = New-Brush "#E4EAF2" })
    $row.Add_PreviewMouseLeftButtonDown({
        $_.Handled = $true
        Focus-ClaudeSession $this.Tag
    })

    return $row
}

function Update-Dashboard {
    $records = @(Get-SessionRecords)
    if ($records.Count -eq 0) {
        $window.Close()
        return
    }

    $signatureParts = @()
    foreach ($record in $records) {
        $signatureParts += "{0}:{1}:{2}" -f $record.id, $record.state, $record.updatedAt
    }
    $signature = $signatureParts -join "|"
    if ($signature -eq $script:lastSignature) { return }
    $script:lastSignature = $signature

    $RowsPanel.Children.Clear()
    for ($i = 0; $i -lt $records.Count; $i++) {
        $RowsPanel.Children.Add((New-SessionRow $records[$i] ($i + 1))) | Out-Null
    }

    $visibleRows = [Math]::Min($records.Count, 10)
    $RowsScroll.MaxHeight = [double](31 * $visibleRows)
    $window.Height = [double](74 + (31 * $visibleRows))

    $countText.Text = [string]$records.Count
    $firstStyle = Get-StateStyle ([string]$records[0].state)
    $outer.BorderBrush = New-Brush $firstStyle.Accent
    $dot.Fill = New-Brush $firstStyle.Accent
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="252" Height="105"
        WindowStyle="None" ResizeMode="NoResize"
        AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False"
        SnapsToDevicePixels="False" UseLayoutRounding="True">
    <Grid Margin="6">
        <Border x:Name="Outer" CornerRadius="20" BorderThickness="3" Background="#F7FAFF" BorderBrush="#0A84FF">
            <Border.Effect>
                <DropShadowEffect Color="#330A84FF" BlurRadius="12" ShadowDepth="1" Opacity="0.35" />
            </Border.Effect>
            <Grid Margin="16,12,14,12">
                <Grid.RowDefinitions>
                    <RowDefinition Height="25" />
                    <RowDefinition Height="*" />
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="16" />
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="32" />
                    <ColumnDefinition Width="24" />
                </Grid.ColumnDefinitions>

                <Ellipse x:Name="Dot" Grid.Row="0" Grid.Column="0" Width="10" Height="10" VerticalAlignment="Center" Fill="#0A84FF" />
                <TextBlock Grid.Row="0" Grid.Column="1" Text="Claude Sessions" VerticalAlignment="Center"
                           FontFamily="Segoe UI" FontSize="13" Foreground="#596273" />
                <TextBlock x:Name="CountText" Grid.Row="0" Grid.Column="2" Text="0" VerticalAlignment="Center" HorizontalAlignment="Center"
                           FontFamily="Segoe UI" FontSize="12" FontWeight="Bold" Foreground="#697386" />
                <TextBlock x:Name="CloseButton" Grid.Row="0" Grid.Column="3" Text="x"
                           VerticalAlignment="Center" HorizontalAlignment="Center"
                           FontFamily="Segoe UI" FontSize="14" Foreground="#A4ADBA"
                           Cursor="Hand" Padding="6,1,6,3" />

                <ScrollViewer x:Name="RowsScroll" Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="4"
                              VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <StackPanel x:Name="RowsPanel" />
                </ScrollViewer>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$outer = $window.FindName("Outer")
$dot = $window.FindName("Dot")
$countText = $window.FindName("CountText")
$closeButton = $window.FindName("CloseButton")
$RowsScroll = $window.FindName("RowsScroll")
$RowsPanel = $window.FindName("RowsPanel")

$screen = [System.Windows.SystemParameters]::WorkArea
$window.Left = $screen.Right - $window.Width - 18
$window.Top = $screen.Top + 90

$closeButton.Add_MouseEnter({ $closeButton.Foreground = New-Brush "#5F6B7A" })
$closeButton.Add_MouseLeave({ $closeButton.Foreground = New-Brush "#A4ADBA" })
$closeButton.Add_PreviewMouseLeftButtonDown({
    $_.Handled = $true
    $window.Close()
})
$window.Add_MouseLeftButtonDown({
    if ($_.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        try { $window.DragMove() } catch {}
    }
})

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(180)
$timer.Add_Tick({ Update-Dashboard })
$window.Add_Loaded({ Update-Dashboard; $timer.Start() })
$window.Add_Closed({
    $timer.Stop()
    if ($script:mutex) {
        try { $script:mutex.ReleaseMutex() } catch {}
        $script:mutex.Dispose()
    }
})
[void]$window.ShowDialog()
