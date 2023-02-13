
. .\Common-Classes.ps1
. .\Common-Functions.ps1

# Import-Module -Name ExchangePowerShell

# $ErrorActionPreference = 'Continue'
# $WarningPreference = 'Continue'

$file_path_processing = $null

function Main {
	Log "----------------------------------------------------------------------------------------------------------------------------------------"
	Log "Starting Main script"

	$directory_data_path = $(Get-Item ".").FullName + "/data"
	$directory_unprocessed_path = $(Get-Item ".").FullName + "/data/unprocessed"
	$directory_processing_path = $(Get-Item ".").FullName + "/data/processing"
	$directory_processed_path = $(Get-Item ".").FullName + "/data/processed"

	$date_current = Get-Date -Format "yyyy-MM-dd"
	$directory_today_processing_path = "$directory_processing_path/$date_current"
	$directory_today_processed_path = "$directory_processed_path/$date_current"

	$time_current = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
	$file_today_processing_path = "$directory_today_processing_path/users-$time_current.csv"
	# $file_today_processed_path = "$directory_today_processed_path/$time_current.csv"

	# Create today directories at (processing, processed)
	Log "Creating directory '$directory_data_path' if not exists"
	Log "Creating directory '$directory_unprocessed_path' if not exists"
	Log "Creating directory '$directory_processing_path' if not exists"
	Log "Creating directory '$directory_processed_path' if not exists"
	Log "Creating directory '$directory_today_processing_path' if not exists"
	Log "Creating directory '$directory_today_processed_path' if not exists"
	if (!(Test-Path -PathType Container $directory_data_path)) { New-Item -ItemType Directory -Path $directory_data_path | Out-Null }
	if (!(Test-Path -PathType Container $directory_unprocessed_path)) { New-Item -ItemType Directory -Path $directory_data_path | Out-Null }
	if (!(Test-Path -PathType Container $directory_processing_path)) { New-Item -ItemType Directory -Path $directory_data_path | Out-Null }
	if (!(Test-Path -PathType Container $directory_processed_path)) { New-Item -ItemType Directory -Path $directory_data_path | Out-Null }
	if (!(Test-Path -PathType Container $directory_today_processing_path)) { New-Item -ItemType Directory -Path $directory_today_processing_path | Out-Null }
	if (!(Test-Path -PathType Container $directory_today_processed_path)) { New-Item -ItemType Directory -Path $directory_today_processed_path | Out-Null }

	# Combine all unprocessed into one file
	Log "Searching for *.csv files in directory '$directory_unprocessed_path'"
	$files_unprocessed = Get-ChildItem -Path $directory_unprocessed_path -filter "*.csv"

	Log "Found $($files_unprocessed.Count) unprocessed '.csv' files"
	$files_unprocessed | ForEach-Object { Log "Found '$($_.FullName)'" }
	$csv_content_combined = $files_unprocessed | Select-Object -ExpandProperty FullName | Import-Csv
	Log "Trying to merge found files into one file at '$file_today_processing_path'"
	if ($null -ne $csv_content_combined) {
		$csv_content_combined | Export-Csv $file_today_processing_path -NoTypeInformation -Append
		Log "Unprocessed found files merged into one file at '$file_today_processing_path'"
	} else {
		Log "No files found to merge"
	}
	Log "Removing unprocessed files"
	$files_unprocessed | Remove-Item -Verbose

	# Get all files in processing stage.
	$files_processing = Get-ChildItem -Path $directory_today_processing_path -filter "users-*.csv"

	$security_group_name = "MigrateUsersListSecurityGroup"

	foreach ($_ in $files_processing) {
		$file_path_processing = $_

		Log "Start current processing file '$($files_processing.FullName)'"

		$file_name = $_.Name
		$file_name_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
		$file_ext = $_.Extension
		$file_path = $_.FullName
		$file_path_fetched = "$file_path.fetched"
		$file_path_locked = "$file_path.locked"
		$file_path_migrating = "$file_path.migrating"
		$file_path_migrated = "$file_path.migrated"
		$file_path_failed = "$file_path.failed"
		$file_path_migrating_1 = "$file_path_migrating.1"
		$file_path_migrating_2 = "$file_path_migrating.2"
		$file_path_migrated_1 = "$file_path_migrated.1"
		$file_path_migrated_2 = "$file_path_migrated.2"

		$file_path_processed = $file_path.Replace("processing", "processed")
		$file_path_processed_user_output = $file_path_processed.Replace(".csv", "-output.csv")
		
		$time_current = $file_name_no_ext

		$file_is_processed = (Test-Path -Path $file_path_processed -PathType Leaf)
		$file_is_migrated = $file_is_processed -or (Test-Path -Path $file_path_migrated -PathType Leaf)
		$file_is_migrating = $file_is_migrated -or (Test-Path -Path $file_path_migrating -PathType Leaf)
		$file_is_locked = $file_is_migrating -or (Test-Path -Path $file_path_locked -PathType Leaf)
		$file_is_fetched = $file_is_locked -or (Test-Path -Path $file_path_fetched -PathType Leaf)
		
		# Read users
		$file_path_current = $file_is_processed ? $file_path_processed : ($file_is_migrated ? $file_path_migrated : ($file_is_migrating ? $file_path_migrating : ($file_is_locked ? $file_path_locked : ($file_is_fetched ? $file_path_fetched :$file_path))))
		$users = [System.Collections.Generic.List[UserInfo]]((Read-Users-From-CSV $file_path_current) ?? @())
		$users_failed = [System.Collections.Generic.List[UserInfo]]((Read-Users-From-CSV $file_path_failed) ?? @())
		Log "Init current users ($($users.Count)) from file '$file_path_current'"
		
		# if the count is 0 continue to the next file
		if ($users.Count -eq 0) {
			Log "Warning: skipping current file due to users count = 0"
			continue
		}

		# $users_is_fetched = $false
		# if ($file_is_fetched) {
		# 	$users_fetched = Read-Users-From-CSV $file_path_fetched
		# 	$users_is_fetched = ($users.Count -eq $users_fetched.Count)
		# }
		
		# ==============================================================================================================================

		# Prepare user info
		if (!$file_is_fetched -and $users.Count -gt 0) {
			Log "Start fetching user information"

			# Group users by source tenant
			$users_groups = $users | Sort-Object SourceTenant | Group-Object -Property SourceTenant

			foreach ($users_group in $users_groups) {
				$tenant_name = $users_group.Name
				$tenant_users = $users_group.Group
				$tenant = Get-Tenant $tenant_name
		
				# Fecth users info by source
				Import-Users-Info $tenant $tenant_users $true
			}

			# Extract failed users
			$users | Where-Object { !$_.isMigratedFetched -or $null } | ForEach-Object { $users.Remove($_); $users_failed.Add($_); }
		
			# Save all users info
			Save-Users-To-CSV $users $file_path_fetched
			Save-Users-To-CSV $users_failed $file_path_failed

			Log "End fetching user information into file '$file_path_fetched'"
		} else {
			Log "Users information have been fetched before"
		}

		# ==============================================================================================================================

		# Lock users on source
		# Group users by source tenant
		if (!$file_is_locked -and $users.Count -gt 0) {
			Log "Start locking users"

			# $users = Read-Users-From-CSV $file_path_fetched
			$users_groups = $users | Where-Object { $_.isMigratedFetched -and $null -ne $_.SourceId -and $null -ne $_.isTeacher -and $null -ne $_.isStudent } | Sort-Object SourceTenant | Group-Object -Property SourceTenant

			foreach ($users_group in $users_groups) {
				$tenant_name = $users_group.Name
				$tenant_users = $users_group.Group
				$tenant = Get-Tenant $tenant_name

				# Add source users to mail-enabled security group
				Add-Users-To-SecurityGroup $tenant $tenant_users $security_group_name
			}

			# Extract failed users
			$users | Where-Object { !$_.isMigratedLocked } | ForEach-Object { $users.Remove($_); $users_failed.Add($_); }
			Save-Users-To-CSV $users_failed $file_path_failed
			if ($users.Count -eq 0) { continue }

			# User divided to two batches groups
			# because two way migration simultaneously not suppored
			$users_batch_1 = [System.Collections.Generic.List[UserInfo]](($users | Where-Object { $_.MigrationDirectionOrdered -eq $_.MigrationDirection }) ?? @())
			$users_batch_2 = [System.Collections.Generic.List[UserInfo]](($users | Where-Object { $_.MigrationDirectionOrdered -ne $_.MigrationDirection }) ?? @())

			# Optimization: move non-conflict batches from second run to first run.
			$users_batch_2 | Where-Object { $users_batch_1.MigrationDirectionOrdered -notcontains $_.MigrationDirectionOrdered } | ForEach-Object { $users_batch_2.Remove($_); $users_batch_1.Add($_); } | Out-Null

			# Update MigrationBatchNumber
			Log "Setting users MigrationBatchNumber"
			$users_batch_1 | ForEach-Object { $_.MigrationBatchNumber = "1" }
			$users_batch_2 | ForEach-Object { $_.MigrationBatchNumber = "2" }

			# Save mail-enabled security group migration status
			Save-Users-To-CSV $users $file_path_locked
			# Remove-Item $file_path_fetched 

			Log "End locking users"
		} else {
			Log "Users locking have been fetched before"
		}

		# ==============================================================================================================================

		if (!$file_is_migrated -and $users.Count -gt 0) {
			Log "Start migrating users"

			# $users = Read-Users-From-CSV $file_path_locked

			if ((Test-Path -Path $file_path_migrating_1 -PathType Leaf)) {
				$users_batch_1 = [System.Collections.Generic.List[UserInfo]](Read-Users-From-CSV $file_path_migrating_1) # Resume
				Log "Resume migration batch 1 users from file '$file_path_migrating_1'"
			} else {
				$users_batch_1 = ([System.Collections.Generic.List[UserInfo]]($users | Where-Object { $_.MigrationBatchNumber -eq "1" }))
			}
			if ((Test-Path -Path $file_path_migrating_2 -PathType Leaf)) {
				$users_batch_2 = [System.Collections.Generic.List[UserInfo]](Read-Users-From-CSV $file_path_migrating_2) # Resume
				Log "Resume migration batch 2 users from file '$file_path_migrating_2'"
			} else {
				$users_batch_2 = ([System.Collections.Generic.List[UserInfo]]($users | Where-Object { $_.MigrationBatchNumber -eq "2" }))
			}
			
			$users = [System.Collections.Generic.List[UserInfo]]($users_batch_1 + $users_batch_2)

			# Start migration batch 1
			Start-Migration-Batch $users $users_batch_1 $file_path 1

			# Extract failed users
			$users_batch_1 | Where-Object { !$_.isMigratedHasMailbox -or !$_.isMigratedMailBox -or !$_.isMigratedBatchStarted } | ForEach-Object { $users.Remove($_); $users_batch_1.Remove($_); $users_failed.Add($_); } | Out-Null
			Save-Users-To-CSV $users_failed $file_path_failed
			Save-Users-To-CSV $users_batch_1 $file_path_migrating_1
			if ($users.Count -eq 0) { continue }

			# Wait migration batch 1
			Wait-Migration-Batch $users $users_batch_1 $file_path 1

			# Extract failed users
			$users_batch_1 | Where-Object { !$_.isMigratedBatchSuccess } | ForEach-Object { $users.Remove($_); $users_batch_1.Remove($_); $users_failed.Add($_); } | Out-Null
			Save-Users-To-CSV $users_failed $file_path_failed
			Save-Users-To-CSV $users_batch_1 $file_path_migrating_1
			if ($users.Count -eq 0) { continue }

			# Start migration batch 2
			Start-Migration-Batch $users $users_batch_2 $file_path 2

			# Extract failed users
			$users_batch_2 | Where-Object { !$_.isMigratedHasMailbox -or !$_.isMigratedMailBox -or !$_.isMigratedBatchStarted } | ForEach-Object { $users.Remove($_); $users_batch_2.Remove($_); $users_failed.Add($_); } | Out-Null
			Save-Users-To-CSV $users_failed $file_path_failed
			Save-Users-To-CSV $users_batch_2 $file_path_migrating_2
			if ($users.Count -eq 0) { continue }

			# Wait migration batch 2
			Wait-Migration-Batch $users $users_batch_2 $file_path 2

			# Extract failed users
			$users_batch_2 | Where-Object { !$_.isMigratedBatchSuccess } | ForEach-Object { $users.Remove($_); $users_batch_2.Remove($_); $users_failed.Add($_); } | Out-Null
			Save-Users-To-CSV $users_failed $file_path_failed
			Save-Users-To-CSV $users_batch_2 $file_path_migrating_2
			if ($users.Count -eq 0) { continue }

			# 
			Save-Users-To-CSV $users $file_path_migrated
			
			Log "End migrating users"
		} else {
			Log "Migrating users already done"
		}

		# ==============================================================================================================================

		if (!$file_is_processed -and $users.Count -gt 0) {
			# $users = Read-Users-From-CSV $file_path_migrated
			Log "Dumping output processed files"

			Save-Users-To-CSV $users $file_path_processed

			Log "Dumping migrated users info to file '$file_path_processed_user_output'"
			$users | Select-Object TargetEmail,TargetPassword | Export-Csv -NoTypeInformation $file_path_processed_user_output
		} else {
			Log "Dumping output processed files already done"
		}

		Log "Failed users count = $($users_failed.Count)"
		if ($users_failed.Count -gt 0) {
			Log "Starting process of rolling back falied users"

			foreach ($user in $users_failed) {
				if ($user.isMigratedStatus) {
					
				}

				if ($user.isMigratedBatchStarted) {
					
				}

				if ($user.isMigratedBatchStarted) {
					
				}

				if ($user.isMigratedBatchStarted) {
					
				}

				if ($user.isMigratedBatchStarted) {
					
				}
			}


		} else {
			Log "No users to rollback"
		}

		Log "End current processing file '$($files_processing.FullName)'"

		$file_path_processing = $null

		Log "====================================================================`n`n"
	}
}

#============================================================================================================================================

function Start-Migration-Batch {
	param (
		[System.Collections.Generic.List[UserInfo]]$users,
		[System.Collections.Generic.List[UserInfo]]$users_batch,
		[string]$file_path,
		[string]$batch_number
	)
	if ($users.Count -eq 0 -or $users_batch.Count -eq 0) { return }

	Log "Start 'Start-Migration-Batch'"

	$file_name_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($file_path)
	$directory_today_processing_path = (Get-Item $file_path).DirectoryName

	$file_path_fetched = "$file_path.fetched"
	$file_path_locked = "$file_path.locked.$batch_number"
	$file_path_migrating = "$file_path.migrating.$batch_number"
	$file_path_migrated = "$file_path.migrated.$batch_number"
	$file_path_failed = "$file_path.failed.$batch_number"

	$file_is_migrated = (Test-Path -Path $file_path_migrated -PathType Leaf)
	$file_is_migrating = $file_is_migrated -or (Test-Path -Path $file_path_migrating -PathType Leaf)
	$file_is_locked = $file_is_migrating -or (Test-Path -Path $file_path_locked -PathType Leaf)
	$file_is_fetched = $file_is_locked -or (Test-Path -Path $file_path_fetched -PathType Leaf)
	
	# MailBox Migration
	# Group users by source & target tenants
	if (!$file_is_migrating) {
		Log "Start migrating users for batch number $batch_number"

		# $users_batch = Read-Users-From-CSV $file_path_locked
		$users_groups = $users_batch | Where-Object { !$_.isMigratedBatchStarted } | Sort-Object SourceTenant | Group-Object -Property SourceTenant,TargetTenant

		foreach ($users_group in $users_groups) {
			$tenant_names = $users_group.Name.Split(',').Trim()
			$tenant_source_name = $tenant_names[0]
			$tenant_target_name = $tenant_names[1]
			$tenant_source = Get-Tenant $tenant_source_name
			$tenant_target = Get-Tenant $tenant_target_name
			$tenant_users = $users_group.Group
			$migration_batch_name = "Migration-$($tenant_source.TenantTitle)-$($tenant_target.TenantTitle)-$file_name_no_ext"

			# Mailbox Migration
			New-Mailbox-Migration-Batch $tenant_source $tenant_target $tenant_users $migration_batch_name $directory_today_processing_path
		}
		
		# Save mailbox migration status
		Save-Users-To-CSV $users_batch $file_path_migrating
		# Remove-Item $file_path_locked
		# Rename-Item -Path $file_path_locked -NewName $file_path_migrating
		# Move-Item -Path $file_path_locked -Destination $file_path_migrating
	} else {
		Log "Migrating users for batch number $batch_number was done before"
	}

	Log "End 'Start-Migration-Batch'"
}

#============================================================================================================================================

function Wait-Migration-Batch {
	param (
		[System.Collections.Generic.List[UserInfo]]$users,
		[System.Collections.Generic.List[UserInfo]]$users_batch,
		[string]$file_path,
		[string]$batch_number
	)
	if ($users.Count -eq 0 -or $users_batch.Count -eq 0) { return }
	
	Log "Start 'Wait-Migration-Batch'"

	$file_name_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($file_path)

	$file_path_fetched = "$file_path.fetched"
	$file_path_locked = "$file_path.locked.$batch_number"
	$file_path_migrating = "$file_path.migrating.$batch_number"
	$file_path_migrated = "$file_path.migrated.$batch_number"
	$file_path_failed = "$file_path.failed"

	$file_is_migrated = (Test-Path -Path $file_path_migrated -PathType Leaf)
	$file_is_migrating = $file_is_migrated -or (Test-Path -Path $file_path_migrating -PathType Leaf)
	$file_is_locked = $file_is_migrating -or (Test-Path -Path $file_path_locked -PathType Leaf)
	$file_is_fetched = $file_is_locked -or (Test-Path -Path $file_path_fetched -PathType Leaf)
	
	# Migration
	if (!$file_is_migrated) {
		Log "Watching migration batches statuses for users batch number $batch_number"

		# $users_batch = Read-Users-From-CSV $file_path_migrating
		$users_groups = $users_batch | Where-Object { $_.isMigratedBatchStarted -and !$_.isMigratedBatchSuccess } | Sort-Object MigrationBatchName | Group-Object -Property MigrationBatchName

		$migrations_batches_finished = @()

		do {
			foreach ($users_group in $users_groups) {
				$migration_batch_name = $users_group.Name
				$migration_batch_users = $users_group.Group

				if ($migrations_batches_finished -contains $migration_batch_name) { continue }
				
				$tenant_name = $users_batch[0].TargetTenant
				$tenant = Get-Tenant $tenant_name

				Connect-ExchangeOnline-Custom $tenant

				try {
					Log "Getting migration batch status '$migration_batch_name' from target tenant '$tenant_name'"
					# https://www.easy365manager.com/exchange-migration-batch-percentage-progress/
					# https://learn.microsoft.com/en-us/powershell/module/exchange/get-migrationbatch?view=exchange-ps
					# https://learn.microsoft.com/en-us/previous-versions/office/exchange-server-api/jj956046(v=exchg.150)
					# Get-MigrationUser -BatchId "E365M Batch" | Get-MigrationUserStatistics | Format-Table Identity,@{Label="TotalItems";Expression={$_.TotalItemsInSourceMailboxCount}},@{Label="SyncedItems";Expression={$_.SyncedItemCount}},@{Label="Completion";Expression={ $_.SyncedItemCount / $_.TotalItemsInSourceMailboxCount}; FormatString="P"}
					$migration_batch = Get-MigrationBatch -Identity $migration_batch_name -ErrorAction Stop	
					# Get-MigrationUser -BatchId "Migration-dev2-dev1-users-2022-12-26-23-10-45" -ResultSize Unlimited
					# Get-MoveRequestStatistics -Identity "test_student_2@dev1.rb.moe.gov.sa"
				}
				catch {
					# switch -wildcard ($_.Exception.Message) {
					# 	# Get-MigrationBatch: ExBDDC58|Microsoft.Exchange.Configuration.Tasks.ManagementObjectNotFoundException|The migration batch "Migration-dev1-dev2-users-2022-12-26-21-15-36" can't be found.
					# 	# "*Microsoft.Exchange.Configuration.Tasks.ManagementObjectNotFoundException*" { $migrations_batches_finished += $migration_batch_name; continue; }
					# 	Default { $migrations_batches_finished += $migration_batch_name; continue; }
					# }
					$migrations_batches_finished += $migration_batch_name
					Log-Error "Getting migration batch status '$migration_batch_name' at target tenant '$tenant_name' failed, skip listening to this batch in this iteration, exception = '$($_.Exception.Message)'"
					continue
				}
				
				Log "migration batch '$migration_batch_name' status = '$($migration_batch.Status.Value)' at target tenant '$tenant_name'"
				switch ($migration_batch.Status.Value) {
					"Completed" {
						Start-Migration-Completed $file_path_migrating $migration_batch $migration_batch_users $users_batch
						$migrations_batches_finished += $migration_batch_name
					}
					"CompletedWithErrors" {
						Start-Migration-Failed $file_path_migrating $migration_batch $migration_batch_users $users_batch
						$migrations_batches_finished += $migration_batch_name
					}
					"Completing" { }
					"Corrupted" {
						Start-Migration-Failed $file_path_migrating $migration_batch $migration_batch_users $users_batch
						$migrations_batches_finished += $migration_batch_name
					}
					"Created" { }
					"Failed" {
						Start-Migration-Failed $file_path_migrating $migration_batch $migration_batch_users $users_batch
						$migrations_batches_finished += $migration_batch_name
					}
					"IncrementalSyncing" { }
					"Removing" { }
					"Starting" { }
					"Stopped" { }
					"Syncing" {
						# Start-Migration-Syncing $file_path_migrating $migration_batch $migration_batch_users $users_batch
					}
					"Stopping" { }
					"Synced" {
						Log "Completing migration batch '$migration_batch_name' at target tenant '$tenant_name'"
						Complete-MigrationBatch -Identity $migration_batch_name -Confirm:$false
					}
					"SyncedwithErrors" {
						Start-Migration-Failed $file_path_migrating $migration_batch $migration_batch_users $users_batch
						$migrations_batches_finished += $migration_batch_name
					}
					"Waiting" { }
					Default { }
				}
	
				Log "Sleeping for 1000 Milliseconds"
				Start-Sleep -Milliseconds 1000
			}
		} until ($migrations_batches_finished.Length -eq $users_groups.Length)
	} else {
		Log "Watching migration batches statuses for users batch number $batch_number was done before"
	}

	Log "End 'Wait-Migration-Batch'"
}

#============================================================================================================================================

function Start-Migration-Completed {
	param (
		[string]$file_path,
		$migration_batch,
		[System.Collections.Generic.List[UserInfo]]$migration_batch_users,
		[System.Collections.Generic.List[UserInfo]]$users_batch 
	)
	if ($migration_batch_users.Length -eq 0 -or $users_batch.Length -eq 0) { return }

	Log "Start 'Start-Migration-Completed'"

	$migration_batch_name = $migration_batch.Identity.Name
	$tenant_source_name = $migration_batch_users[0].SourceTenant
	$tenant_target_name = $migration_batch_users[0].TargetTenant
	$tenant_source = Get-Tenant $tenant_source_name
	$tenant_target = Get-Tenant $tenant_target_name
	$file_path_migrating = $file_path

	# Set user as migrated
	foreach ($user in $migration_batch_users) {
		Log "Setting user '$($user.Name)' as isMigratedBatchSuccess = true"
		$user.isMigratedBatchSuccess = $true
	}

	# Save users
	Save-Users-To-CSV $users_batch $file_path_migrating
	
	# ==============================================================================================================================

	# TargetId
	$migration_batch_users_filtered = [System.Collections.Generic.List[UserInfo]]($migration_batch_users | Where-Object { $null -eq $_.TargetId -or "" -eq $_.TargetId })
	if ($migration_batch_users_filtered.Length -gt 0) {
		Log "Fetching migrated users ids"

		# Fecth user info (TargetId)
		Import-Users-Info $tenant_target $migration_batch_users_filtered $false
		
		# Save users
		Save-Users-To-CSV $users_batch $file_path_migrating
	} else {
		Log "Fetching migrated users ids was done before"
	}
	
	# ==============================================================================================================================

	# Groups
	$migration_batch_users_filtered = [System.Collections.Generic.List[UserInfo]]($migration_batch_users | Where-Object { !$_.isMigratedGroups })
	if ($migration_batch_users_filtered.Length -gt 0) {
		Log "Assigning migrated users to groups"

		# Groups
		Add-Users-To-Groups $tenant_target $migration_batch_users_filtered
		
		# Save users
		Save-Users-To-CSV $users_batch $file_path_migrating
	} else {
		Log "Assigning migrated users to groups was done before"
	}

	# ==============================================================================================================================

	# # Licenses
	# $migration_batch_users_filtered = [System.Collections.Generic.List[UserInfo]]($migration_batch_users | Where-Object { !$_.isMigratedLicenses })
	# if ($migration_batch_users_filtered.Length -gt 0) {
	# 	Log "Assigning migrated users licenses"

	# 	# Licenses
	# 	Add-Licenses-To-Users $tenant_target $migration_batch_users
			
	# 	# Save users
	# 	Save-Users-To-CSV $users_batch $file_path_migrating
	# } else {
	# 	Log "Assigning migrated users licenses was done before"
	# }

	# ==============================================================================================================================

	$migration_batch_users_filtered = [System.Collections.Generic.List[UserInfo]]($migration_batch_users | Where-Object { !$_.isMigratedStatus })
	if ($migration_batch_users_filtered.Length -gt 0) {
		Log "Disabling migrated users"

		# Disable Users
		Disable-Users $tenant_source $migration_batch_users
			
		# Save users
		Save-Users-To-CSV $users_batch $file_path_migrating
	} else {
		Log "Disabling migrated users was done before"
	}

	Log "End 'Start-Migration-Completed'"
}

#============================================================================================================================================

function Start-Migration-Failed {
	param (
		[string]$file_path,
		[Microsoft.Exchange.Migration.MigrationBatch]$migration_batch,
		[System.Collections.Generic.List[UserInfo]]$migration_batch_users,
		[System.Collections.Generic.List[UserInfo]]$users
	)

	$migration_batch | Out-File -FilePath "$file_path.log" -Append
}

#============================================================================================================================================

function Start-Migration-Syncing {
	param (
		[string]$file_path,
		[Microsoft.Exchange.Migration.MigrationBatch]$migration_batch,
		[System.Collections.Generic.List[UserInfo]]$migration_batch_users,
		[System.Collections.Generic.List[UserInfo]]$users
	)

	$migration_batch_name = $migration_batch.Identity.Name
	$migration_batch_id = $migration_batch.Identity

	$migration_users_statuses = Get-MigrationUser -BatchId $migration_batch_id
	if ($null -eq $migration_users_statuses) { return }

	foreach ($migration_user_status in $migration_users_statuses) {
		$migration_user_name = ($migration_user_status.Identity).Split("@")[0]

		# TODO: Change user migration status
	}
}

#============================================================================================================================================

Main
