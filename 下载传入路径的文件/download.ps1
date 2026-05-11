Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "URL批量下载工具"
$form.Size = New-Object System.Drawing.Size(700, 550)
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$form.Tag = $scriptDir

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Size = New-Object System.Drawing.Size(660, 20)
$label.Text = "请输入要下载的URL (每行一个):"
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10, 35)
$textBox.Size = New-Object System.Drawing.Size(660, 150)
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$form.Controls.Add($textBox)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(10, 195)
$startButton.Size = New-Object System.Drawing.Size(100, 30)
$startButton.Text = "开始下载"
$form.Controls.Add($startButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 235)
$statusLabel.Size = New-Object System.Drawing.Size(660, 25)
$statusLabel.Text = "状态: 等待开始..."
$statusLabel.Font = New-Object System.Drawing.Font($statusLabel.Font, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 265)
$progressBar.Size = New-Object System.Drawing.Size(660, 25)
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

$logTextBox = New-Object System.Windows.Forms.RichTextBox
$logTextBox.Location = New-Object System.Drawing.Point(10, 295)
$logTextBox.Size = New-Object System.Drawing.Size(660, 180)
$logTextBox.Multiline = $true
$logTextBox.ScrollBars = "Vertical"
$logTextBox.ReadOnly = $true
$logTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logTextBox.BackColor = [System.Drawing.Color]::Black
$logTextBox.ForeColor = [System.Drawing.Color]::Lime
$form.Controls.Add($logTextBox)

function Add-Log {
    param([string]$message, [string]$color = "Lime")
    if ($color -eq "Red") {
        $logTextBox.SelectionColor = [System.Drawing.Color]::Red
    } elseif ($color -eq "Yellow") {
        $logTextBox.SelectionColor = [System.Drawing.Color]::Yellow
    } elseif ($color -eq "Cyan") {
        $logTextBox.SelectionColor = [System.Drawing.Color]::Cyan
    } else {
        $logTextBox.SelectionColor = [System.Drawing.Color]::Lime
    }
    $logTextBox.AppendText("$message`r`n")
    $logTextBox.SelectionStart = $logTextBox.Text.Length
    $logTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Parse-Urls {
    param([string]$text)
    $lines = $text -split '[\r\n]+'
    $urls = @()
    foreach ($line in $lines) {
        $line = $line.Trim()
        $pattern = '(https?://[^\s]+)'
        if ($line -match $pattern) {
            $url = $matches[1]
            $url = $url -replace '[`\s''"]+$', ''
            $url = $url -replace '^[`\s''"]+', ''
            if ($url.StartsWith("http://") -or $url.StartsWith("https://")) {
                $urls += $url
            }
        }
    }
    return $urls
}

$startButton.Add_Click({
    $inputText = $textBox.Text
    if ([string]::IsNullOrWhiteSpace($inputText)) {
        [System.Windows.Forms.MessageBox]::Show("请输入至少一个URL", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $textBox.Enabled = $false
    $startButton.Enabled = $false
    $statusLabel.Text = "状态: 正在下载..."
    $progressBar.Value = 0
    $logTextBox.Text = ""
    
    $scriptDir = $form.Tag
    
    Add-Log "开始处理..."
    Add-Log "脚本目录: $scriptDir"
    
    $downloadDir = Join-Path $scriptDir "Download"
    
    Add-Log "下载目录: $downloadDir"
    
    if (-not (Test-Path $downloadDir)) {
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    }
    
    $allUrls = Parse-Urls -text $inputText
    
    Add-Log "找到 $($allUrls.Count) 个链接"
    foreach ($u in $allUrls) {
        Add-Log "  - $u"
    }
    
    if ($allUrls.Count -eq 0) {
        Add-Log "未找到有效链接" "Yellow"
        $statusLabel.Text = "状态: 未找到有效链接"
        $textBox.Enabled = $true
        $startButton.Enabled = $true
        return
    }
    
    Add-Log ""
    Add-Log "开始下载..."
    
    $count = 1
    $totalDownload = $allUrls.Count
    $downloaded = 0
    $successCount = 0
    $failCount = 0
    
    for ($i = 0; $i -lt $allUrls.Count; $i++) {
        $url = $allUrls[$i]
        
        try {
            $uri = New-Object System.Uri($url)
            $fileName = $uri.Segments[-1]
            
            if ([string]::IsNullOrEmpty($fileName) -or $fileName -eq "/") {
                $ext = [System.IO.Path]::GetExtension($url)
                if ([string]::IsNullOrEmpty($ext)) {
                    $ext = ".mp4"
                }
                $fileName = "file_$count$ext"
            }
            
            $filePath = Join-Path $downloadDir $fileName
            
            Add-Log "下载: $fileName ..."
            
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            $webClient.DownloadFile($url, $filePath)
            $webClient.Dispose()
            
            if (Test-Path $filePath) {
                $fileSize = (Get-Item $filePath).Length
                $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                Add-Log "  [成功] $fileName ($fileSizeMB MB)" "Lime"
                $successCount++
            } else {
                Add-Log "  [失败] 文件未创建" "Red"
                $failCount++
            }
            $count++
        } catch {
            Add-Log "  [失败] $($_.Exception.Message)" "Red"
            $failCount++
        }
        
        $downloaded++
        $progressBar.Value = [math]::Floor(($downloaded / $totalDownload) * 100)
    }
    
    $progressBar.Value = 100
    
    Add-Log ""
    Add-Log "========== 下载完成! ==========" "Cyan"
    Add-Log "成功: $successCount 个" "Lime"
    if ($failCount -gt 0) {
        Add-Log "失败: $failCount 个" "Red"
    }
    Add-Log "保存位置: $downloadDir" "Cyan"
    
    $statusLabel.Text = "状态: 下载完成! (成功: $successCount, 失败: $failCount)"
    $textBox.Enabled = $true
    $startButton.Enabled = $true
    
    $result = [System.Windows.Forms.MessageBox]::Show("下载完成!`n`n成功: $successCount 个`n失败: $failCount 个`n`n文件保存在: $downloadDir", "完成", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$form.ShowDialog()
