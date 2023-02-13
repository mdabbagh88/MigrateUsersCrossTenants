
. .\Common-Classes.ps1
. .\Common-Functions.ps1

$security_group_name = "MigrateUsersListSecurityGroup"

Write-Host "Starting Tenants Initialization Driver"

Write-Host "Tenants count = $($Tenants.Count)"

foreach ($tenant_source in $Tenants) {
	foreach ($tenant_target in $Tenants) {
		if ($tenant_source -eq $tenant_target) { continue; }

		$tenant_source_domain = $tenant_source.TenantName
		$tenant_target_domain = $tenant_target.TenantName

		Write-Host "Creating migration relation from '$tenant_source_domain' -> '$tenant_target_domain'"
		
		New-Migration-Relation $tenant_source $tenant_target $security_group_name
		
		Write-Host "Created migration relation from '$tenant_source_domain' -> '$tenant_target_domain'"
	}
}

Write-Host "Finished Tenants Initialization Driver"


# Connect-ExchangeOnline-Custom $Tenants[0]
# Get-MigrationEndpoint

# New-OrganizationRelationship "OrgRelationship-dev1-dev2" -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability RemoteOutbound -DomainNames $TargetTenant.TenantId -OAuthApplicationId $TargetTenant.AppId -MailboxMovePublishedScopes $MigrateUsersListSecurityGroup




