# PowerShell script to compare group members and update _S groups

#Import Active Directory module
#Install-WindowsFeature RSAT-AD-PowerShell

# Clear
# Setup logging
$logPath = "C:\log"
$logFile = Join-Path -Path $logPath -ChildPath "$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Create log directory if it doesn't exist
if (-not (Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [switch]$NoNewLine
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Write to console and log file
    if ($NoNewLine) {
        Write-Host $logMessage -NoNewline
        Add-Content -Path $logFile -Value $logMessage -NoNewline
    } else {
        Write-Host $logMessage
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "=== Script Execution Started ==="


function Get-GroupMembers {
    param (
        [string]$groupName
    )
    
    try {
        $members = Get-ADGroupMember -Identity $groupName | Select-Object -ExpandProperty SamAccountName
        }
    Write-Log "Found $($members.Count) members in $groupName : $($members -join ', ')"
    return $members
}
function Update-SGroup {
    param (
        [string]$sGroupName,
        [array]$membersToAdd
    )
    Write-Log "=== Updating group $sGroupName ==="
    try {
        $group = Get-ADGroup -Identity $sGroupName
    }
    catch {    
        Write-Log "Error getting group $sGroupName : $($_.Exception.Message)"
        return
    }
    
    # First, remove all existing members
    Write-Log "Removing existing members from $sGroupName"
    $existingMembers = Get-ADGroupMember -Identity $sGroupName
    if ($existingMembers) {
        Write-Log "Removing $($existingMembers.Count) existing members from $sGroupName, $($members -join ', ')"
        foreach ($member in $existingMembers) {
            Write-Log "Removing member $($member.SamAccountName) from $sGroupName"
            Remove-ADGroupMember -Identity $sGroupName -Members $member.SamAccountName -Confirm:$false
        }
    }
    # Verify group is empty
    $verifyMembers = Get-ADGroupMember -Identity $sGroupName
    if ($verifyMembers) {
        Write-Log "WARNING: Group $sGroupName still has members after removal: $($verifyMembers.SamAccountName -join ', ')"
        ## TODO EventLog    
    } else {
        Write-Log "Verified $sGroupName is empty"

    # Add new members
    Write-Log "Adding $($membersToAdd.Count) new members to $sGroupName, $($members -join ', ')"
    foreach ($member in $membersToAdd) {
        Write-Log "Adding member $member to $sGroupName" -NoNewLine
        Try {
        Add-ADGroupMember -Identity $sGroupName -Members $member -Confirm:$false
        }
        catch {
            Write-Log "ERROR adding member $member to $sGroupName : $($_.Exception.Message)"
        }
        else {
            Write-Log "Successfully added"
        }

    }
    Write-Log "Successfully updated group $sGroupName with $($membersToAdd.Count) members"
#TODO
    Write-Log "=== Script Execution Completed Successfully ==="
}