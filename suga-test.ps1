# suga-test.ps1 - Complete Windows testing script
# Run with: powershell -ExecutionPolicy Bypass -File suga-test.ps1

param(
    [string]$AppUrl = "https://your-app.suga.app"  # CHANGE THIS!
)

Write-Host "=== Suga Testing Script for Windows ===" -ForegroundColor Cyan

# Function to get timestamp with milliseconds
function Get-Timestamp {
    return (Get-Date -Format "HH:mm:ss.fff")
}

# Function to test endpoint
function Test-Endpoint {
    param($Path = "", $ExpectedCode = 200)
    
    $fullUrl = $AppUrl + $Path
    $timestamp = Get-Timestamp
    
    try {
        $response = Invoke-WebRequest -Uri $fullUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $status = $response.StatusCode
        $duration = $response.Headers['X-Response-Time']  # If provided by Suga
        
        Write-Host "$timestamp - HTTP $status ✅ (${duration}s)" -ForegroundColor Green
        return $true
    }
    catch {
        $status = $_.Exception.Response.StatusCode.value__
        if (-not $status) { $status = "ERROR" }
        Write-Host "$timestamp - HTTP $status ❌ ($($_.Exception.Message))" -ForegroundColor Red
        return $false
    }
}

# Monitor deployment continuously
function Start-DeploymentMonitor {
    Write-Host "`n=== STARTING DEPLOYMENT MONITOR ===" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop monitoring`n"
    
    $startTime = Get-Date
    $successCount = 0
    $errorCount = 0
    
    while ($true) {
        $timestamp = Get-Timestamp
        $elapsed = (Get-Date) - $startTime
        
        try {
            $request = [System.Net.WebRequest]::Create($AppUrl)
            $request.Timeout = 5000
            $response = $request.GetResponse()
            $statusCode = [int]$response.StatusCode
            $response.Close()
            
            $successCount++
            Write-Host "$timestamp (${elapsed:ss\.fff}s) - HTTP $statusCode ✅ (Successes: $successCount)" -ForegroundColor Green
        }
        catch {
            $errorCount++
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
                Write-Host "$timestamp (${elapsed:ss\.fff}s) - HTTP $statusCode ❌ (Errors: $errorCount)" -ForegroundColor Red
            }
            else {
                Write-Host "$timestamp (${elapsed:ss\.fff}s) - CONNECTION ERROR ❌ (Errors: $errorCount)" -ForegroundColor Red
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
}

# Generate load on the app
function Start-LoadTest {
    param($Requests = 50)
    
    Write-Host "`n=== GENERATING $Requests REQUESTS ===" -ForegroundColor Yellow
    
    for ($i = 1; $i -le $Requests; $i++) {
        Start-Job -ScriptBlock {
            param($url, $num)
            try {
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
                Write-Host "[$num] Request completed - HTTP $($response.StatusCode)"
            }
            catch {
                Write-Host "[$num] Request failed - $($_.Exception.Message)" -ForegroundColor Red
            }
        } -ArgumentList $AppUrl, $i | Out-Null
        
        if ($i % 10 -eq 0) {
            Write-Host "Sent $i requests..." -ForegroundColor Cyan
        }
        Start-Sleep -Milliseconds 100
    }
    
    # Wait for all jobs to complete
    Get-Job | Wait-Job | Out-Null
    Get-Job | Remove-Job
    Write-Host "Load test complete!" -ForegroundColor Green
}

# Menu system
function Show-Menu {
    Clear-Host
    Write-Host @"
=== SUGA TESTING TOOL ===
Current App URL: $AppUrl

1. Start Deployment Monitor (checks for 502s/503s)
2. Run Load Test (50 requests)
3. Test all endpoints (/, /health, /slow)
4. Zero-downtime test (while deploying new version)
5. Check service metrics (if you have service name)
6. Change App URL
0. Exit

"@ -ForegroundColor Cyan
    
    $choice = Read-Host "Select option"
    return $choice
}

# Main loop
do {
    $choice = Show-Menu
    
    switch ($choice) {
        '1' { 
            Start-DeploymentMonitor
        }
        '2' { 
            $count = Read-Host "Number of requests (default: 50)"
            if ([string]::IsNullOrWhiteSpace($count)) { $count = 50 }
            Start-LoadTest -Requests ([int]$count)
            Read-Host "`nPress Enter to continue"
        }
        '3' {
            Write-Host "`nTesting endpoints..." -ForegroundColor Yellow
            Test-Endpoint -Path ""
            Test-Endpoint -Path "/health"
            Test-Endpoint -Path "/slow"
            Read-Host "`nPress Enter to continue"
        }
        '4' {
            Write-Host @"
`n=== ZERO-DOWNTIME TEST ===
1. Start the deployment monitor (Option 1 in NEW PowerShell window)
2. Deploy new version to Suga
3. Watch for any 502/503 errors
4. Press Ctrl+C in monitor window when done

"@ -ForegroundColor Yellow
            Read-Host "Press Enter after you've started the monitor"
            
            Write-Host "Ready to deploy? Deploy now in Suga dashboard..." -ForegroundColor Cyan
            Read-Host "Press Enter when deployment is complete"
            
            Write-Host "Check monitor window for error count!" -ForegroundColor Green
            Read-Host "Press Enter to continue"
        }
        '5' {
            $serviceName = Read-Host "Enter service name from canvas"
            Write-Host "`nChecking metrics for: $serviceName" -ForegroundColor Yellow
            Write-Host "Note: This requires Suga's API endpoint - you'll need to inspect network traffic" -ForegroundColor Gray
            Read-Host "Press Enter to continue"
        }
        '6' {
            $newUrl = Read-Host "Enter new App URL (e.g., https://myapp.suga.app)"
            if ($newUrl) { $AppUrl = $newUrl }
            Write-Host "App URL updated to: $AppUrl" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne '0')