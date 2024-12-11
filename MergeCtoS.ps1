# PowerShell script to compare group members and update _S groups

Import-Module ActiveDirectory
#Prereq : Install-WindowsFeature RSAT-AD-PowerShell

Clear
# Setup logging
$logPath = "C:\log"
$logFile = Join-Path -Path $logPath -ChildPath "$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Create log directory if it doesn't exist
if (-not (Test-Path -Path $logPath)) { New-Item -ItemType Directory -Path $logPath -Force | Out-Null}

function Write-Log {
    param(
        [string]$Message,
        [switch]$NoNewLine
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Write to console and log file
    if ($NoNewLine) {   Write-Host $logMessage -NoNewline; Add-Content -Path $logFile -Value $logMessage -NoNewline  }
    else            {   Write-Host $logMessage           ; Add-Content -Path $logFile -Value $logMessage             }
}
Write-Log "=== Script Execution Started ==="
function Get-GroupMembers {
    param (
        [string]$groupName
    )
    
    try {        
        $members = Get-ADGroupMember -Identity $groupName | Where-Object { $_.objectClass -eq "user" } | Select-Object SamAccountName 
        Write-Log "Found $($members.Count) members in $groupName : $($members -join ', ')"
        return $members
        }
    catch {
        Write-Log "No Users found Found"
        #TODO Do  error handeling
    }
}
function Update-SGroup {
    param (
        [string]$sGroupName,
        [array]$membersToAdd
    )
    #region get group
    Write-Log "=== Updating group $sGroupName ==="
    try {
        $group = Get-ADGroup -Identity $sGroupName
    }
    catch {    
        Write-Log "Error getting group $sGroupName : $($_.Exception.Message)"
        return
    }
    #endregion
    
    #region First, remove all existing members
    #Write-Log "Removing existing members from $sGroupName"
    #$existingMembers = Get-ADGroupMember -Identity $sGroupName # remove first, so 
    #if ($existingMembers) {
    #    Write-Log "Removing $($existingMembers.Count) existing members from $sGroupName, $($members -join ', ')"
    #    foreach ($member in $existingMembers) {
    #        Write-Log "Removing member $($member.SamAccountName) from $sGroupName"
    #        try   {   Remove-ADGroupMember -Identity $sGroupName -Members $member.SamAccountName -Confirm:$false }
    #        catch { Write-Log "ERROR Removing member $member from $sGroupName : $($_.Exception.Message)"         }  
    #        
    #    }
    #}
    #endregion

    #region Verify group is empty
    $verifyMembers = Get-ADGroupMember -Identity $sGroupName
    if ($verifyMembers) {
        Write-Log "WARNING: Group $sGroupName still has members after removal: $($verifyMembers.SamAccountName -join ', ')"
        ## TODO EventLog    
    #endregion
    } else {
    Write-Log "Verified $sGroupName is empty"
    #region Add new members
            Write-Log "Adding $($membersToAdd.Count) new members to $sGroupName, $($members -join ', ')"
            foreach ($member in $membersToAdd) 
                {
                    Write-Log "Adding member $member to $sGroupName" -NoNewLine
                    Try {   Add-ADGroupMember -Identity $sGroupName -Members $member -Confirm:$false}
                    catch { Write-Log "ERROR adding member $member to $sGroupName : $($_.Exception.Message)"}
                    else {  Write-Log "$member Successfully added to $sGroupName"}
                }
            Write-Log "Successfully updated group $sGroupName with $($membersToAdd.Count) members"
            }
    #endregion
}

#region Main merge
Write-Log "---------------------------------------------------------------------"
Write-Log "Getting lic_group members..."
$licGroupMembers = Get-GroupMembers "Lic_Group"
Write-Log "Found $($licGroupMembers.Count) users i Lic_Group $($licGroupMembers.SamAccountName -join ', ') "
Write-Log "---------------------------------------------------------------------"
Write-Log "Getting list of _C groups..."
$cGroups = Get-ADGroup -Filter "Name -like '*_C'"
Write-Log "Found $($cGroups.Count) _C groups, $($cGroups.Name -join ', ')"
Write-Log "------------------GROUP UPDATES--------------------------------------"
foreach ($cGroup in $cGroups) {
    $cGroupName = $cGroup.Name
    $sGroupName = $cGroupName -replace "_C$", "_S"
    Write-Log "---------------------- $cGroupName -> $sGroupName ----------------------------"
    
    # Get _C group members
    $cGroupMembers = Get-GroupMembers $cGroupName
    Write-Log "Found $($cGroupMembers.Count) users i $cGroupName $($cGroupMembers.SamAccountName -join ', ') "
    if($cGroupMembers.Count -le 1) {  Write-Log "No members found in $cGroupName, skipping" ; continue} # Om gruppen är tom så skippar vi resten
    
    # Find matching members
    #Version 1
    #$matchingMembers = $cGroupMembers | Where-Object { $licGroupMembers -contains $_ }
    $CommonMembers = Compare-Object -ReferenceObject $MembersA -DifferenceObject $MembersB -Property SamAccountName -IncludeEqual | 
        Where-Object { $_.SideIndicator -eq "==" } |
        Select-Object -ExpandProperty InputObject
    
    Write-Log "Found $($CommonMembers.Count) matching members between $cGroupName and lic_group"
    try{    Update-SGroup $sGroupName $matchingMembers                             }
    catch { Write-Log "Error updating group $sGroupName : $($_.Exception.Message)" }
}
Write-Log "=== Script Execution Completed Successfully ==="
#endregion