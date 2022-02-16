
################################################
#
# CREATE WINDOWS TASK
#
################################################

 # Confirm you want a scheduled task
 $createTask = $Host.UI.PromptForChoice("Confirmation", "Do you want to create a scheduled task for the check and refreshment?", @('&Yes'; '&No'), 0)

 If ( $createTask -eq "0" ) {

    # Means yes and proceed
    Write-Log -message "Creating a scheduled task to check the token daily"

    # Default file
    $taskNameDefault = $settings.response.taskDefaultName

    # Replace task?
    $replaceTask = $Host.UI.PromptForChoice("Replace Task", "Do you want to replace the existing task if it exists?", @('&Yes'; '&No'), 0)

    If ( $replaceTask -eq 0 ) {
        
        # Check if the task already exists
        $matchingTasks = Get-ScheduledTask | where { $_.TaskName -eq $taskName }

        If ( $matchingTasks.count -ge 1 ) {
            Write-Log -message "Removing the previous scheduled task for recreation"
            # To replace the task, remove it without confirmation
            Unregister-ScheduledTask -TaskName $taskNameDefault -Confirm:$false
        }
        
        # Set the task name to default
        $taskName = $taskNameDefault

    } else {

        # Ask for task name or use default value
        $taskName  = Read-Host -Prompt "Which name should the task have? [$( $taskNameDefault )]"
        if ( $taskName -eq "" -or $null -eq $taskName) {
            $taskName = $taskNameDefault
        }

    }

    Write-Log -message "Using name '$( $taskName )' for the task"


    # TODO [ ] Find a reliable method for credentials testing
    # TODO [ ] Check if a user has BatchJobrights ##[System.Security.Principal.WindowsIdentity]::GrantUserLogonAsBatchJob

    # Enter username and password
    $taskCred = Get-Credential

    # Parameters for scheduled task
    $taskParams = [Hashtable]@{
        TaskPath = "\Apteco\"
        TaskName = $taskname
        Description = "Checks the Agnitas EMM connected SFTP Server for new response data to download, transform and match"
        Action = New-ScheduledTaskAction -Execute "$( $settings.powershellExePath )" -Argument "-ExecutionPolicy Bypass -File ""$( $scriptPath )\agnitas__99__FERGE.ps1"""
        #Principal = New-ScheduledTaskPrincipal -UserId $taskCred.Name -LogonType "ServiceAccount" # Using this one is always interactive mode and NOT running in the background
        Trigger = @(
            New-ScheduledTaskTrigger -at ([Datetime]::Today.AddDays(1).AddHours(6).AddMinutes(5)) -Daily # Starting tomorrow at 06:05 in the morning
            New-ScheduledTaskTrigger -at ([Datetime]::Today.AddDays(1).AddHours(12).AddMinutes(5)) -Daily # Starting tomorrow at 12:05 at lunchtime
            New-ScheduledTaskTrigger -at ([Datetime]::Today.AddDays(1).AddHours(18).AddMinutes(5)) -Daily # Starting tomorrow at 18:05 in the evening
        )
        Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances "Parallel" # Max runtime of 30 minutes
        User = $taskCred.UserName
        Password = $taskCred.GetNetworkCredential().Password
        #AsJob = $true
    }

    # Create the scheduled task
    try {
        Write-Log -message "Creating the scheduled task now"
        $newTask = Register-ScheduledTask @taskParams #T1 -InputObject $task
    } catch {
        Write-Log -message "Creation of task failed or is not completed, please check your scheduled tasks and try again"
        throw $_.Exception
    }

    # Check the scheduled task
    $task = $newTask #Get-ScheduledTask | where { $_.TaskName -eq $taskName }
    $taskInfo = $task | Get-ScheduledTaskInfo
    Write-Host "Task with name '$( $task.TaskName )' in '$( $task.TaskPath )' was created"
    Write-Host "Next run '$( $taskInfo.NextRunTime.ToLocalTime().ToString() )' local time"
    # The task will only be created if valid. Make sure it was created successfully

 } 

Write-Log -message "Done with settings creation"