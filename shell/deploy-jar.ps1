# This script deploys local Java JAR to remote Linux Docker container from Windows 11
# Step 1: Search for all JAR files in current directory and subdirectories
#         - If no JAR found: show error
#         - If multiple JARs: prompt user to select one
#         - If single JAR: auto-select, use filename (without .jar) as container name

Write-Host "Searching for JAR files..." -ForegroundColor Cyan
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray

try {
    # Search for all JAR files in current directory and subdirectories, only from target directories
    $ALL_JARS = Get-ChildItem -Path "." -Filter "*.jar" -Recurse -ErrorAction Stop | Where-Object { $_.DirectoryName -match 'target' }

    Write-Host "Total JAR files found: $($ALL_JARS.Count)" -ForegroundColor Gray

    if ($ALL_JARS.Count -gt 0) {
        Write-Host "JAR file locations:" -ForegroundColor Gray
        $ALL_JARS | ForEach-Object { Write-Host "  - $($_.FullName)" -ForegroundColor Gray }
    }
}
catch {
    Write-Host "ERROR during file search: $_" -ForegroundColor Red
    Write-Host "Exception details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if ($ALL_JARS.Count -eq 0)
{
    Write-Host "ERROR: No JAR files found in target directories" -ForegroundColor Red
    exit 1
}
elseif ($ALL_JARS.Count -eq 1)
{
    $JAR_PATH = $ALL_JARS[0].FullName
    Write-Host "Found 1 JAR file, auto-selecting:" -ForegroundColor Green
    Write-Host "  $JAR_PATH" -ForegroundColor Yellow
}
else
{
    Write-Host "Found $($ALL_JARS.Count) JAR files:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $ALL_JARS.Count; $i++)
    {
        Write-Host "  [$($i + 1)] $($ALL_JARS[$i].FullName)" -ForegroundColor White
    }

    while ($true)
    {
        if ([Console]::IsInputRedirected)
        {
            $SELECTION = [Console]::ReadLine()
        }
        else
        {
            $SELECTION = Read-Host "Please select a JAR file (enter number)"
        }

        if ($SELECTION -match '^\d+$' -and [int]$SELECTION -ge 1 -and [int]$SELECTION -le $ALL_JARS.Count)
        {
            $JAR_PATH = $ALL_JARS[[int]$SELECTION - 1].FullName
            break
        }
        else
        {
            Write-Host "Invalid selection. Please enter a number between 1 and $($ALL_JARS.Count)" -ForegroundColor Red
        }
    }
}

# Extract container name from JAR filename (remove .jar extension)
Write-Host "JAR path: $JAR_PATH" -ForegroundColor Green

$CONTAINER_NAME = [System.IO.Path]::GetFileNameWithoutExtension($JAR_PATH)

Write-Host "Container name: $CONTAINER_NAME" -ForegroundColor Green


$SERVER = "park@192.168.10.11"
$REMOTE_DIR = "/home/park/docker/$CONTAINER_NAME"

Write-Host "Starting deployment of $CONTAINER_NAME ..." -ForegroundColor Cyan

# 1. Check if JAR file exists
if (-Not (Test-Path $JAR_PATH))
{
    Write-Host "ERROR: JAR file not found: $JAR_PATH" -ForegroundColor Red
    exit 1
}
Write-Host "OK: JAR file exists" -ForegroundColor Green

# 2. Create remote directory and backup
Write-Host "Creating directory and backup..." -ForegroundColor Yellow
$BACKUP_CMD = "mkdir -p $REMOTE_DIR && cp $REMOTE_DIR/$CONTAINER_NAME.jar $REMOTE_DIR/$CONTAINER_NAME.jar.backup.`$(date +%Y%m%d%H%M%S) 2>/dev/null || true"
ssh $SERVER $BACKUP_CMD

# 3. Transfer JAR file
Write-Host "Transferring JAR file..." -ForegroundColor Yellow
scp -o StrictHostKeyChecking=no $JAR_PATH "${SERVER}:${REMOTE_DIR}/"
if ($LASTEXITCODE -ne 0)
{
    Write-Host "ERROR: File transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host "OK: File transfer successful" -ForegroundColor Green

# 4. Copy to container
Write-Host "Copying to Docker container..." -ForegroundColor Yellow
$COPY_CMD = "docker cp ${REMOTE_DIR}/$CONTAINER_NAME.jar ${CONTAINER_NAME}:/home/park/$CONTAINER_NAME.jar"
ssh $SERVER $COPY_CMD

# 5. Restart container
Write-Host "Restarting application..." -ForegroundColor Yellow
$RESTART_CMD = "docker restart ${CONTAINER_NAME}"
ssh $SERVER $RESTART_CMD

# 6. Wait for application to start
Write-Host "Waiting for application to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 7. Verify container status
Write-Host "Checking container status..." -ForegroundColor Yellow
$STATUS_CMD = "docker ps | grep ${CONTAINER_NAME}"
ssh $SERVER $STATUS_CMD

# 8. View latest logs
Write-Host "Viewing application logs (last 10 lines)..." -ForegroundColor Yellow
$LOGS_CMD = "docker logs --tail 10 ${CONTAINER_NAME}"
ssh $SERVER $LOGS_CMD

Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
