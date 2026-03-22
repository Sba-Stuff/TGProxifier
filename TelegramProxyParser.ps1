# Telegram Proxy Fetcher - Standalone Script
# Downloads proxies from GitHub and creates a CSV file with server, port, and secret

Add-Type -AssemblyName System.Windows.Forms

# The URL containing the proxy list
$proxyUrl = "https://raw.githubusercontent.com/SoliSpirit/mtproto/master/all_proxies.txt"

# Get the path where this script is located
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$downloadedFile = Join-Path $scriptPath "all_proxies.txt"
$outputCsv = Join-Path $scriptPath "telegram_proxies.csv"

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Telegram Proxy Fetcher"
$form.Size = New-Object System.Drawing.Size(800, 550)
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
$titleLabel.Text = "Telegram Proxy Fetcher"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(400, 30)
$mainPanel.Controls.Add($titleLabel)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready to fetch proxies..."
$statusLabel.Location = New-Object System.Drawing.Point(20, 60)
$statusLabel.Size = New-Object System.Drawing.Size(700, 25)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$mainPanel.Controls.Add($statusLabel)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 95)
$progressBar.Size = New-Object System.Drawing.Size(700, 20)
$progressBar.Style = "Marquee"
$progressBar.Visible = $false
$mainPanel.Controls.Add($progressBar)

# Results text box
$resultsBox = New-Object System.Windows.Forms.TextBox
$resultsBox.Location = New-Object System.Drawing.Point(20, 130)
$resultsBox.Size = New-Object System.Drawing.Size(700, 280)
$resultsBox.Multiline = $true
$resultsBox.ScrollBars = "Vertical"
$resultsBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$resultsBox.ReadOnly = $true
$resultsBox.BackColor = [System.Drawing.Color]::White
$mainPanel.Controls.Add($resultsBox)

# Button panel
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Location = New-Object System.Drawing.Point(20, 425)
$buttonPanel.Size = New-Object System.Drawing.Size(700, 50)
$mainPanel.Controls.Add($buttonPanel)

$fetchButton = New-Object System.Windows.Forms.Button
$fetchButton.Text = "Fetch & Parse Proxies"
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
$closeButton.Location = New-Object System.Drawing.Point(620, 10)
$closeButton.Size = New-Object System.Drawing.Size(80, 35)
$buttonPanel.Controls.Add($closeButton)

# Function to add text to results box
function AddResultText {
    param($text, $color = "Black")
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

# Function to fetch and parse proxies
function FetchAndParseProxies {
    # Clear results
    $resultsBox.Clear()
    AddResultText "========================================"
    AddResultText "Telegram Proxy Fetcher - Starting..."
    AddResultText "========================================"
    AddResultText ""
    
    # Show progress bar
    $progressBar.Visible = $true
    $statusLabel.Text = "Downloading proxy list from GitHub..."
    $fetchButton.Enabled = $false
    
    try {
        # Step 1: Download the file
        AddResultText "[1/3] Downloading proxy list..."
        AddResultText "URL: $proxyUrl"
        
        Invoke-WebRequest -Uri $proxyUrl -OutFile $downloadedFile -UseBasicParsing -TimeoutSec 30
        
        # Check if download was successful
        if (Test-Path $downloadedFile) {
            $fileInfo = Get-Item $downloadedFile
            AddResultText "Downloaded: $($fileInfo.Length) bytes"
            AddResultText ""
        } else {
            throw "Download failed - file not created"
        }
        
        # Step 2: Read and parse the file
        AddResultText "[2/3] Parsing proxy list..."
        $lines = Get-Content $downloadedFile
        AddResultText "Total lines read: $($lines.Count)"
        
        $proxyList = @()
        $validCount = 0
        $invalidCount = 0
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -eq "") { continue }
            
            # Only process lines that look like proxy URLs
            if ($line -like "*server=*" -and $line -like "*port=*" -and $line -like "*secret=*") {
                $parsed = ParseProxyLine $line
                
                if ($parsed -and $parsed.Server -and $parsed.Port -and $parsed.Secret) {
                    $proxyList += [PSCustomObject]@{
                        Server = $parsed.Server
                        Port = $parsed.Port
                        Secret = $parsed.Secret
                    }
                    $validCount++
                } else {
                    $invalidCount++
                }
            } else {
                $invalidCount++
            }
        }
        
        AddResultText "Valid proxies found: $validCount"
        if ($invalidCount -gt 0) {
            AddResultText "Invalid lines ignored: $invalidCount"
        }
        AddResultText ""
        
        # Step 3: Export to CSV
        AddResultText "[3/3] Creating CSV file..."
        
        if ($validCount -gt 0) {
            $proxyList | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
            
            if (Test-Path $outputCsv) {
                $csvInfo = Get-Item $outputCsv
                AddResultText "CSV file created successfully!"
                AddResultText "File: $outputCsv"
                AddResultText "Size: $($csvInfo.Length) bytes"
                AddResultText ""
                
                # Show preview of first 5 proxies
                AddResultText "Preview (first 5 proxies):"
                AddResultText ("{0,-40} {1,-8} {2,-50}" -f "SERVER", "PORT", "SECRET")
                AddResultText ("{0,-40} {1,-8} {2,-50}" -f "------", "----", "------")
                
                $proxyList | Select-Object -First 5 | ForEach-Object {
                    $secretPreview = $_.Secret
                    if ($secretPreview.Length -gt 50) {
                        $secretPreview = $secretPreview.Substring(0, 47) + "..."
                    }
                    AddResultText ("{0,-40} {1,-8} {2,-50}" -f $_.Server, $_.Port, $secretPreview)
                }
                
                if ($validCount -gt 5) {
                    AddResultText "... and $($validCount - 5) more proxies"
                }
                
                AddResultText ""
                AddResultText "========================================"
                AddResultText "COMPLETE! $validCount proxies saved to CSV"
                AddResultText "========================================"
                
                $statusLabel.Text = "Complete! $validCount proxies saved to CSV"
                $openCsvButton.Enabled = $true
                
            } else {
                throw "Failed to create CSV file"
            }
        } else {
            AddResultText "ERROR: No valid proxies found in the downloaded file!"
            $statusLabel.Text = "Error: No valid proxies found"
        }
        
    } catch {
        AddResultText ""
        AddResultText "ERROR: $($_.Exception.Message)"
        $statusLabel.Text = "Error: $($_.Exception.Message)"
    }
    
    # Hide progress bar
    $progressBar.Visible = $false
    $fetchButton.Enabled = $true
}

# Event handlers
$fetchButton.Add_Click({
    FetchAndParseProxies
})

$openCsvButton.Add_Click({
    if (Test-Path $outputCsv) {
        Invoke-Item $outputCsv
    } else {
        [System.Windows.Forms.MessageBox]::Show("CSV file not found. Please fetch proxies first.", "File Not Found", "OK", [System.Windows.Forms.MessageBoxIcon]::Warning)
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