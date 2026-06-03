# ops-receiver auto deploy script
# Usage: .\deploy.ps1 <container_name>

# Get container name from arguments
if ($args.Count -gt 0) {
    $CONTAINER_NAME = $args[0]
} else {
    if ([Console]::IsInputRedirected) {
        $CONTAINER_NAME = [Console]::ReadLine()
    } else {
        $CONTAINER_NAME = Read-Host "Please enter container name"
    }
}

# Trim whitespace
$CONTAINER_NAME = $CONTAINER_NAME.Trim()

if (-Not $CONTAINER_NAME) {
    Write-Host "ERROR: Container name cannot be empty" -ForegroundColor Red
    Write-Host "Usage: .\deploy.ps1 container_name" -ForegroundColor Yellow
    exit 1
}

# Auto search for CONTAINER_NAME.jar file
$JAR_FILE = "$CONTAINER_NAME.jar"
$JAR_PATH = Get-ChildItem -Path "." -Filter $JAR_FILE -Recurse | Select-Object -First 1 -ExpandProperty FullName

Write-Host "CONTAINER_NAME:" $CONTAINER_NAME "JAR_PATH:" $JAR_PATH

if (-Not $JAR_PATH) {
    Write-Host "ERROR: $JAR_FILE not found in current directory" -ForegroundColor Red
    exit 1
}

$SERVER = "park@192.168.10.11"
$REMOTE_DIR = "/home/park/docker/$CONTAINER_NAME"

Write-Host "Starting deployment of $CONTAINER_NAME ..." -ForegroundColor Cyan

# 1. Check if JAR file exists
if (-Not (Test-Path $JAR_PATH)) {
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
if ($LASTEXITCODE -ne 0) {
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
