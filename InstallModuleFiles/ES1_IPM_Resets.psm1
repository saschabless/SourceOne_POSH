<#	
	.NOTES
	===========================================================================
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_IPM_Resets.psm1
	
	Copyright (c) EMC Corporation.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		EMC SourceOne IPM functions for resetting various database items

#>

#requires -Version 2


$global:SQLVolValReset = "update archiveDB.[dbo].[ipmVolumeVerify] set Status=1
                          where Level=INLEVEL and TaskId=
                          (select TaskId from [archiveDB].[dbo].[ipmTask] where Name='INTASKNAME')"

$global:SQLIndexValReset = "update [archiveDB].[dbo].[ipmVolumeVerify] set Status=1
                          where Level=3 and TaskId=
                          (select TaskId from [archiveDB].[dbo].[ipmTask] where Name='INTASKNAME')"
                          
$global:SQLVolMigReset = "update [archiveDB].[dbo].[ipmVolume] set Status=1, ItemCount=0,ExceptionCount=0,MSGExceptions=''
                          where TaskId=
                          (select TaskId from [archiveDB].[dbo].[ipmTask] where Name='INTASKNAME')"                          
 
 $global:SQLVolReset = "update [archiveDB].[dbo].[ipmVolume] set Status=1, ItemCount=0,ExceptionCount=0,MSGExceptions=''
                          where VolumeName IN (VOLUMELIST)"
  
 $global:SQLTasksForRerun="select distinct tsk.TaskID,tsk.Name as TaskName from [archiveDB].[dbo].[ipmVolume]as vl 
                           join [archiveDB].[dbo].ipmTask as tsk on tsk.TaskID=vl.TaskID
                           where Volumename IN (VOLUMELIST) "
 
 
 ################################
function Reset-IPMTask {
<#
.SYNOPSIS
Resets the migration status of volumes in task
.DESCRIPTION
Resets the migration status of volumes in task,so migration can be run again.
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER taskName
The migration task Name.  The name should be unique for all servers.

.EXAMPLE
Reset-IPMTask -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -task "all 2009"

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$True)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('arDB')]
        [string] $archiveDB="ES1Archive",
        [Parameter(Mandatory=$True)]
        [Alias('task')]
        [string] $taskName="" )


BEGIN {

}
PROCESS {
    Write-Verbose "Reset-IPMTask "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$archiveDB`" "
    
    # substitute the input params...
    $SQLCommand=$global:SQLVolMigReset.replace("archiveDB",$archiveDB)
    $SQLCommand=$SQLCommand.replace("INTASKNAME",$taskName)
    
   
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
            
            $updateCnt = @(Invoke-ES1SQLNonQuery $sqlserver $archiveDB $SQLCommand)
          
              if ($updateCnt -gt 0)
              {
                Write-Host "Sucessfully reset $updateCnt Volumes for migration in task `"$taskName`" " -foregroundcolor green
              
              }
              else
              {
                Write-Host "No Volumes found to reset in task `"$taskName`" " -foregroundcolor red
                
              }
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Exception excuting SQL Query" -foregroundcolor red
            Write-Verbose $SQLCommand
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}

#####################################################

function Reset-IPMVolume {
<#
.SYNOPSIS
Resets the migration status of individual volumes
.DESCRIPTION
Resets the migration status of individual volumes in a task,so migration can be run again.
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER volList
Full Path and filename of the a text file containing the list of volumes to be reset.  The file should contain one volume name per line in the file.

.EXAMPLE
Reset-IPMVolume -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -vols c:\temp\volumes.txt

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$True)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('arDB')]
        [string] $archiveDB="ES1Archive",
        [Parameter(Mandatory=$True)]
        [Alias('vols')]
        [string] $volList="" )


BEGIN {

}
PROCESS {
    Write-Verbose "Reset-IPMVolume "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$archiveDB`" "
    
   
    $tasksToReRun=@();
    
        try {
            #  read volume names from the file and format them for the SQL query.
            $SQLVolList=""
            $volumes = @(get-content $volList)
            [int] $numVols=$volumes.length

            foreach ($volume in $volumes)
            {
                $vol=$volume.Trim()
                $SQLVolList+="'" + $vol + "'"
                if ($volume -ne $volumes[$numVols-1])
                {
                    $SQLVolList +=","
                }
            }
        
            # substitute the input params...
            $SQLUPDCommand=$global:SQLVolReset.replace("archiveDB",$archiveDB)
            $SQLUPDCommand=$SQLUPDCommand.replace("VOLUMELIST",$SQLVolList)
            
            $SQLCommand=$global:SQLTasksForRerun.replace("archiveDB",$archiveDB)
            $SQLCommand=$SQLCommand.replace("VOLUMELIST",$SQLVolList)
            
            Write-Debug $SQLCommand
           
            Write-Verbose "Executing SQL Query...."
        
            $tasksToReRun= @(Invoke-ES1SQLQuery $sqlserver $archiveDB $SQLCommand)
            [int] $tasksCount = $tasksToReRun.length
            if ( $tasksCount -gt 0 )
            {
                Write-Host "The following task will need to be rerun"
                $tasksToReRun | format-table
            }
            else
            {
                Write-Host "The tasks for the specified volumes could not be found" -foregroundcolor red
            }
            
            $updateCnt = @(Invoke-ES1SQLNonQuery $sqlserver $archiveDB $SQLUPDCommand)
          
              if ($updateCnt -gt 0)
              {
                Write-Host "Sucessfully reset $updateCnt Volumes  " -foregroundcolor green
              
              }
              else
              {
                Write-Host "No Volumes found to reset " -foregroundcolor red
                
              }
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Exception excuting SQL Query" -foregroundcolor red
            Write-Verbose $SQLCommand
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}
#
#
#
function Reset-IPMValidationIndex {
<#
.SYNOPSIS
Resets the index validation status so validation can be run again
.DESCRIPTION
Resets the index validation status so validation can be run again.
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER taskName
The migration task Name.  The name should be unique for all servers.

.EXAMPLE
Reset-IPMValidationIndex -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -task "all 2009"

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$True)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('arDB')]
        [string] $archiveDB="ES1Archive",
        [Parameter(Mandatory=$True)]
        [Alias('task')]
        [string] $taskName="" )


BEGIN {

}
PROCESS {
    Write-Verbose "Reset-IPMValidationIndex "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$archiveDB`" "
    
    # substitute the input params...
    $SQLCommand=$global:SQLIndexValReset.replace("archiveDB",$archiveDB)
    $SQLCommand=$SQLCommand.replace("INTASKNAME",$taskName)
    
   
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
            
            $updateCnt = @(Invoke-ES1SQLNonQuery $sqlserver $archiveDB $SQLCommand)
          
              if ($updateCnt -gt 0)
              {
                Write-Host "Sucessfully reset $updateCnt Indexes for revalidation in task `"$taskName`" " -foregroundcolor green
              
              }
              else
              {
                Write-Host "No Indexes found to reset in task `"$taskName`" " -foregroundcolor red
                Write-Host "You can only reset the validation state if you previously ran a validation" -foregroundcolor red
              }
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Exception excuting SQL Query" -foregroundcolor red
            Write-Verbose $SQLCommand
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}


###########################################################

function Reset-IPMValidationVolume {
<#
.SYNOPSIS
Resets the volume validation status so validation can be run again
.DESCRIPTION
Resets the volume validation status for a particular validation level,so validation can be run again.
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER taskName
The migration task Name.  The name should be unique for all servers.
.PARAMETER level
The validation level(1,2,3) that should be reset
.EXAMPLE
Reset-IPMValidationVolume -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -task "all 2009" -level 1

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$True)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('arDB')]
        [string] $archiveDB="ES1Archive",
        [Parameter(Mandatory=$True)]
        [Alias('task')]
        [string] $taskName="" ,
        [Parameter(Mandatory=$True)]
        [Alias('l')]
        [string] $level=""  ) 
     


BEGIN {

}
PROCESS {
    Write-Verbose "Reset-IPMValidationVolume "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$archiveDB`" "
    
    # substitute the input params...
    $SQLCommand=$global:SQLVolValReset.replace("archiveDB",$archiveDB)
    $SQLCommand=$SQLCommand.replace("INTASKNAME",$taskName)
    $SQLCommand=$SQLCommand.replace("INLEVEL",$level)
 
   
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
            
            $updateCnt = @(Invoke-ES1SQLNonQuery $sqlserver $archiveDB $SQLCommand)
          
              if ($updateCnt -gt 0)
              {
                Write-Host "Sucessfully reset Level $level validation on $updateCnt Volumes for revalidation in task `"$taskName`" " -foregroundcolor green
              
              }
              else
              {
                Write-Host "No Volumes found at Level $level to reset in task `"$taskName`" " -foregroundcolor red
                Write-Host "You can only reset the validation state if you previously ran a validation" -foregroundcolor red
              }
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Exception excuting SQL Query" -foregroundcolor red
            Write-Verbose $SQLCommand
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}

New-Alias IPMVolValReset    Reset-IPMValidationVolume
New-Alias IPMIdxValReset    Reset-IPMValidationIndex
New-Alias IPMReset          Reset-IPMTask
New-Alias IPMVolumeReset    Reset-IPMVolume

Export-ModuleMember -Function * -Alias *
