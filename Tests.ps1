



 # Loop through the server list
 Get-Content "ServerList.txt" | ForEach-Object {

    # Define what each job does
    $ScriptBlock = {
        param($pipelinePassIn) 
        Test-Path "\\$pipelinePassIn\c`$\Something"
        Start-Sleep 60
    }

    # Execute the jobs in parallel
    Start-Job $ScriptBlock -ArgumentList $_
}

Get-Job

# Wait for it all to complete
While (Get-Job -State "Running")
{
    Start-Sleep 10
}

# Getting the information back from the jobs
Get-Job | Receive-Job






$status = Get-MigrationBatch -Identity $migration_batch_name
$status.Status.Value -ne "Syncing"


# Loop through the server list
Get-Content "ServerList.txt" | ForEach-Object {

    # Define what each job does
    $ScriptBlock = {
        param($pipelinePassIn) 
        Test-Path "\\$pipelinePassIn\c`$\Something"
        Start-Sleep 60
    }

    # Execute the jobs in parallel
    Start-Job $ScriptBlock -ArgumentList $_
    # Start-Job -FilePath C:\Scripts\Sample.ps1
}

Get-Job

# Wait for it all to complete
While (Get-Job -State "Running")
{
    Start-Sleep 10
}

# Getting the information back from the jobs
Get-Job | Receive-Job

# do 
# {
# 	$stat = Get-MigrationBatch -Identity $migration_batch_name
# 	Start-Sleep -Milliseconds 600
# } until ($stat.Status.Value -ne "Syncing")
# Complete-MigrationBatch -Identity $migration_batch_name