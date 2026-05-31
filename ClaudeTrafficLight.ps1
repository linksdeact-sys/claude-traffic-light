Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:root = "D:\ClaudeTrafficLight"
$script:stateFile = Join-Path $script:root "state.txt"

function Stop-OtherLights {
    try {
        Get-CimInstance Win32_Process -Filter "name='powershell.exe'" |
            Where-Object {
                $_.ProcessId -ne $PID -and
                $_.CommandLine -and
                $_.CommandLine -match '(?i)-File\s+.*ClaudeTrafficLight\.ps1'
            } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch {}
}

function Get-ClaudeState {
    if (-not (Test-Path -LiteralPath $script:stateFile)) { return "blue" }
    try {
        $flag = (Get-Content -LiteralPath $script:stateFile -Raw -ErrorAction Stop).Trim().ToUpperInvariant()
    } catch {
        return "blue"
    }
    if ($flag -match 'ACTION') { return "yellow" }
    if ($flag -match 'RUNNING') { return "green" }
    return "blue"
}

function New-Brush([string]$hex) {
    return [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($hex))
}

function Set-LightTheme([string]$state) {
    if ($script:currentState -eq $state) { return }
    $script:currentState = $state

    switch ($state) {
        "green" {
            $accent = "#34C759"
            $soft = "#F2FFF6"
            $text = "RUNNING"
            $hint = "working"
        }
        "yellow" {
            $accent = "#FFCC00"
            $soft = "#FFF9DE"
            $text = "ACTION"
            $hint = "needs you"
        }
        default {
            $accent = "#0A84FF"
            $soft = "#F7FAFF"
            $text = "DONE"
            $hint = "idle"
        }
    }

    $outer.BorderBrush = New-Brush $accent
    $outer.Background = New-Brush $soft
    $dot.Fill = New-Brush $accent
    $status.Text = $text
    $sub.Text = $hint
}

Stop-OtherLights

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="188" Height="108"
        WindowStyle="None" ResizeMode="NoResize"
        AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False"
        SnapsToDevicePixels="False" UseLayoutRounding="True">
    <Grid Margin="6">
        <Border x:Name="Outer" CornerRadius="20" BorderThickness="3" Background="#F7FAFF" BorderBrush="#0A84FF">
            <Border.Effect>
                <DropShadowEffect Color="#330A84FF" BlurRadius="12" ShadowDepth="1" Opacity="0.35" />
            </Border.Effect>
            <Grid Margin="18,13,16,13">
                <Grid.RowDefinitions>
                    <RowDefinition Height="22" />
                    <RowDefinition Height="38" />
                    <RowDefinition Height="18" />
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="16" />
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="24" />
                </Grid.ColumnDefinitions>

                <Ellipse x:Name="Dot" Grid.Row="0" Grid.Column="0" Width="10" Height="10" VerticalAlignment="Center" Fill="#0A84FF" />
                <TextBlock x:Name="Title" Grid.Row="0" Grid.Column="1" Text="Claude" VerticalAlignment="Center"
                           FontFamily="Segoe UI" FontSize="13" Foreground="#596273" />
                <Button x:Name="CloseButton" Grid.Row="0" Grid.Column="2" Content="x"
                        VerticalAlignment="Center" HorizontalAlignment="Center" Width="22" Height="22"
                        FontFamily="Segoe UI" FontSize="14" Foreground="#9AA3B2"
                        Background="Transparent" BorderThickness="0" Padding="0" Cursor="Hand" Focusable="False" />

                <TextBlock x:Name="Status" Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="3" Text="DONE"
                           VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="26" FontWeight="Bold"
                           Foreground="#121826" />
                <TextBlock x:Name="Sub" Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Text="idle"
                           VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="13" Foreground="#697386" />
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$outer = $window.FindName("Outer")
$dot = $window.FindName("Dot")
$status = $window.FindName("Status")
$sub = $window.FindName("Sub")
$closeButton = $window.FindName("CloseButton")

$screen = [System.Windows.SystemParameters]::WorkArea
$window.Left = $screen.Right - $window.Width - 18
$window.Top = $screen.Top + 90

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
$timer.Interval = [TimeSpan]::FromMilliseconds(80)
$timer.Add_Tick({ Set-LightTheme (Get-ClaudeState) })
$window.Add_Loaded({ $script:currentState = ""; Set-LightTheme (Get-ClaudeState); $timer.Start() })
$window.Add_Closed({ $timer.Stop() })
[void]$window.ShowDialog()
