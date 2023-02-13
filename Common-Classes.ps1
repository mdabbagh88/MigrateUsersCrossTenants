
# Write-Host "Loading Common-Classes.ps1"

# Command error handler behaviours
# -ErrorAction Stop
# -ErrorAction SilentlyContinue
# -ErrorAction Inquire


class TenantInfo {
    [string]$TenantId
    [string]$TenantName
    [string]$TenantTitle
    [string]$TenantOnMicrosoft
    [string]$TenantEmailPrefix
    [string]$AdminEmail
    [string]$AppId
    [string]$AppClientSecret
    [string]$TeacherGroupId
    [string]$StudentGroupId
    [string]$TeacherLicenseId
    [string]$StudentLicenseId
    [string]$ConnectAppId
    TenantInfo(
		[string]$TenantId,
		[string]$TenantName,
		[string]$TenantTitle,
		[string]$TenantOnMicrosoft,
		[string]$AdminEmail,
		[string]$AppId,
		[string]$AppClientSecret,
		[string]$TeacherGroupId,
		[string]$StudentGroupId,
		[string]$TeacherLicenseId,
		[string]$StudentLicenseId,
		[string]$ConnectAppId
    ){
		$this.TenantId = $TenantId
		$this.TenantName = $TenantName
		$this.TenantTitle = $TenantTitle
		$this.TenantOnMicrosoft = $TenantOnMicrosoft
		$this.AdminEmail = $AdminEmail
		$this.AppId = $AppId
		$this.AppClientSecret = $AppClientSecret
		$this.TenantEmailPrefix= "@" + $TenantName
		$this.TeacherGroupId = $TeacherGroupId
		$this.StudentGroupId = $StudentGroupId
		$this.TeacherLicenseId = $TeacherLicenseId
		$this.StudentLicenseId = $StudentLicenseId
		$this.ConnectAppId = $ConnectAppId
    }
    TenantInfo([Object]$obj){
		$this.TenantId = $obj.TenantId
		$this.TenantName = $obj.TenantName
		$this.TenantTitle = $obj.TenantTitle
		$this.TenantOnMicrosoft = $obj.TenantOnMicrosoft
		$this.AdminEmail = $obj.AdminEmail
		$this.AppId = $obj.AppId
		$this.AppClientSecret = $obj.AppClientSecret
		$this.TenantEmailPrefix= "@" + $obj.TenantName
		$this.TeacherGroupId = $obj.TeacherGroupId
		$this.StudentGroupId = $obj.StudentGroupId
		$this.TeacherLicenseId = $obj.TeacherLicenseId
		$this.StudentLicenseId = $obj.StudentLicenseId
		$this.ConnectAppId = $obj.ConnectAppId
    } 
	# [string]ToString(){
    #     return ("{0}`n{1}`n{2}`n{3}`n{4}`n{5}`n{6}`n`n" -f $this.TenantId,	$this.TenantName, $this.TenantOnMicrosoft, $this.AdminEmail, $this.AppId, $this.AppClientSecret, $this.TenantEmailPrefix)
    # }
}

class UserInfo {
    [string]$Name
    [string]$SourceTenant
    [string]$TargetTenant
    [string]$SourceEmail
    [string]$TargetEmail
    [string]$SourceId
    [string]$TargetId
    [bool]$isTeacher
    [bool]$isStudent
	[bool]$isMigratedFetched = $false
	[bool]$isMigratedLocked = $false
	[bool]$isMigratedHasMailbox = $false
	[bool]$isMigratedMailBox = $false
	[bool]$isMigratedBatchStarted = $false
	[bool]$isMigratedBatchSuccess = $false
	[bool]$isMigratedGroups = $false
	[bool]$isMigratedLicenses = $false
	[bool]$isMigratedStatus = $false
    [string]$TargetPassword = $null
    [string]$MigrationBatchName = $null
	[string]$MigrationBatchNumber = $null
    [string]$MigrationDirection = $null
    [string]$MigrationDirectionOrdered = $null
	UserInfo() {
		$this.isMigratedFetched = $false
		$this.isMigratedLocked = $false
		$this.isMigratedHasMailbox = $false
		$this.isMigratedMailBox = $false
		$this.isMigratedBatchStarted = $false
		$this.isMigratedBatchSuccess = $false
		$this.isMigratedGroups = $false
		$this.isMigratedLicenses = $false
		$this.isMigratedStatus = $false
	}
    UserInfo(
		[string]$Name,
		[string]$SourceTenant,
		[string]$TargetTenant,
		[string]$SourceId,
		[string]$TargetId,
		[bool]$isTeacher,
		[bool]$isStudent,
		[bool]$isMigratedFetched = $false,
		[bool]$isMigratedLocked = $false,
		[bool]$isMigratedHasMailbox = $false,
		[bool]$isMigratedMailBox = $false,
		[bool]$isMigratedBatchStarted = $false,
		[bool]$isMigratedBatchSuccess = $false,
		[bool]$isMigratedGroups = $false,
		[bool]$isMigratedLicenses = $false,
		[bool]$isMigratedStatus = $false,
		[string]$TargetPassword = $null,
		[string]$MigrationBatchName = $null,
		[string]$MigrationBatchNumber = $null
    ){
		$this.Name = $Name
		$this.SourceTenant = $SourceTenant
		$this.TargetTenant = $TargetTenant
		$this.SourceEmail = $Name + "@" + $SourceTenant
		$this.TargetEmail = $Name + "@" + $TargetTenant
		$this.SourceId = $SourceId
		$this.TargetId = $TargetId
		$this.isTeacher = $isTeacher
		$this.isStudent = $isStudent
		$this.isMigratedFetched = $isMigratedFetched
		$this.isMigratedLocked = $isMigratedLocked
		$this.isMigratedHasMailbox = $isMigratedHasMailbox
		$this.isMigratedMailBox = $isMigratedMailBox
		$this.isMigratedBatchStarted = $isMigratedBatchStarted
		$this.isMigratedBatchSuccess = $isMigratedBatchSuccess
		$this.isMigratedGroups = $isMigratedGroups
		$this.isMigratedLicenses = $isMigratedLicenses
		$this.isMigratedStatus = $isMigratedStatus
		$this.TargetPassword = $TargetPassword
		$this.MigrationBatchName = $MigrationBatchName
		$this.MigrationBatchNumber = $MigrationBatchNumber
		$this.MigrationDirection = "$SourceTenant-$TargetTenant"
		$this.MigrationDirectionOrdered = ($SourceTenant -lt $TargetTenant) ? "$SourceTenant-$TargetTenant" : "$TargetTenant-$SourceTenant"
    }
    UserInfo([Object]$obj){
		$this.Name = $obj.Name
		$this.SourceTenant = $obj.SourceTenant
		$this.TargetTenant = $obj.TargetTenant
		$this.SourceEmail = $obj.Name + "@" + $obj.SourceTenant
		$this.TargetEmail = $obj.Name + "@" + $obj.TargetTenant
		$this.SourceId = $obj.SourceId
		$this.TargetId = $obj.TargetId
		$this.isTeacher = $obj.isTeacher
		$this.isStudent = $obj.isStudent
		$this.isMigratedFetched = $obj.isMigratedFetched
		$this.isMigratedLocked = $obj.isMigratedLocked
		$this.isMigratedHasMailbox = $obj.isMigratedHasMailbox
		$this.isMigratedMailBox = $obj.isMigratedMailBox
		$this.isMigratedBatchStarted = $obj.isMigratedBatchStarted
		$this.isMigratedBatchSuccess = $obj.isMigratedBatchSuccess
		$this.isMigratedGroups = $obj.isMigratedGroups
		$this.isMigratedLicenses = $obj.isMigratedLicenses
		$this.isMigratedStatus = $obj.isMigratedStatus
		$this.TargetPassword = $obj.TargetPassword
		$this.MigrationBatchName = $obj.MigrationBatchName
		$this.MigrationBatchNumber = $obj.MigrationBatchNumber
		$this.MigrationDirection = $obj.MigrationDirection
		$this.MigrationDirectionOrdered = $obj.MigrationDirectionOrdered
    }
}


# $Tenants = @([TenantInfo]::new(
# 		"616a8d6d-a4ee-497e-8225-18a534713857", #TenantId
# 		"dev1.rb.moe.gov.sa", #TenantName
# 		"dev1", #TenantTitle
# 		"moedev1.onmicrosoft.com", #$TenantOnMicrosoft
# 		"maldabbagh@dev1.rb.moe.gov.sa", #$AdminEmail
# 		"60c58f5b-c4dd-4033-b36c-2a637cd5e351", #$AppId
# 		"Wxv8Q~r5eEThjsk~ADtQeDPtUrCEkcMdVRvdWasr", #$AppClientSecret
# 		"1579f5ec-8007-4d0d-a879-8178e246bcf1",
# 		"53e63833-361d-4235-b01c-5ec89581f369",
# 		"94763226-9b3c-4e75-a931-5c89701abe66",
# 		"314c4481-f395-4525-be8b-2ec4bb1e9d91"
# 	),[TenantInfo]::new(
# 		"ac0ae679-c35f-4b3a-9bf1-8fd9ed5ca2e6", #TenantId
# 		"dev2.rb.moe.gov.sa", #TenantName
# 		"dev2", #TenantTitle
# 		"moedev2.onmicrosoft.com", #$TenantOnMicrosoft
# 		"maldabbagh@dev2.rb.moe.gov.sa", #$AdminEmail
# 		"da8ddf01-de58-4ea8-a2df-538f29f83952", #$AppId
# 		"KL18Q~wDPE4tyQ6UwU520AujnA8eM4kGsgiUIbB6", #$AppClientSecret
# 		"3c71dd88-4ca0-4951-b13e-6f53e3a46a55",
# 		"fa685670-3d59-4e2b-9916-51c58994eb4e",
# 		"94763226-9b3c-4e75-a931-5c89701abe66",
# 		"314c4481-f395-4525-be8b-2ec4bb1e9d91"
# ))

# $Tenants | ForEach-Object {$_.ToString()}

# $Tenants | Export-Csv -Path 'tenants-info.csv'

$Tenants = [TenantInfo[]](Import-Csv -Path 'tenants-info.csv')
# $Tenants
# $Tenants[0].GetType()


# function Test-Main {
# 	param (
# 	)
# 	$user = [UserInfo]::new()
# 	$user.Name = "test_student_2"
# 	$user.SourceTenant = "dev2.rb.moe.gov.sa"
# 	$user.SourceId = "SourceId"
# 	$user.TargetId = "TargetId"

# 	function Test-PassByRef {
# 		param (
# 			[UserInfo]$param_user
# 		)
# 		$param_user.isMigratedLocked = $true
# 	}
# 	$user.isMigratedLocked
# 	Test-PassByRef $user
# 	$user.isMigratedLocked
# }
# Test-Main 



# [System.Collections.Generic.List[UserInfo]]$users = @()
# $user1 = [UserInfo]::new()
# $user1.Name = "test_student_2"
# $user1.SourceTenant = "dev2.rb.moe.gov.sa"
# $user1.SourceId = "SourceId"
# $user1.TargetId = "TargetId"
# $users
# $users.Add($user1)
# $users
# $user1.Name = "Modified"
# $users
# $users.Remove($user1)
# $users
# $users | Where-Object { $_.Name -eq "test_student_2" } | ForEach-Object { $users.Remove($_) }
# $users
