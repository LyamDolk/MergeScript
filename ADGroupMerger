Clear 
# Requires elevation (Run as Administrator)
if ([System.Diagnostics.EventLog]::SourceExists("User_Sync") -eq $false) {
    New-EventLog -LogName Application -Source "User_Sync"
    Write-EventLog -LogName Application -Source "User_Sync" -EventId 1 -Message "Event Log Source 'User_Sync' has been created successfully" -EntryType Information
}

# Create log directory if it doesn't exist
$logDir = "C:/log"
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH:mm:ss'
$logFile = Join-Path $logDir "$timestamp.log" # Write here to have same lof file name for the entire script run.
function Write-UserSyncLog {
    param(
        [Parameter(Mandatory=$true)]        [string]$Statement,        
        [Parameter(Mandatory=$false)]         [switch]$IsError,
        [Parameter(Mandatory=$false)]         [int16]$EventId = 1000,
        [Parameter(Mandatory=$false)]         [int16]$RunId
    )
    if ($RunId) { $EventId = $RunId+$eventId} ; if ($IsError) { $eventId = 9999 } ;    $entryType = if ($IsError) { "Error" } else { "Information" }
    
    # Write to Event Log
    Write-EventLog -LogName Application -Source "User_Sync" -EventId $eventId -Message $Statement -EntryType $entryType
    Write-Host "EventId $eventId Message $Statement -EntryType $entryType"

    # Format log message
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`t$entryType`t$EventId`t$Statement"

    # Append to log file
    Add-Content -Path $logFile -Value $logMessage
}
# DEMO Logs
# Write-UserSyncLog -Statement "This is an info message"
# Write-UserSyncLog -Statement "This is an error message" -IsError

function Proccess-SSGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$CgroupName,                 # Name of the first source group _C
        [Parameter(Mandatory = $true)][string]$SgroupName,                 # Name of the target group _S
        [Parameter(Mandatory = $false)][string]$RunId = 1                  # runid for the log, Makes each loop separatable in logs later on.
    )

    try {
        # Retrieve members of the sourcegroups                                                                                                                                   Logstatements for the commands to the left
        $CgroupMembersNames   = Get-ADGroupMember -Identity $CgroupName -Recursive | Where-Object { $_.objectClass -eq 'user' } | Select-Object -ExpandProperty SamAccountName ; Write-UserSyncLog -Statement "Found $($CgroupMembersNames.Count) users in group '$CgroupName': $($CgroupMembersNames -join ', ')" -RunId $RunId
        $SgroupMembersNames   = Get-ADGroupMember -Identity $SgroupName -Recursive | Where-Object { $_.objectClass -eq 'user' } | Select-Object -ExpandProperty SamAccountName ; Write-UserSyncLog -Statement "Found $($SgroupMembersNames.Count) users in group '$SgroupName': $($SgroupMembersNames -join ', ')" -RunId $RunId
        $LicGroupMembersNames = Get-ADGroupMember -Identity "lic_users" -Recursive | Where-Object { $_.objectClass -eq 'user' } | Select-Object -ExpandProperty SamAccountName ; Write-UserSyncLog -Statement "Found $($LicGroupMembersNames.Count) users in group 'lic_users': $($LicGroupMembersNames -join ', ')" -RunId $RunId
        Write-host "-----------------------------------------------------------------------------------------------"

        # Find common members
        $CommonMemberNames  = $CgroupMembersNames | Where-Object { $LicGroupMembersNames -contains $_ }    ; Write-UserSyncLog -Statement "Found $($CommonMemberNames.Count) common users in group '$CgroupName': $($CommonMemberNames -join ', ')" -RunId $RunId 
        $UsersNotInLicGroup = $SgroupMembersNames | Where-Object { $LicGroupMembersNames -notcontains $_ } ; Write-UserSyncLog -Statement "Found $($UsersNotInLicGroup.Count) users not in lic_users group: $($UsersNotInLicGroup -join ', ')" -RunId $RunId
        $UsersNotInCGroup   = $SgroupMembersNames | Where-Object { $CgroupMembersNames -notcontains $_ }   ; Write-UserSyncLog -Statement "Found $($UsersNotInCGroup.Count) users not in '$CgroupName': $($UsersNotInCGroup -join ', ')" -RunId $RunId
        Write-host ('-'*100)
        
        # Add common members to the target group
        $AddedUsers = @()
        foreach ($Member in $CommonMemberNames) {
                try { Add-ADGroupMember -Identity $SgroupName -Members $Member -Confirm:$false
                        $AddedUsers += $Member
                } catch { Write-UserSyncLog -Statement "Failed to add user '$Member' to group '$SgroupName'. Error: $_" -IsError $true -RunId $RunId }
            }

        if ($AddedUsers.Count -gt 0) {
            Write-UserSyncLog -Statement "Added users to group '$SgroupName': $($AddedUsers -join ', ')" -RunId $RunId
        }
        Write-UserSyncLog -Statement "Successfully added common members to group '$SgroupName' with $($AddedUsers.Count) members " -RunId $RunId
        Write-host "Successfully added common members to group '$SgroupName'. with $($AddedUsers.Count) members on  $(1000+$RunId)" 
                
        # Remove unmatched members from SGroup that are not in LicGroup
        $RemovedUsers = @() # i make this here to gather all the users into one log statement.
        foreach ($User in $UsersNotInLicGroup) 
            {
                try     {
                        Remove-ADGroupMember -Identity $SgroupName -Members $User -Confirm:$false
                        $RemovedUsers += $User
                        }
                catch { Write-UserSyncLog -Statement "Failed to remove user '$User' from group '$SgroupName'. Error: $_" -IsError $true -RunId $RunId   }
            }
        
        if ($RemovedUsers.Count -gt 0) { Write-UserSyncLog -Statement "Removed users from group '$SgroupName': $($RemovedUsers -join ', ')" -RunId $RunId }
        
        # Remove unmatched members from SGroup that are not in CGroup
        $RemovedUsers = @()
        foreach ($User in $UsersNotInCGroup) 
            {
                try     { 
                        Remove-ADGroupMember -Identity $SgroupName -Members $User -Confirm:$false
                        $RemovedUsers += $User
                        }
                catch   {Write-UserSyncLog -Statement "Failed to remove user '$User' from group '$SgroupName'. Error: $_" -IsError $true -RunId $RunId }
            }

        if ($RemovedUsers.Count -gt 0) { Write-UserSyncLog -Statement "Removed users from group '$SgroupName': $($RemovedUsers -join ', ')" -RunId $RunId }
        Write-UserSyncLog -Statement "Successfully removed unmatched members from group '$SgroupName' with $($RemovedUsers.Count) members " -RunId $RunId
        
        Write-host "Successfully removed unmatched members from group '$SgroupName'. with $($RemovedUsers.Count) members on  $(1000+$RunId)" 
        Write-Host ('*' * 100)

    } catch {Write-UserSyncLog -Statement "An error occurred: $_" -IsError $true -RunId $RunId}
}


# Get all AD groups matching the pattern and process them
$CGroups = Get-ADGroup -Filter "name -like 'APP-SS-*_C'" | Select-Object -ExpandProperty Name
Write-UserSyncLog -Statement "Found $($CGroups.Count) groups matching pattern 'APP-SS-*_C': $($CGroups -join ', ')" -EventId 100
Write-Host ('*' * 100)
$RunId= 1
foreach ($CGroupName in $CGroups) {
    # Derive S group name by replacing _C with _S at the end
    $SGroupName = $CGroupName -replace '_C$', '_S'
    Write-UserSyncLog -Statement "Processing group pair: '$CGroupName' -> '$SGroupName'"
    
    try {        Proccess-SSGroup -CgroupName $CGroupName -SgroupName $SGroupName -RunId $RunId    } 
    catch {        Write-UserSyncLog -Statement "Failed to process group pair '$CGroupName' -> '$SGroupName'. Error: $_" -IsError $true
    }
    $RunId++ # Increment runid for the next iteration to give new log entries ids
}
