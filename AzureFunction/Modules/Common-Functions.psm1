

. .\Common-Classes.ps1

$certPassword = 'c@rt1f1c@teP@ssw0rd'
$CertFileLocation = './data'

# -ErrorAction SilentlyContinue -WarningAction Ignore
# -ErrorAction $error_action -WarningAction $warning_action

# $error_action = "SilentlyContinue"
# $warning_action = "Ignore"

#============================================================================================================================================
# Install-Module Az

function Get-Tenant {
	[OutputType([TenantInfo])]
    param (
        [string]$tenantName
    )

	foreach ($Tenant in $Tenants) {
		if ($Tenant.TenantName -eq $tenantName -or $Tenant.TenantId -eq $tenantName -or $Tenant.TenantTitle -eq $tenantName) {
			return [TenantInfo]$Tenant
		}
	}
}

#Get-Tenant("dev1.rb.moe.gov.sa")| $_.ToString()

#============================================================================================================================================

function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [ValidateRange(4,[int]::MaxValue)]
        [int] $length,
        [int] $upper = 1,
        [int] $lower = 1,
        [int] $numeric = 1,
        [int] $special = 1
    )
    if($upper + $lower + $numeric + $special -gt $length) {
        throw "number of upper/lower/numeric/special char must be lower or equal to length"
    }
    $uCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lCharSet = "abcdefghijklmnopqrstuvwxyz"
    $nCharSet = "0123456789"
    $sCharSet = "/*-+,!?=()@;:._"
    $charSet = ""
    if($upper -gt 0) { $charSet += $uCharSet }
    if($lower -gt 0) { $charSet += $lCharSet }
    if($numeric -gt 0) { $charSet += $nCharSet }
    if($special -gt 0) { $charSet += $sCharSet }
    
    $charSet = $charSet.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
    }
    $password = (-join $result)
    $valid = $true
    if($upper   -gt ($password.ToCharArray() | Where-Object {$_ -cin $uCharSet.ToCharArray() }).Count) { $valid = $false }
    if($lower   -gt ($password.ToCharArray() | Where-Object {$_ -cin $lCharSet.ToCharArray() }).Count) { $valid = $false }
    if($numeric -gt ($password.ToCharArray() | Where-Object {$_ -cin $nCharSet.ToCharArray() }).Count) { $valid = $false }
    if($special -gt ($password.ToCharArray() | Where-Object {$_ -cin $sCharSet.ToCharArray() }).Count) { $valid = $false }
 
    if(!$valid) {
         $password = Get-RandomPassword $length $upper $lower $numeric $special
    }
    return $password
}

# Get-RandomPassword 20 3 3 2 2

#============================================================================================================================================

function Read-Users-From-CSV {
	[OutputType([System.Collections.Generic.List[UserInfo]])]
	param (
		[string]$file_path
	)
	
	# $users_new = New-Object System.Collections.ArrayList
	$users_new = [System.Collections.Generic.List[UserInfo]]@()
	
	if (!(Test-Path -Path $file_path -PathType Leaf)) {
		return [System.Collections.Generic.List[UserInfo]]$users_new
	}
	
	# Read source users
	$users = Import-Csv -Path $file_path
	$users_count = $users.Count

	foreach ($_ in $users) {
		# $user_name = $_.Name
		# $user_tenant = $_.Tenant
		# $tenant = Get-Tenant($user_tenant)
		# $user_email = $user_name + $_.Tenant
		
		$user_temp = [UserInfo]::new();
		$user_temp.Name = $_.Name
		$user_temp.SourceTenant = $_.SourceTenant
		$user_temp.TargetTenant = $_.TargetTenant
		$user_temp.SourceEmail = $_.Name + "@" + $_.SourceTenant
		$user_temp.TargetEmail = $_.Name + "@" + $_.TargetTenant
		$user_temp.SourceId = $_.SourceId
		$user_temp.TargetId = $_.TargetId
		$user_temp.isTeacher = ($_.isTeacher -eq 'True' ? $true : $false)
		$user_temp.isStudent = ($_.isStudent -eq 'True' ? $true : $false)
		$user_temp.isMigratedFetched = ($_.isMigratedFetched -eq 'True' ? $true : $false)
		$user_temp.isMigratedLocked = ($_.isMigratedLocked -eq 'True' ? $true : $false)
		$user_temp.isMigratedHasMailbox = ($_.isMigratedHasMailbox -eq 'True' ? $true : $false)
		$user_temp.isMigratedMailBox = ($_.isMigratedMailBox -eq 'True' ? $true : $false)
		$user_temp.isMigratedBatchStarted = ($_.isMigratedBatchStarted -eq 'True' ? $true : $false)
		$user_temp.isMigratedBatchSuccess = ($_.isMigratedBatchSuccess -eq 'True' ? $true : $false)
		$user_temp.isMigratedGroups = ($_.isMigratedGroups -eq 'True' ? $true : $false)
		$user_temp.isMigratedLicenses = ($_.isMigratedLicenses -eq 'True' ? $true : $false)
		$user_temp.isMigratedStatus = ($_.isMigratedStatus -eq 'True' ? $true : $false)
		$user_temp.TargetPassword = $_.TargetPassword
		$user_temp.MigrationBatchName = $_.MigrationBatchName
		$user_temp.MigrationBatchNumber = $_.MigrationBatchNumber
		$user_temp.MigrationDirection = "$($_.SourceTenant)-$($_.TargetTenant)"
		$user_temp.MigrationDirectionOrdered = ($_.SourceTenant -lt $_.TargetTenant) ? "$($_.SourceTenant)-$($_.TargetTenant)" : "$($_.TargetTenant)-$($_.SourceTenant)"

		$users_new.Add($user_temp)
		# $users_new += $user_temp
	}

	return $users_new
}

#============================================================================================================================================

function Import-Users-Info {
	# [OutputType([System.Collections.Generic.List[UserInfo]])]
	param (
		[TenantInfo]$tenant,
		[System.Collections.Generic.List[UserInfo]]$users,
		[bool]$is_source = $true
	)
	
	if (!$users) { return [System.Collections.Generic.List[UserInfo]]@() }
	if ($users.Count -eq 0 ) { return [System.Collections.Generic.List[UserInfo]]@() }

	$tenant = $tenant ? $tenant : (Get-Tenant($users[0].SourceTenant))

	Log "Start 'Import-Users-Info'"
	Log "Set tenant '$($tenant.TenantName)' as $($is_source ? "source" : "target")"

	# Login
	# Connect-ExchangeOnline-Custom $tenant
	Connect-AzAccount-Custom $tenant
	
	# Get user info
	# https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azaduser?view=azps-9.2.0
	# https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azadgroupmember?view=azps-9.2.0
	# $users_new = [System.Collections.Generic.List[UserInfo]]@()

	foreach ($_ in $users) {
		$user_name = $_.Name
		$user_tenant_domain = $tenant.TenantName
		$user_email = $_.Email ? $_.Email : "$user_name@$user_tenant_domain"

		$tenant_teacher_group_id = $tenant.TeacherGroupId
		$tenant_student_group_id = $tenant.StudentGroupId

		try {
			Log "Fetching user id for '$user_email' from tenant '$user_tenant_domain'"
			$user = Get-AzADUser -UserPrincipalName $user_email -Select 'Id' -ErrorAction Stop #-WarningAction $warning_action
			$user_id = $user.Id
		}
		catch {
			Log-Error "Failed to fetch user id for '$user_email' from tenant '$user_tenant_domain'"
			Log-Error "Exception = $_"
			$user_id = $null
		}
		Log "Fetched user id '$user_id' for '$user_email' from tenant '$user_tenant_domain'"
		
		if ($is_source -eq $true) {
			Log "Set user id '$user_id' for '$user_email' as source tenant user id"
			Log "Trying to identigy user group (teacher, student) for '$user_email'"
			try {
				$temp = Get-AzADGroupMember -GroupObjectId $tenant_teacher_group_id -Select 'Id' -Filter "Id eq '$user_id'" -ErrorAction Stop #-WarningAction $warning_action
				$user_is_teacher = ($null -ne $temp)
			}
			catch {
				$user_is_teacher = $false
			}
			
			try {
				$temp = Get-AzADGroupMember -GroupObjectId $tenant_student_group_id -Select 'Id' -Filter "Id eq '$user_id'" -ErrorAction Stop #-WarningAction $warning_action
				$user_is_student = ($null -ne $temp)
			}
			catch {
				$user_is_student = $false
			}
			if ($user_is_teacher -or $user_is_student) {
				Log "Set user group for '$user_email' as a '$($user_is_teacher ? "teacher" : "student")'"
			}
			if (!$user_is_teacher -and !$user_is_student) {
				Log-Error "Failed to identify user group (teacher, student) for '$user_email'"
			}
			
			if ($null -ne $user_id -and ($user_is_teacher -or $user_is_student)) {
				$_.isMigratedFetched = $true
				$_.SourceId = $user_id
				$_.isTeacher = $user_is_teacher
				$_.isStudent = $user_is_student
			} eles {
				$_.isMigratedFetched = $false
			}
		} else {
			Log "Set user id '$user_id' for '$user_email' as target tenant user id"

			$_.TargetId = $user_id
			# $_.isTeacher = $user_is_teacher
			# $_.isStudent = $user_is_student
		}

		# TODO: Read user UsageLocation property
		# https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/get-mguser?view=graph-powershell-1.0
		# Get-MgUser -UserId "7d4f55b8-d0da-49fe-804e-bfdf6d568839" -Select UsageLocation | Select-Object UsageLocation

		# $user_temp = [UserInfo]::new(
		# 	$user_id,
		# 	$user_name,
		# 	$user_tenant,
		# 	$user_email,
		# 	$user_is_teacher,
		# 	$user_is_student
		# );

		# $users_new += $user_temp
	}

	Log "End 'Import-Users-Info'"

	# return $users
}

#============================================================================================================================================

function Save-Users-To-CSV {
	param (
		[System.Collections.Generic.List[UserInfo]]$users,
		[string]$file_path
	)

	if ($null -eq $users -or $users.Count -eq 0) { return }
	
	$users | Export-Csv -Path $file_path #-NoTypeInformation

	if ($file_path -contains ".failed") {
		Log "Failed users updated, count = $($users.Count), file '$file_path'"
	} else {
		Log "Saving users state to file '$file_path'"
	}
}

#============================================================================================================================================

function Add-Users-To-Groups {
	param (
		[TenantInfo]$tenant,
		[System.Collections.Generic.List[UserInfo]]$users
	)
	
	# TODO: users grouped by tenant
	if (!$users) {return [System.Collections.Generic.List[UserInfo]]@() }
	if ($users.Count -eq 0 ) {return [System.Collections.Generic.List[UserInfo]]@() }

	Log "Start 'Add-Users-To-Groups'"

	$tenant = $tenant ? $tenant : (Get-Tenant($users[0].Tenant))
	$tenant_teacher_group_id = $tenant.TeacherGroupId
	$tenant_student_group_id = $tenant.StudentGroupId
	
	# Login
	Connect-AzAccount-Custom $tenant
	# Connect-MgGraph-Custom $tenant

	# Group users by type (teacher or student)
	$users_teachers_emails = $users.Where({ $_.isTeacher }) | ForEach-Object { $_.TargetId } # Select-Object -Property TargetEmail
	$users_students_emails = $users.Where({ $_.isStudent }) | ForEach-Object { $_.TargetId } # Select-Object -Property TargetEmail

	$users_teachers_emails = [string[]]$users_teachers_emails
	$users_students_emails = [string[]]$users_students_emails
	
	# Add users to group (Az) - batch update
	# https://learn.microsoft.com/en-us/powershell/module/az.resources/add-azadgroupmember?view=azps-9.2.0
	if ($users_teachers_emails.Count -gt 0) {
		try {
			Log "Adding migrated users to teacher group id '$tenant_teacher_group_id'"
			Add-AzADGroupMember -TargetGroupObjectId $tenant_teacher_group_id -MemberObjectId $users_teachers_emails -ErrorAction Stop
			$users | Where-Object { $users_teachers_emails -contains $_.TargetId } | ForEach-Object { $_.isMigratedGroups = $true }
			Log "Adding migrated users to teacher group id '$tenant_teacher_group_id' succeeded"
		}
		catch {
			Log "Adding migrated users to teacher group id '$tenant_teacher_group_id' failed"
			Log-Error "Exception = $_"
			switch -wildcard ($_.Exception.Message) {
				"*One or more added object references already exist for the following modified properties*" {
					$users | Where-Object { $users_teachers_emails -contains $_.TargetId } | ForEach-Object { $_.isMigratedGroups = $true }
				}
				Default {
					$users | Where-Object { $users_teachers_emails -contains $_.TargetId } | ForEach-Object { $_.isMigratedGroups = $false }
				}
			}
		}
	} else {
		Log "There is no migrated users to add to the student group"
	}

	if ($users_students_emails.Count -gt 0) {
		try {
			Log "Adding migrated users to student group id '$tenant_teacher_group_id'"
			Add-AzADGroupMember -TargetGroupObjectId $tenant_student_group_id -MemberObjectId $users_students_emails -ErrorAction Stop
			$users | Where-Object { $users_students_emails -contains $_.TargetId } | ForEach-Object { $_.isMigratedGroups = $true }
			Log "Adding migrated users to student group id '$tenant_teacher_group_id' succeeded"
		}
		catch {
			Log "Adding migrated users to student group id '$tenant_teacher_group_id' failed"
			Log-Error "Exception = $_"
			switch -wildcard ($_.Exception.Message) {
				"*One or more added object references already exist for the following modified properties*" {
					$users | Where-Object { $users_students_emails -contains $_.TargetId } | ForEach-Object { $_.isMigratedGroups = $true }
				}
				Default {
					$users | Where-Object { $users_students_emails -contains $_.TargetId } | ForEach-Object { $_.isMigratedGroups = $false }
				}
			}
		}
	} else {
		Log "There is no migrated users to add to the student group"
	}

	foreach ($user in $users) {
		if ($user.isMigratedGroups) {
			Log "User '$($user.Name)' was assigned to group ($($user.isTeacher ? "Teacher" : ($user.isStudent ? "Student" : "-"))) successfully"
		} else {
			Log-Error "User '$($user.Name)' failed to assign to group"
		}
	}

	# Add users to group (Microsoft Graph) - one by one update
	# https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.groups/new-mggroupmember?view=graph-powershell-1.0
	# ForEach ($user in $users) {
	# 	if ($user.isTeacher) {
	# 		New-MgGroupMember -GroupId $tenant_teacher_group_id -DirectoryObjectId $user.TargetId
	# 	}
	# 	if ($user.isStudent) {
	# 		New-MgGroupMember -GroupId $tenant_student_group_id -DirectoryObjectId $user.TargetId
	# 	}
	# }

}

#============================================================================================================================================

function Connect-MgGraph-Custom {
	param (
		[TenantInfo]$tenant
	)

	Log "Connecting MgGraph using tenant admin '$($tenant.AdminEmail)'"

	# https://helloitsliam.com/2022/04/20/connect-to-microsoft-graph-powershell-using-an-app-registration/

	# Populate with the App Registration details and Tenant ID
	$tenantid = $tenant.TenantId
	$appid = $tenant.AppId
	$secret = $tenant.AppClientSecret
	
	$body = @{
		Grant_Type    = "client_credentials"
		Scope         = "https://graph.microsoft.com/.default"
		Client_Id     = $appid
		Client_Secret = $secret
	}
	
	$connection = Invoke-RestMethod `
		-Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token `
		-Method POST `
		-Body $body
	
	$token = $connection.access_token
	
	Connect-MgGraph -AccessToken $token | Out-null
}

#============================================================================================================================================

function Connect-AzAccount-Custom {
	param (
		[TenantInfo]$tenant
	)
	# https://www.sqlshack.com/different-ways-to-login-to-azure-automation-using-powershell/

	# $email = $tenant.AdminEmail
	# $plain_password = "123456"
	# $plain_password_secured = ConvertTo-SecureString -String $plain_password -AsPlainText -Force
	# $subscription = "<subscription id>"
	# $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $email,$plain_password_secured
	# Connect-AzAccount -Credential $Credential -Tenant $tenant.TenantId -Subscription $subscription

	Log "Connecting Az account using tenant admin '$($tenant.AdminEmail)'"

	$azureAplicationId = $tenant.AppId
	$azureTenantId = $tenant.TenantId
	$azurePassword = ConvertTo-SecureString $tenant.AppClientSecret -AsPlainText -Force
	$psCred = New-Object System.Management.Automation.PSCredential($azureAplicationId , $azurePassword)
	Connect-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal | Out-null

	# $context = Get-AzContext
	# if (!$context) {
	# 	Connect-AzAccount
	# } else {
	# 	Write-Host " Already connected"
	# }
}

#============================================================================================================================================

function Connect-ExchangeOnline-Custom {
	param (
		[TenantInfo]$tenant
	)
	# https://o365reports.com/2019/12/11/connect-exchange-online-powershell-without-basic-authentication/
	
	# Using a non-MFA account to connect Exchange Online PowerShell
	# $Credential = Get-Credential
	# Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false

	# Using authorized AppId and certificate
	#----Step by step guide---- https://www.youtube.com/watch?v=GyF8HV_35GA --------
	# Log "Connecting Exchange Online using certificate to '$($tenant.TenantName)'"
    $connectSplat = @{
            CertificateFilePath = "/Users/MKD/Downloads/MigrateUsersCrossTenants-2/data/$($tenant.TenantTitle)-Exo.pfx"
            CertificatePassword = $(ConvertTo-SecureString -String $certPassword -AsPlainText -Force)
            AppId = $tenant.ConnectAppId
            Organization = $tenant.TenantName
        }
    Connect-ExchangeOnline @connectSplat

	# Using a MFA account to connect Exchange Online PowerShell
	Log "Connecting Exchange Online using tenant admin '$($tenant.AdminEmail)'"
	Connect-ExchangeOnline -UserPrincipalName $tenant.AdminEmail -ShowBanner:$false | Out-null
}

#============================================================================================================================================

function Add-Licenses-To-Users {
	param (
		[TenantInfo]$tenant,
		[System.Collections.Generic.List[UserInfo]]$users
	)
	
	# TODO: users grouped by tenant
	if (!$users) { return [System.Collections.Generic.List[UserInfo]]@() }
	if ($users.Count -eq 0 ) {return [System.Collections.Generic.List[UserInfo]]@() }

	$tenant = $tenant ? $tenant : (Get-Tenant($users[0].Tenant))
	
	# Login
	# https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0#using-connect-mggraph
	Connect-MgGraph-Custom $tenant
	# Connect-MgGraph -TenantId "616a8d6d-a4ee-497e-8225-18a534713857" -ClientId "60c58f5b-c4dd-4033-b36c-2a637cd5e351" -CertificateThumbprint "6E442BCB760DEE68D59746CE7D7457EF7EAB33C3"
	
	# License ID
	# https://learn.microsoft.com/en-us/microsoft-365/enterprise/view-account-license-and-service-details-with-microsoft-365-powershell?view=o365-worldwide
	# Get-MgSubscribedSku
 
	# Assign licenses
	# https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users.actions/set-mguserlicense?view=graph-powershell-1.0
	# https://learn.microsoft.com/en-us/microsoft-365/enterprise/assign-licenses-to-user-accounts-with-microsoft-365-powershell?view=o365-worldwide
	foreach ($user in $users) {
		$licenses_to_add = @()
		$licenses_to_remove = @()

		if ($user.isTeacher) { $licenses_to_add += @{SkuId = $tenant.TeacherLicenseId} } else { $licenses_to_remove += $tenant.TeacherLicenseId }
		if ($user.isStudent) { $licenses_to_add += @{SkuId = $tenant.StudentLicenseId} } else { $licenses_to_remove += $tenant.StudentLicenseId }

		Log "Setting user licenses add '$licenses_to_add', remove '$licenses_to_add'"
		try {
			Set-MgUserLicense -UserId $user.TargetId -AddLicenses $licenses_to_add -RemoveLicenses $licenses_to_remove #-ErrorAction $error_action -WarningAction $warning_action #-WhatIf

			$user.isMigratedLicenses = $true
		}
		catch {
			Log-Error "Exception = $_"
			if ($_.Exception.Message -eq "User license is inherited from a group membership and it cannot be removed directly from the user.") {
				Log "License $($SKU.SkuPartNumber) is assigned via the group-based licensing feature, either remove the user from the group or unassign the group license, as needed."
				continue
			}
			else {
				$_ | Format-List * -Force; continue #catch-all for any unhandled errors
			}
		}
	}
}

#============================================================================================================================================

function Disable-Users {
	param (
		[TenantInfo]$tenant,
		[System.Collections.Generic.List[UserInfo]]$users
	)
	
	Log "Start 'Disable-Users'"

	# Login
	Connect-AzAccount-Custom $tenant
	# Connect-MgGraph-Custom $tenant

	# Disable user
	foreach ($user in $users) {
		$user_id = $user.SourceId
		$user_email = $user.SourceEmail

		try {
			Log "Disabling user '$user_email'"

			# Using Az
			# https://learn.microsoft.com/en-us/powershell/module/activedirectory/disable-adaccount?view=windowsserver2022-ps
			Update-AzADUser -UPNOrObjectId $user_id -AccountEnabled $false -ErrorAction Stop #-WarningAction $warning_action #-WhatIf

			# Using Microsoft Graph
			# https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/update-mguser?view=graph-powershell-1.0
			# Update-MgUser -UserId $user_id -AccountEnabled

			$user.isMigratedStatus = $true
			Log "Disabling user '$user_email' succeeded"
		}
		catch {
			$user.isMigratedStatus = $false
			# $_ | Format-List * -Force; continue
			Log-Error "Disabling user '$user_email' failed"
			Log-Error "Exception = $_"
		}
	}

	Log "End 'Disable-Users'"
}

#============================================================================================================================================

function New-Migration-Relation {
    param (
		[TenantInfo]$SourceTenant,
        [TenantInfo]$TargetTenant,
		[string]$MigrateUsersListSecurityGroup
    )

	$MigrationEndPoint = "MigrationEndPoint-$($SourceTenant.TenantTitle)-$($TargetTenant.TenantTitle)"
	$MigrateUsersListSecurityGroup = $MigrateUsersListSecurityGroup ? $MigrateUsersListSecurityGroup : "MigrateUsersListSecurityGroup"


	#----------------------------------------------------------------------------------------------------------------------------------------
	#---------------------------------     Target Configuration    --------------------------------------------------------------------------
	#----------------------------------------------------------------------------------------------------------------------------------------

	# Login
	Connect-ExchangeOnline-Custom $TargetTenant

	$tenant_source_onmicrosoft = $SourceTenant.TenantOnMicrosoft
	$tenant_target_client_id = $TargetTenant.AppId

	# Create an application 
	# grant Mailbox.Migration permission on the target tenant
	# TODO:

	# Admin consent
	# Generate URL to grant admin consent for target application (application from detination and URL to source)
	# run the URL in browser and accept the admin consent from source tenant
	$consentUrl = "https://login.microsoftonline.com/$tenant_source_onmicrosoft/adminconsent?client_id=$tenant_target_client_id&redirect_uri=https://schools.t4edu.com"
	Log "Opening consent url: $consentUrl" 
	# Start-Process $consentUrl
	
	# Waiting the admin consent
	# Read-Host -Prompt "Please accept the consent on '$($SourceTenant.TenantName)', then enter any key to continue...."

	# IsDehydrated
	$org_config = Get-OrganizationConfig | Select-Object IsDehydrated
	if ($org_config.IsDehydrated -eq $true) { Enable-OrganizationCustomization }

	# Migration
	# Check existing migration, create if not exist
	$endpoints = Get-MigrationEndpoint
	$endpoints = ($endpoints  | ForEach-Object { if ($_.Identity -eq $MigrationEndPoint) { return $true } } )
	if ($endpoints -ne $true) {
		Log "Creating endpoint $MigrationEndPoint"
		$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TargetTenant.AppId, (ConvertTo-SecureString -String $TargetTenant.AppClientSecret -AsPlainText -Force)
		New-MigrationEndpoint -RemoteServer outlook.office.com -RemoteTenant $SourceTenant.TenantName -Credentials $Credential -ExchangeRemoteMove:$true -Name $MigrationEndPoint -ApplicationId $TargetTenant.AppId
	}

	# Create Mail-enabled security group
	$securityGroup = Get-DistributionGroup -Filter "Name -eq '$MigrateUsersListSecurityGroup'"
	if ($null -eq $securityGroup) {
		New-DistributionGroup -Type Security -Name $MigrateUsersListSecurityGroup
	}

	#----------------------------------------------------------------------------------------------------------------------------------------
	#---------------------------------     Source Configuration    --------------------------------------------------------------------------
	#----------------------------------------------------------------------------------------------------------------------------------------

	# Login
	Connect-ExchangeOnline-Custom $SourceTenant

	# IsDehydrated
	$org_config = Get-OrganizationConfig | Select-Object IsDehydrated
	if ($org_config.IsDehydrated -eq $true) { Enable-OrganizationCustomization }
	
	#----------------------------------------------------------------------------------------------------------------------------------------
	#--------------------------------------------------    Test    --------------------------------------------------------------------------
	#----------------------------------------------------------------------------------------------------------------------------------------

	# Connect-ExchangeOnline -UserPrincipalName $TargetTenant.AdminEmail -ShowBanner:$false

	# Test-MigrationServerAvailability -EndPoint $MigrationEndPoint -TestMailbox $TestEmail	
}

#============================================================================================================================================

function Add-Users-To-SecurityGroup {
    param (
		[TenantInfo[]]$tenant, 
		[System.Collections.Generic.List[UserInfo]]$users, 
		$group_name
    )
	if ($users.Count -eq 0) { return }
	Log "Start 'Add-Users-To-SecurityGroup'"

	# Login
	Connect-ExchangeOnline-Custom $tenant
	
	# Security Group
	# Add source users to mail-enabled security group
	# https://learn.microsoft.com/en-us/powershell/module/exchange/get-distributiongroup?view=exchange-ps
	# https://learn.microsoft.com/en-us/powershell/module/exchange/add-distributiongroupmember?view=exchange-ps
	Log "Checking if security group '$group_name' is exists"
	$group = Get-DistributionGroup -Identity $group_name
	if ($null -eq $group) {
		Log "Security group '$group_name' on tenant '$($tenant.TenantName)' is not exists"

		try {
			Log "Creating security group '$group_name' at tenant '$($tenant.TenantName)'"
			New-DistributionGroup -Name $group_name -Type "Security" -ErrorAction Stop
		}
		catch {
			Log-Error "Creating security group '$group_name' on tenant '$($tenant.TenantName)' failed"
			Log-Error "Exception = $_"
		}
		Log "Creating security group '$group_name' on tenant '$($tenant.TenantName)' succeeded"
	} else {
		Log "Security group '$group_name' on tenant '$($tenant.TenantName)' is exists"
	}

	foreach ($user in $users) {
		$user_name = $user.Name

		try {
			Log "Adding user '$user_name' to the mail-enabled security group '$group_name' on tenant '$($tenant.TenantName)'"
			Add-DistributionGroupMember -Identity $group_name -Member $user_name -Confirm:$false -BypassSecurityGroupManagerCheck -ErrorAction Stop #-WarningAction $warning_action
			$user.isMigratedLocked = $true
		}
		catch {
			switch -wildcard ($_.Exception.Message) {
				"*Microsoft.Exchange.Management.Tasks.MemberAlreadyExistsException*" { $user.isMigratedLocked = $true }
				Default {
					Log-Error "Exception = $_"
					$user.isMigratedLocked = $false
				}
			}
		}

		if ($user.isMigratedLocked) {
			Log "Adding user '$user_name' to the mail-enabled security group '$group_name' on tenant '$($tenant.TenantName)' succeeded"
		} else {
			Log-Error "Adding user '$user_name' to the mail-enabled security group '$group_name' on tenant '$($tenant.TenantName)' failed"
		}
	}

	Log "End 'Add-Users-To-SecurityGroup'"
}

#============================================================================================================================================

function Remove-Users-From-SecurityGroup {
    param (
		[TenantInfo[]]$tenant, 
		[System.Collections.Generic.List[UserInfo]]$users, 
		$group_name
    )

	# Login
	Log "Connect Exchange Online source '$($tenant.TenantName)'"
	Connect-ExchangeOnline-Custom $tenant
	
	# Security Group
	# Add source users to mail-enabled security group
	# https://learn.microsoft.com/en-us/powershell/module/exchange/get-distributiongroup?view=exchange-ps
	# https://learn.microsoft.com/en-us/powershell/module/exchange/add-distributiongroupmember?view=exchange-ps
	$group = Get-DistributionGroup -Identity $group_name
	if ($null -ne $group) {
		Log "Group '$group_name' found in tenant $($tenant.TenantName)"
		foreach ($user in $users) {
			$user_name = $user.Name

			try {
				Log "Removing user '$user_name' from the mail-enabled security group '$group_name' on tenant '$($tenant.TenantName)'"
				Remove-DistributionGroupMember -Identity $group_name -Member $user_name -BypassSecurityGroupManagerCheck -ErrorAction Stop #-WarningAction $warning_action
				$user.isMigratedLocked = $false
			}
			catch {
				switch -wildcard ($_.Exception.Message) {
					"*Microsoft.Exchange.Management.Tasks.MemberAlreadyExistsException*" { $user.isMigratedLocked = $false }
					Default {
						Log-Error "Exception = $_"
						$user.isMigratedLocked = $true
					}
				}
			}
	
			if ($user.isMigratedLocked) {
				Log "Removing user '$user_name' from the mail-enabled security group '$group_name' on tenant '$($tenant.TenantName)' succeeded"
			} else {
				Log-Error "Removing user '$user_name' from the mail-enabled security group '$group_name' on tenant '$($tenant.TenantName)' failed"
			}
		}
	}

}

#============================================================================================================================================

function New-Mailbox-Migration-Batch {
    param (
		[TenantInfo]$SourceTenant, 
		[TenantInfo]$TargetTenant, 
		[System.Collections.Generic.List[UserInfo]]$users,
		[string]$migration_batch_name,
		[string]$directory_today_processing
    )
	Log "Start 'New-Mailbox-Migration-Batch'"
	Log "Users count = $($users.Count) users"

	#-----------------------------------------------------------------------------------------------
	#---------------------------------     Source     ----------------------------------------------
	#-----------------------------------------------------------------------------------------------
	$migration_endpoint = "MigrationEndPoint-$($SourceTenant.TenantTitle)-$($TargetTenant.TenantTitle)"
	$security_group_name = $security_group_name ? $security_group_name : "MigrateUsersListSecurityGroup"
	
	Log "Migrating from tenant '$($SourceTenant.TenantName)' to tenant '$($TargetTenant.TenantName)' using MigrationEndPoint = '$migration_endpoint'"

	# Login
	Connect-ExchangeOnline-Custom $SourceTenant

	# Prepare users mailboxes
	$users_mailboxes = @()
	foreach ($user in $users) {
		$user_email = $user.Name + $SourceTenant.TenantEmailPrefix

		try {
			Log "Getting user's mailbox '$user_email' from tenant '$($SourceTenant.TenantName)'"
			$user_mailbox = Get-Mailbox $user_email -ErrorAction Stop
		}
		catch {
			$user_mailbox = $null
			Log-Error "Exception = $_"
		}

		if ($null -ne $user_mailbox) {
			$users_mailboxes += $user_mailbox
			$user.isMigratedHasMailbox = $true
			Log "Getting user's mailbox '$user_email' from tenant '$($SourceTenant.TenantName)' succeeded"
		} else {
			$user.isMigratedHasMailbox = $false
			Log-Error "Getting user's mailbox '$user_email' from tenant '$($SourceTenant.TenantName)' failed"
		}
	}

	if ($users_mailboxes.Count -eq 0) {
		Log "Unable to continue beacause no mailboxes was found, Count = 0"
		return
	}

	# Set MailboxMoveCapability RemoteOutbound
	Set-OrganizationRelationship-Custom $TargetTenant $true

	#-----------------------------------------------------------------------------------------------
	#---------------------------------     Target     ----------------------------------------------
	#-----------------------------------------------------------------------------------------------

	# Login
	Connect-ExchangeOnline-Custom $TargetTenant

	# Set MailboxMoveCapability Inbound
	Set-OrganizationRelationship-Custom $SourceTenant $false

	# $users_mailboxes = Import-Clixml $migration_batch_source_users_xml_file
	Add-Type -AssemblyName System.Web

	$users_mailboxes_new = @()
	foreach ($user_mailbox in $users_mailboxes) {
		$user = $users | Where-Object { $_.Name -eq $user_mailbox.Alias } | Select-Object -First 1

		if ($null -eq $user) { continue; }

		$mosi = $user_mailbox.Alias + $TargetTenant.TenantEmailPrefix
		Log "Creating '$mosi' on the target tenant '$($SourceTenant.TenantName)'"
		
		$password = Get-RandomPassword 12 3 3 3 3
		$securedPassword = ConvertTo-SecureString $password -AsPlainText -Force
		$x500 = "x500:" + $user_mailbox.LegacyExchangeDn
		
		$user.TargetPassword = $password
		
		try {
			Log "Creating new mailbox for user '$mosi' on target tenant '$($TargetTenant.TenantName)'"
			$tmpUser = New-MailUser -MicrosoftOnlineServicesID $mosi -PrimarySmtpAddress $mosi -ExternalEmailAddress $user_mailbox.PrimarySmtpAddress -FirstName $user_mailbox.FirstName -LastName $user_mailbox.LastName -Name $user_mailbox.Name -DisplayName $user_mailbox.DisplayName -Alias $user_mailbox.Alias -Password $securedPassword -ErrorAction Stop
			$tmpUser | Set-MailUser -EmailAddresses @{ add = $x500 } -ExchangeGuid $user_mailbox.ExchangeGuid -ArchiveGuid $user_mailbox.ArchiveGuid #-CustomAttribute1 "PleaseMigrate"

			$user.isMigratedMailBox = $true
			$users_mailboxes_new += $user_mailbox
		}
		catch {
			Log-Error "Exception = $_"
			switch -wildcard ($_.Exception.Message) {
				# New-MailUser: ExB10BE9|Microsoft.Exchange.Management.Tasks.WLCDManagedMemberExistsException|The proxy address "SMTP:test_student_11@dev2.rb.moe.gov.sa" is already being used by the proxy addresses or LegacyExchangeDN. Please choose another proxy address.
				"*Microsoft.Exchange.Management.Tasks.WLCDManagedMemberExistsException*" {
					$user.isMigratedMailBox = $true
					$users_mailboxes_new += $user_mailbox
				} 
				Default { $user.isMigratedMailBox = $false }
			}
		}

		if ($user.isMigratedMailBox) {
			Log "Creating new mailbox for user '$mosi' on target tenant '$($TargetTenant.TenantName)' succeeded"
		} else {
			Log-Error "Creating new mailbox for user '$mosi' on target tenant '$($TargetTenant.TenantName)' failed"
		}	

		$tmpx500 = $user_mailbox.EmailAddresses | Where-Object { $_ -match "x500" }
		$tmpx500 | ForEach-Object { Set-MailUser $user_mailbox.Alias -EmailAddresses @{ add = "$_" } }
	}
	$users_mailboxes = $users_mailboxes_new

	if ($users_mailboxes.Count -eq 0) {
		Log "Unable to continue beacause no new mailboxes was created at target tenant, Count = 0"
		return
	}

	# Store source user info to csv file, after editing info to send it to target
	$users_mailboxes_modified = $users_mailboxes | Select-Object @{Name='EmailAddress'; Expression={($_.Alias + $TargetTenant.TenantEmailPrefix)}}, @{Name='BadItemLimit';Expression={'100'}}, @{Name='MailboxType';Expression={'PrimaryAndArchive'}} 
	
	$users_mailboxes_modified_string = ($users_mailboxes_modified | ConvertTo-Csv -NoTypeInformation) -join "`n"
	$file_data = [System.Text.Encoding]::UTF8.GetBytes($users_mailboxes_modified_string) 
	# $file_data = $file_data + 10

	try {
		Log "Creating new MigrationBatch '$migration_batch_name' with '-Autostart' flag at target tenant '$($TargetTenant.TenantName)'"
		New-MigrationBatch -Name $migration_batch_name -SourceEndpoint $migration_endpoint -CSVData $file_data -Autostart -TargetDeliveryDomain $TargetTenant.TenantName -ErrorAction Stop

		$users | Where-Object { $_.isMigratedMailBox } | ForEach-Object { $_.MigrationBatchName = $migration_batch_name; $_.isMigratedBatchStarted = $true; }
		Log "Creating new MigrationBatch '$migration_batch_name' with '-Autostart' flag at target tenant '$($TargetTenant.TenantName)' succeeded"
	}
	catch {
		$users | Where-Object { $_.isMigratedMailBox } | ForEach-Object { $_.MigrationBatchName = $null; $_.isMigratedBatchStarted = $false; }
		Log-Error "Creating new MigrationBatch '$migration_batch_name' with '-Autostart' flag at target tenant '$($TargetTenant.TenantName)' failed"
		Log-Error "Exception = $_"
	}
}

#============================================================================================================================================

function Set-OrganizationRelationship-Custom {
	param (
		[TenantInfo]$tenant,
		[bool]$is_out_bound
	)

	Log "Using current session in 'Set-OrganizationRelationship-Custom'"

	if ($is_out_bound) {
		# Organization Relationship
		# Create a new organization relationship or edit your existing organization relationship object to your target (destination) tenant in Exchange Online PowerShell:
		$org_relationship_source_name = "OrgRelationship-$($tenant.TenantTitle)"

		$orgrels = Get-OrganizationRelationship
		$existingOrgRel = $orgrels | Where-Object { $_.DomainNames -like $tenant.TenantId }
		if ($null -ne $existingOrgRel)
		{
			Log "Setting organization relationship '$org_relationship_source_name' as MoveCapability = RemoteOutbound"
			Set-OrganizationRelationship $existingOrgRel.Name -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability RemoteOutbound -OAuthApplicationId $tenant.AppId -MailboxMovePublishedScopes $security_group_name
		}
		if ($null -eq $existingOrgRel)
		{
			Log "Creating organization relationship '$org_relationship_source_name' as MoveCapability = RemoteOutbound"
			New-OrganizationRelationship $org_relationship_source_name -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability RemoteOutbound -DomainNames $tenant.TenantId -OAuthApplicationId $tenant.AppId -MailboxMovePublishedScopes $security_group_name
		}
	} else {
		# Organization Relationship
		# Create new or edit your existing organization relationship object to your source tenant.
		$org_relationship_target_name = "OrgRelationship-$($tenant.TenantTitle)"

		$orgrels = Get-OrganizationRelationship
		$existingOrgRel = $orgrels | Where-Object { $_.DomainNames -like $tenant.TenantId }
		if ($null -ne $existingOrgRel) {
			Log "Setting organization relationship '$org_relationship_target_name' as MoveCapability = Inbound"
			Set-OrganizationRelationship $existingOrgRel.Name -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability Inbound
		}
		if ($null -eq $existingOrgRel) {
			Log "Creating organization relationship '$org_relationship_target_name' as MoveCapability = Inbound"
			New-OrganizationRelationship $org_relationship_target_name -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability Inbound -DomainNames $tenant.TenantId
		}
	}
}

#============================================================================================================================================

function Log {
	param (
		[string]$message
	)

	$text = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [INFO]: $($message)"
	Write-Host $text

	if ($null -ne $file_path_processing) {
		$text | Out-File -FilePath "$($file_path_processing.FullName).log" -Append
	}
}

#============================================================================================================================================

function Log-Error {
	param (
		[string]$message
	)

	$text = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [ERROR]: $($message)"
	Write-Host $text

	if ($null -ne $file_path_processing) {
		$text | Out-File -FilePath "$($file_path_processing.FullName).log" -Append
	}
}

#============================================================================================================================================
function New-Certificate-File {
	param (
		[TenantInfo]$tenant
	)

    # Create certificate
    $newCertSplat = @{
        DnsName = $tenant.TenantName
        CertStoreLocation = 'cert:\CurrentUser\My'
        NotAfter = (Get-Date).AddYears(1)
        KeySpec = 'KeyExchange'
    } 
    $mycert = New-SelfSignedCertificate @newCertSplat
	$pfxFilePath = "$CertFileLocation\$($tenant.TenantTitle)-Exo.pfx"
	$cerFilePath = "$CertFileLocation\$($tenant.TenantTitle)-Exo.cer"
	if(-not(Test-Path -Path $pfxFilePath -PathType Leaf)){
		# Export certificate to .pfx file
		$exportCertSplat = @{
			FilePath = $pfxFilePath
			Password = $(ConvertTo-SecureString -String $certPassword -AsPlainText -Force)
		}
		$mycert | Export-PfxCertificate @exportCertSplat
	}
	if(-not(Test-Path -Path $cerFilePath -PathType Leaf)){
		# Export certificate to .cer file
		$mycert | Export-Certificate -FilePath $cerFilePath
	}
}

#============================================================================================================================================
function Connect-ExchangeOnline-Certificate {
	param (
		[TenantInfo]$tenant
	)
	$pfxFilePath = "/Users/MKD/Downloads/MigrateUsersCrossTenants-2/data/$($tenant.TenantTitle)-Exo.pfx"

    # Use Certificate
    $connectSplat = @{
            CertificateFilePath = $pfxFilePath
            CertificatePassword = $(ConvertTo-SecureString -String $certPassword -AsPlainText -Force)
            AppId = $tenant.ConnectAppId
            Organization = $tenant.TenantName
        }
    Connect-ExchangeOnline @connectSplat

	# $appid='818829c0-bce8-465d-96c9-0ccf53307162'
	# $orgname='dev2.rb.moe.gov.sa'
	# $pass='c@rt1f1c@teP@ssw0rd'
	# $path="D:\Projects\Old\Archive-2013-T4edu\VirtualSchool\VirtualSchool5.0-prod\MigrateUsersCrossTenants\NEW\data\dev2-Exo.pfx"

	# $connectSplat = @{
	# 	CertificateFilePath = $path
	# 	CertificatePassword = $(ConvertTo-SecureString -String $pass -AsPlainText -Force)
	# 	AppId = $appid
	# 	Organization = $orgname
	# }
	# Connect-ExchangeOnline @connectSplat
}

#============================================================================================================================================

# $tenant = [TenantInfo]$Tenants[0]

# $users = Read-Users-From-CSV './data/users-2022-12-22-19-00-00.csv'
# $users

# $users = Import-Users-Info $tenant $users
# $users

# $users | Export-Csv -Path 'source-full.csv' #-NoTypeInformation

# $users = [System.Collections.Generic.List[UserInfo]](Read-Users-From-CSV 'source-full.csv')
# $users
# $users_groups = $users | Sort-Object SourceTenant | Group-Object -Property SourceTenant,TargetTenant
# $users_groups

# foreach($users_group in $users_groups) {
# 	$users_group.Name
# 	$users_group.Group
# }

# Add-Users-To-Groups $tenant $users

# $users[0].GetType()

# Connect-MgGraph-Custom $tenant

# Add-Users-To-Licenses $tenant $users

# Connect-AzAccount-Custom $tenant

