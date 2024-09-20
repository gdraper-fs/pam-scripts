# This is a script for use with Azure Powershell in a customer's tenancy ideally with Global Reader permissions.

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Install-Module Microsoft.Graph
# Install-Module Az

Connect-MgGraph -TenantId "<tenantId>"
Connect-AzAccount -UseDeviceAuthentication -TenantId "<tentantId>"

# Get list of Users for Tenancy
$users = Get-MgUser -All

# Initialize a list to store user info
$userInfo= @()

# Iterate over users to generate a list of target Users
foreach ($user in $users) {
    $userUid = $user.Id
    $userPrincipalName = $user.UserPrincipalName
    $userInfo += [PSCustomObject]@{
        UserUid           = $userUid
        UserPrincipalName = $userPrincipalName
    }
}

# Get list of Roles for Tenancy
$roles = Get-AzRoleDefinition

# Initialize a list to store role info
$roleInfo = @()

# Iterate over roles to generate a list of target Azure Roles
foreach ($role in $roles) {
    $roleName = $role.Name

    $condition1 = $roleName -like "*Owner*"
    $condition2 = $roleName -like "*Contributor*"
    $condition3 = $roleName -like "*Admin*"

    # Check if the role name contains "Owner", "Contributor", or "Admin"
    if ($condition1 -or $condition2 -or $condition3) {
        $roleId = $role.Id
        $roleInfo += [PSCustomObject]@{
            RoleName = $roleName
            RoleId   = $roleId
        }
    }
}

# Initialize a list to store filtered role assignments info
$filteredRoleAssignments = @()

# Iterate over users
foreach ($user in $userInfo) {
    # Get Role Assignments for each user
    $username = $user.UserPrincipalName
    Write-Host "[x] Getting Assignments for $username"
    $roleAssignmentForUser = Get-AzRoleAssignment -ObjectId $user.UserUid
    Write-Host "[x] Received Assignments for $username"

    # Iterate over role Assignments for that user
    foreach ($roleAssignment in $roleAssignmentForUser) {
        
        $roleDefinitionId   = $roleAssignment.RoleDefinitionId
        $roleObjectType     = $roleAssignment.ObjectType
        $roleAssignmentName = $roleAssignment.RoleAssignmentName


        Write-Host "[x] Parsing Assignment $roleAssignmentName for $username"

        if ($roleObjectType -eq "User") {
            foreach ($role in $roleInfo) {
                $roleid = $role.RoleId
                if ($role.RoleId -eq $roleDefinitionId ) {
                    # Add the role assignment to the filtered list
                    Write-Host "[x] ObjectType is a 'User' and RoleId is $roleid which is in the list of Admin Roles"

                    $filteredRoleAssignments += [PSCustomObject]@{
                        UserUid           = $user.UserUid
                        UserPrincipalName = $user.UserPrincipalName
                        RoleName          = $role.RoleName
                        RoleId            = $role.RoleId
                    }
                }
            }
        }
    }
}


foreach ($filtered in $filteredRoleAssignments){
    $userUid = $filtered.UserUid

    Get-MgUserAuthenticationMethodCount -UserId $userUid
}


