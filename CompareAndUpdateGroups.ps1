

function Update-SGroup {
        param (
            [string]$sGroupName,
            [array]$membersToAdd
        )
        
    try {
        Write-Log "Starting update for group: $sGroupName"
        if ($useADSI) {
            $group = [ADSI]"LDAP://CN=$sGroupName,CN=Users,DC=lyamlab,DC=lab"
        } else {
            $group = Get-ADGroup -Identity $sGroupName
        }
        if ($group) {
            Write-Log "Found group $sGroupName, proceeding with member updates"
            
            # First, remove all existing members
            if ($useADSI) {
                foreach ($member in $group.Member) {
                    $memberEntry = New-Object System.DirectoryServices.DirectoryEntry($member)
                    Write-Log "Removing member $($memberEntry.SamAccountName) from $sGroupName"
                    $group.Remove($member)
                }
            } else {
                $existingMembers = Get-ADGroupMember -Identity $sGroupName
                if ($existingMembers) {
                    Write-Log "Removing $($existingMembers.Count) existing members from $sGroupName"
                    foreach ($member in $existingMembers) {
                        Write-Log "Removing member $($member.SamAccountName) from $sGroupName"
                        Remove-ADGroupMember -Identity $sGroupName -Members $member.SamAccountName -Confirm:$false
                    }
                }
            }
            
            # Verify group is empty
            if ($useADSI) {
                if ($group.Member.Count -eq 0) {
                    Write-Log "Verified $sGroupName is empty"
                } else {
                    Write-Log "WARNING: Group $sGroupName still has members after removal: $($group.Member.Count)"
                }
            } else {
                $verifyMembers = Get-ADGroupMember -Identity $sGroupName
                if ($verifyMembers) {
                    Write-Log "WARNING: Group $sGroupName still has members after removal: $($verifyMembers.SamAccountName -join ', ')"
                } else {
                    Write-Log "Verified $sGroupName is empty"
                }
            }
            
            # Add new members
            Write-Log "Adding $($membersToAdd.Count) new members to $sGroupName"
            foreach ($member in $membersToAdd) {
                Write-Log "Adding member $member to $sGroupName"
                if ($useADSI) {
                    $group.Add("LDAP://CN=$member,CN=Users,DC=lyamlab,DC=lab")
                } else {
                    Add-ADGroupMember -Identity $sGroupName -Members $member -Confirm:$false
                }
            }
            Write-Log "Successfully updated group $sGroupName with $($membersToAdd.Count) members"
        } else {
            Write-Log "ERROR: Group $sGroupName not found"
        }
    }
    catch {
        Write-Log "ERROR updating group $sGroupName : $($_.Exception.Message)"
    }
}
    
    # Main script
    try {
        Write-Log "=== Script Execution Started ==="
        
        Write-Log "Getting lic_group members..."
        $licGroupMembers = Get-GroupMembers "lic_group"
        Write-Log "Found $($licGroupMembers.Count) members in lic_group"
    
        Write-Log "Getting list of _C groups..."
        if ($useADSI) {
            $root = New-Object System.DirectoryServices.DirectoryEntry("LDAP://OU=TestUsers,OU=Staff,DC=lyamlab,DC=lab")
            $searcher = New-Object System.DirectoryServices.DirectorySearcher($root)
            $searcher.Filter = "(&(objectClass=group)(cn=*_C))"
            $cGroups = $searcher.FindAll()
        } else {
            $cGroups = Get-ADGroup -Filter "Name -like '*_C'"
        }
        Write-Log "Found $($cGroups.Count) _C groups"
        
        foreach ($cGroup in $cGroups) {
            if ($useADSI) {
                $cGroupName = $cGroup.Properties["cn"][0]
            } else {
                $cGroupName = $cGroup.Name
            }
            $sGroupName = $cGroupName -replace "_C$", "_S"
            
            Write-Log "Processing group pair: $cGroupName -> $sGroupName"
            
            # Get _C group members
            $cGroupMembers = Get-GroupMembers $cGroupName
            Write-Log "Found $($cGroupMembers.Count) members in $cGroupName"
            
            # Find matching members
            $matchingMembers = $cGroupMembers | Where-Object { $licGroupMembers -contains $_ }
            Write-Log "Found $($matchingMembers.Count) matching members between $cGroupName and lic_group"
            
            # Update _S group
            Update-SGroup $sGroupName $matchingMembers
        }
        Write-Log "=== Script Execution Completed Successfully ==="
    }
    catch {
        Write-Log "=== CRITICAL ERROR: $($_.Exception.Message) ==="
    }
    finally {
        if ($searcher) { 
            $searcher.Dispose()
            Write-Log "Cleaned up searcher object"
        }
        if ($root) { 
            $root.Dispose()
            Write-Log "Cleaned up root object"
        }
        if ($cGroups) { 
            $cGroups.Dispose()
            Write-Log "Cleaned up cGroups object"
        }
        Write-Log "=== Script Execution Ended ==="
    }
