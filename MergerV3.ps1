function Add-CommonMembersToGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$SourceGroup1,                # Name of the first source group _C
        [Parameter(Mandatory = $true)][string]$SourceGroup2 = "lic_users",  # Name of the second source group Lic
        [Parameter(Mandatory = $true)][string]$TargetGroup                  # Name of the target group _S
    )

    try {
        # Retrieve members of the source groups
        $MembersGroup1 = Get-ADGroupMember -Identity $SourceGroup1 -Recursive | Where-Object { $_.objectClass -eq 'user' }
        $MembersGroup2 = Get-ADGroupMember -Identity $SourceGroup2 -Recursive | Where-Object { $_.objectClass -eq 'user' }

        # Find common members
        $CommonMembers = $MembersGroup1 | Where-Object { $MembersGroup2 -contains $_ }

        # Add common members to the target group
        foreach ($Member in $CommonMembers) {
            Add-ADGroupMember -Identity $TargetGroup -Members $Member.SamAccountName -Confirm:$false
        }

        Write-Output "Successfully added common members to group '$TargetGroup'."
    } catch {
        Write-Error "An error occurred: $_"
    }
}

Add-CommonMembersToGroup -SourceGroup1 "A_C" -TargetGroup "A_S"

