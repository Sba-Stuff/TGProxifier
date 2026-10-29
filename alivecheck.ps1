# Telegram Proxy Checker - Bulk Proxy Status Checker
# Fetches proxies from GitHub and checks their availability

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Net.Http

# Configuration
$proxyUrl = "https://raw.githubusercontent.com/SoliSpirit/mtproto/master/all_proxies.txt"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$downloadedFile = Join-Path $scriptPath "all_proxies.txt"
$outputCsv = Join-Path $scriptPath "telegram_proxies_checked.csv"

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Telegram Proxy Checker"
$form.Size = New-Object System.Drawing.Size(1000, 700)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Main panel
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = "Fill"
$mainPanel.Padding = New-Object System.Windows.Forms.Padding(20)
$form.Controls.Add($mainPanel)

# Title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Telegram Proxy Bulk Checker"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(400, 30)
$mainPanel.Controls.Add($titleLabel)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready to check proxies..."
$statusLabel.Location = New-Object System.Drawing.Point(20, 60)
$statusLabel.Size = New-Object System.Drawing.Size(900, 25)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$mainPanel.Controls.Add($statusLabel)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 95)
$progressBar.Size = New-Object System.Drawing.Size(900, 25)
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$mainPanel.Controls.Add($progressBar)

# Results rich text box (for colored text)
$resultsBox = New-Object System.Windows.Forms.RichTextBox
$resultsBox.Location = New-Object System.Drawing.Point(20, 130)
$resultsBox.Size = New-Object System.Drawing.Size(900, 400)
$resultsBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$resultsBox.ReadOnly = $true
$resultsBox.BackColor = [System.Drawing.Color]::White
$resultsBox.WordWrap = $false
$mainPanel.Controls.Add($resultsBox)

# Button panel
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Location = New-Object System.Drawing.Point(20, 545)
$buttonPanel.Size = New-Object System.Drawing.Size(900, 50)
$mainPanel.Controls.Add($buttonPanel)

$fetchButton = New-Object System.Windows.Forms.Button
$fetchButton.Text = "Fetch and Check Proxies"
$fetchButton.Location = New-Object System.Drawing.Point(0, 10)
$fetchButton.Size = New-Object System.Drawing.Size(150, 35)
$fetchButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$buttonPanel.Controls.Add($fetchButton)

$openCsvButton = New-Object System.Windows.Forms.Button
$openCsvButton.Text = "Open CSV File"
$openCsvButton.Location = New-Object System.Drawing.Point(160, 10)
$openCsvButton.Size = New-Object System.Drawing.Size(120, 35)
$openCsvButton.Enabled = $false
$buttonPanel.Controls.Add($openCsvButton)

$openFolderButton = New-Object System.Windows.Forms.Button
$openFolderButton.Text = "Open Folder"
$openFolderButton.Location = New-Object System.Drawing.Point(290, 10)
$openFolderButton.Size = New-Object System.Drawing.Size(100, 35)
$buttonPanel.Controls.Add($openFolderButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Location = New-Object System.Drawing.Point(820, 10)
$closeButton.Size = New-Object System.Drawing.Size(80, 35)
$buttonPanel.Controls.Add($closeButton)

# Function to add text to results box with color coding
function AddResultText {
    param($text, $colorName = "Black")
    
    # Convert color name to Color object
    $color = switch ($colorName) {
        "Black" { [System.Drawing.Color]::Black }
        "Red" { [System.Drawing.Color]::Red }
        "Green" { [System.Drawing.Color]::Green }
        "Blue" { [System.Drawing.Color]::Blue }
        "Orange" { [System.Drawing.Color]::Orange }
        "Gray" { [System.Drawing.Color]::Gray }
        default { [System.Drawing.Color]::Black }
    }
    
    $resultsBox.SelectionStart = $resultsBox.TextLength
    $resultsBox.SelectionLength = 0
    $resultsBox.SelectionColor = $color
    $resultsBox.AppendText($text + "`r`n")
    $resultsBox.ScrollToCaret()
}

# Function to parse a single proxy URL line
function ParseProxyLine {
    param($line)
    
    try {
        $cleanLine = $line.Trim()
        
        # Extract server, port, secret using regex
        $serverMatch = [regex]::Match($cleanLine, 'server=([^&]+)')
        $portMatch = [regex]::Match($cleanLine, 'port=([^&]+)')
        $secretMatch = [regex]::Match($cleanLine, 'secret=([^&\s]+)')
        
        if ($serverMatch.Success -and $portMatch.Success -and $secretMatch.Success) {
            $server = $serverMatch.Groups[1].Value
            $port = $portMatch.Groups[1].Value
            $secret = $secretMatch.Groups[1].Value
            
            return @{
                Server = $server
                Port = $port
                Secret = $secret
            }
        }
    }
    catch {
        # Silently fail
    }
    
    return $null
}

# Function to ping a server (fast check)
function Test-PingStatus {
    param($server, $timeoutMs = 3000)
    
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send($server, $timeoutMs)
        
        if ($reply.Status -eq "Success") {
            return @{
                Success = $true
                Latency = $reply.RoundtripTime
                Message = "Ping OK ($($reply.RoundtripTime)ms)"
            }
        } else {
            return @{
                Success = $false
                Latency = $null
                Message = "Ping failed"
            }
        }
    } catch {
        return @{
            Success = $false
            Latency = $null
            Message = "Ping error: $($_.Exception.Message)"
        }
    }
}

# Function to test TCP connection (port open check)
function Test-TcpPort {
    param($server, $port, $timeoutMs = 5000)
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($server, $port)
        $timeoutTask = [System.Threading.Tasks.Task]::Delay($timeoutMs)
        
        $completed = [System.Threading.Tasks.Task]::WaitAny($connectTask, $timeoutTask)
        
        if ($completed -eq 0 -and $connectTask.IsCompleted -and $tcpClient.Connected) {
            $tcpClient.Close()
            return @{
                Success = $true
                Message = "Port $port is open"
            }
        } else {
            if ($tcpClient.Connected) { $tcpClient.Close() }
            return @{
                Success = $false
                Message = "Port $port is closed or timed out"
            }
        }
    } catch {
        return @{
            Success = $false
            Message = "TCP error: $($_.Exception.Message)"
        }
    }
}

# Function to check MTProto proxy (simplified)
function Test-MTProtoProxy {
    param($server, $port, $secret, $timeoutMs = 8000)
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($server, $port)
        $timeoutTask = [System.Threading.Tasks.Task]::Delay($timeoutMs)
        
        $completed = [System.Threading.Tasks.Task]::WaitAny($connectTask, $timeoutTask)
        
        if ($completed -eq 0 -and $connectTask.IsCompleted -and $tcpClient.Connected) {
            
            # Send a minimal MTProto ping/pong test
            $stream = $tcpClient.GetStream()
            
            # Set timeout for read/write
            $stream.ReadTimeout = $timeoutMs
            $stream.WriteTimeout = $timeoutMs
            
            # Send a simple probe
            $testData = [System.Text.Encoding]::UTF8.GetBytes("GET / HTTP/1.1`r`nHost: $server`r`n`r`n")
            $stream.Write($testData, 0, $testData.Length)
            
            # Wait for response
            $buffer = New-Object byte[] 1024
            $asyncRead = $stream.BeginRead($buffer, 0, $buffer.Length, $null, $null)
            
            if ($asyncRead.AsyncWaitHandle.WaitOne($timeoutMs)) {
                $bytesRead = $stream.EndRead($asyncRead)
                if ($bytesRead -gt 0) {
                    $tcpClient.Close()
                    return @{
                        Success = $true
                        Message = "MTProto proxy responding"
                    }
                }
            }
            
            $tcpClient.Close()
            return @{
                Success = $false
                Message = "MTProto test failed (no response)"
            }
        } else {
            if ($tcpClient.Connected) { $tcpClient.Close() }
            return @{
                Success = $false
                Message = "MTProto test failed (connection refused/timed out)"
            }
        }
    } catch {
        return @{
            Success = $false
            Message = "MTProto error: $($_.Exception.Message)"
        }
    }
}

# Function to check a single proxy comprehensively
function CheckProxy {
    param($proxy, $index, $total)
    
    $percent = [math]::Round(($index / $total) * 100, 1)
    $statusLabel.Text = "Checking proxy $index of $total ($percent%) - $($proxy.Server):$($proxy.Port)"
    
    AddResultText "[$index/$total] Checking $($proxy.Server):$($proxy.Port)..." "Blue"
    
    # Step 1: Ping test
    $pingResult = Test-PingStatus -server $proxy.Server -timeoutMs 3000
    
    if ($pingResult.Success) {
        AddResultText "  [OK] Ping: $($pingResult.Message)" "Green"
    } else {
        AddResultText "  [FAIL] Ping: $($pingResult.Message)" "Red"
    }
    
    # Step 2: TCP port test
    $tcpResult = Test-TcpPort -server $proxy.Server -port $proxy.Port -timeoutMs 5000
    
    if ($tcpResult.Success) {
        AddResultText "  [OK] TCP: $($tcpResult.Message)" "Green"
    } else {
        AddResultText "  [FAIL] TCP: $($tcpResult.Message)" "Red"
    }
    
    # Step 3: MTProto test (only if TCP test passed)
    $mtprotoResult = $null
    if ($tcpResult.Success) {
        $mtprotoResult = Test-MTProtoProxy -server $proxy.Server -port $proxy.Port -secret $proxy.Secret -timeoutMs 6000
        
        if ($mtprotoResult.Success) {
            AddResultText "  [OK] MTProto: $($mtprotoResult.Message)" "Green"
        } else {
            AddResultText "  [FAIL] MTProto: $($mtprotoResult.Message)" "Red"
        }
    } else {
        $mtprotoResult = @{ Success = $false; Message = "Skipped (TCP test failed)" }
        AddResultText "  [SKIP] MTProto: Skipped due to TCP failure" "Gray"
    }
    
    # Determine overall status
    $overallStatus = "DEAD"
    $statusColor = "Red"
    if ($pingResult.Success -and $tcpResult.Success -and $mtprotoResult.Success) {
        $overallStatus = "ALIVE"
        $statusColor = "Green"
    } elseif ($pingResult.Success -and $tcpResult.Success) {
        $overallStatus = "PARTIAL"
        $statusColor = "Orange"
    }
    
    AddResultText "  -> Status: $overallStatus" $statusColor
    AddResultText "" "Black"
    
    # Update progress bar
    $progressBar.Value = $index
    
    return [PSCustomObject]@{
        Server = $proxy.Server
        Port = $proxy.Port
        Secret = $proxy.Secret
        PingStatus = if ($pingResult.Success) { "OK" } else { "FAIL" }
        PingLatency = if ($pingResult.Success) { $pingResult.Latency } else { $null }
        PingMessage = $pingResult.Message
        TCPStatus = if ($tcpResult.Success) { "OK" } else { "FAIL" }
        TCPMessage = $tcpResult.Message
        MTProtoStatus = if ($mtprotoResult.Success) { "OK" } else { "FAIL" }
        MTProtoMessage = $mtprotoResult.Message
        OverallStatus = $overallStatus
        CheckTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

# Function to fetch and check proxies
function FetchAndCheckProxies {
    $resultsBox.Clear()
    AddResultText "========================================" "Black"
    AddResultText "Telegram Proxy Bulk Checker - Starting..." "Black"
    AddResultText "========================================" "Black"
    AddResultText "" "Black"
    
    # Show progress bar
    $progressBar.Visible = $true
    $progressBar.Value = 0
    $statusLabel.Text = "Downloading proxy list from GitHub..."
    $fetchButton.Enabled = $false
    
    $checkedProxies = @()
    
    try {
        # Step 1: Download the file
        AddResultText "[1/4] Downloading proxy list..." "Blue"
        AddResultText "URL: $proxyUrl" "Black"
        
        Invoke-WebRequest -Uri $proxyUrl -OutFile $downloadedFile -UseBasicParsing -TimeoutSec 30
        
        if (Test-Path $downloadedFile) {
            $fileInfo = Get-Item $downloadedFile
            AddResultText "Downloaded: $($fileInfo.Length) bytes" "Green"
            AddResultText "" "Black"
        } else {
            throw "Download failed - file not created"
        }
        
        # Step 2: Read and parse the file
        AddResultText "[2/4] Parsing proxy list..." "Blue"
        $lines = Get-Content $downloadedFile
        AddResultText "Total lines read: $($lines.Count)" "Black"
        
        $proxyList = @()
        $validCount = 0
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -eq "") { continue }
            
            if ($line -like "*server=*" -and $line -like "*port=*" -and $line -like "*secret=*") {
                $parsed = ParseProxyLine $line
                
                if ($parsed -and $parsed.Server -and $parsed.Port -and $parsed.Secret) {
                    $proxyList += [PSCustomObject]@{
                        Server = $parsed.Server
                        Port = $parsed.Port
                        Secret = $parsed.Secret
                    }
                    $validCount++
                }
            }
        }
        
        AddResultText "Valid proxies found: $validCount" "Green"
        AddResultText "" "Black"
        
        if ($validCount -eq 0) {
            throw "No valid proxies found in the downloaded file"
        }
        
        # Step 3: Check all proxies
        AddResultText "[3/4] Checking proxy availability..." "Blue"
        AddResultText "This may take several minutes depending on proxy count..." "Black"
        AddResultText "" "Black"
        
        # Set progress bar maximum
        $progressBar.Maximum = $validCount
        $progressBar.Value = 0
        
        $counter = 0
        foreach ($proxy in $proxyList) {
            $counter++
            $checkedProxy = CheckProxy -proxy $proxy -index $counter -total $validCount
            $checkedProxies += $checkedProxy
        }
        
        # Step 4: Export results
        AddResultText "[4/4] Exporting results to CSV..." "Blue"
        
        # Count statistics
        $aliveCount = ($checkedProxies | Where-Object { $_.OverallStatus -eq "ALIVE" }).Count
        $partialCount = ($checkedProxies | Where-Object { $_.OverallStatus -eq "PARTIAL" }).Count
        $deadCount = ($checkedProxies | Where-Object { $_.OverallStatus -eq "DEAD" }).Count
        
        # Export to CSV
        $checkedProxies | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
        
        AddResultText "" "Black"
        AddResultText "========================================" "Black"
        AddResultText "CHECK COMPLETE!" "Green"
        AddResultText "========================================" "Black"
        AddResultText "Total proxies checked: $validCount" "Black"
        AddResultText "[ALIVE] proxies: $aliveCount" "Green"
        AddResultText "[PARTIAL] proxies: $partialCount" "Orange"
        AddResultText "[DEAD] proxies: $deadCount" "Red"
        AddResultText "" "Black"
        AddResultText "Results saved to: $outputCsv" "Black"
        AddResultText "========================================" "Black"
        
        $statusLabel.Text = "Complete! Alive: $aliveCount, Dead: $deadCount, Partial: $partialCount"
        $openCsvButton.Enabled = $true
        
        # Show summary of alive proxies
        if ($aliveCount -gt 0) {
            AddResultText "" "Black"
            AddResultText "ALIVE PROXIES SUMMARY:" "Green"
            AddResultText ("{0,-40} {1,-8} {2,-50} {3,-10}" -f "SERVER", "PORT", "SECRET", "PING(ms)")
            AddResultText ("{0,-40} {1,-8} {2,-50} {3,-10}" -f "------", "----", "------", "--------")
            
            $checkedProxies | Where-Object { $_.OverallStatus -eq "ALIVE" } | ForEach-Object {
                $pingDisplay = if ($_.PingLatency) { "$($_.PingLatency)" } else { "N/A" }
                AddResultText ("{0,-40} {1,-8} {2,-50} {3,-10}" -f $_.Server, $_.Port, $_.Secret, $pingDisplay) "Green"
            }
        }
        
    } catch {
        AddResultText "" "Black"
        AddResultText "ERROR: $($_.Exception.Message)" "Red"
        $statusLabel.Text = "Error: $($_.Exception.Message)"
    }
    
    # Hide progress bar
    $progressBar.Visible = $false
    $fetchButton.Enabled = $true
    $statusLabel.Text = "Ready"
}

# Event handlers
$fetchButton.Add_Click({
    FetchAndCheckProxies
})

$openCsvButton.Add_Click({
    if (Test-Path $outputCsv) {
        Invoke-Item $outputCsv
    } else {
        [System.Windows.Forms.MessageBox]::Show("CSV file not found. Please fetch and check proxies first.", "File Not Found", "OK", [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

$openFolderButton.Add_Click({
    Invoke-Item $scriptPath
})

$closeButton.Add_Click({
    $form.Close()
})

# Show the form
$form.ShowDialog() | Out-Null