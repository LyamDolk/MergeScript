function MergeCommonMembers {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupA,
        
        [Parameter(Mandatory=$true)]
        [string]$GroupB,
        
        [Parameter(Mandatory=$true)]
        [string]$GroupC
    )

    # Get members of both groups
    $membersA = Get-ADGroupMember -Identity $GroupA
    $membersB = Get-ADGroupMember -Identity $GroupB

    # Find common members between groups A and B
    $commonMembers = $membersA | Where-Object { $membersB.SamAccountName -contains $_.SamAccountName }

    # Add common members to group C
    foreach ($member in $commonMembers) {
        try {
            Add-ADGroupMember -Identity $GroupC -Members $member -ErrorAction Stop
            Write-Host "Added $($member.SamAccountName) to $GroupC"
        }
        catch {
            Write-Warning "Failed to add $($member.SamAccountName) to $GroupC. Error: $_"
        }
    }

    Write-Host "Process completed. Added $($commonMembers.Count) members to $GroupC"
}
MergeCommonMembers -GroupA A_C -GroupB Lic_Group -GroupC A_S