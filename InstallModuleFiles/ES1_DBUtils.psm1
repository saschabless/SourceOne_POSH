<#	
	.NOTES
	===========================================================================
	 Created on:   	8/21/2014 1:35 PM
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_DBUtils.psm1
	
	Copyright (c) EMC Corporation.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		EMC SourceOne direct database access utility functions

#>

#requires -Version 2

function Get-ES1ArchiveDatabases
{
<#
.SYNOPSIS
Gets the list of archive databases and their SQL servers

.DESCRIPTION
Gets the list of archive databases and their SQL servers
.PARAMETER sqlserver
Specifies the Name of the SQL server hosting the SourceOne Activity database. Should contain the SQL instance if needed as well.
.PARAMETER activityDB
The Name of the Activity database. The default is "ES1Activity".

.EXAMPLE
Get-ES1ArchiveDatabases

#>
[CmdletBinding()]
param
(
	[Parameter(Position=0,Mandatory=$false)]
	[string] $activityDbServer,

	[Parameter(Position=1,Mandatory=$false)]
	[string] $activityDb
)

begin {

}

process
{
	if (! $activityDbServer -or ! $activityDb)
	{
		#-------------------------------------------------------------------------------
		# Get Activity Database
		#-------------------------------------------------------------------------------
		$activityData = Get-ES1ActivityDatabase
		$activityDbServer = $activityData[0]
		$activityDb = $activityData[1]

	}
	#-------------------------------------------------------------------------------
	# Get Archive Databases
	#-------------------------------------------------------------------------------
	$sqlQuery = @'
    Select Name AS Connection,
           xConfig.value('(/ExASProviderConfig/DBServer)[1]','nvarchar(max)') AS DBServer,
           xConfig.value('(/ExASProviderConfig/DBName)[1]','nvarchar(max)') AS DBName
    From ProviderConfig (nolock)
    Where ProviderTypeID <> 5 AND State = 1    
'@

	$archiveDBs = @(Invoke-ES1SQLQuery $activityDbServer $activityDb $sqlQuery)

	$archiveDBs

}

end {}
}



function Test-IsOnS1Master
{
<#
.SYNOPSIS
Determines if running on the S1 Master machine

.DESCRIPTION
Determines if running on the S1 Master machine


.EXAMPLE
$onMaster = Test-IsOnS1Master
#>
[CmdletBinding()]
param()

begin {
	[bool] $IsMasterMachine = $false
}

process {
	try
	{
		if (Test-Path -Path HKLM:\SOFTWARE\Wow6432NodeEMC\SourceOne)
			{
				$MasterInstalled = Get-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\EMC\SourceOne\Versions -Name "Master+" -ErrorAction SilentlyContinue

			}
			else
			{
				$MasterInstalled = Get-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\EMC\SourceOne\Versions -Name "Master+" -ErrorAction SilentlyContinue 
			} 
		}
		catch
		{
			Write-Error $_

		}

		if ( $MasterInstalled )
		{
			$IsMasterMachine = $true
		}


		$IsMasterMachine
	}
	end {}


}

#
#-------------------------------------------------------------------------------
# Get Activity Database
# returns
#     [0] = activity DB Server
#     [1] = Activity DB Name
#-------------------------------------------------------------------------------

function Get-ES1ActivityDatabase 
{
	<#
.SYNOPSIS
Gets the SourceOne Activity database and SQL server name

.DESCRIPTION
Gets the SourceOne Activity database and SQL server name

.OUTPUTS
    [0] = Activity database server name
    [1] = Activity database name

.EXAMPLE
    Get-ES1ActivityDatabase
#>
	[CmdletBinding()]
	param ( )

	begin {}

	process {

		# 64 bit OS's now more prevelent try, the try the "WOW" node first
		try
		{
			if (Test-Path -Path HKLM:SOFTWARE\Wow6432Node\EMC\SourceOne)
			{
				$actDbServer = (Get-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\EMC\SourceOne).Server_JDF
				$actDb = (Get-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\EMC\SourceOne).DB_JDF
			}
			else
			{
				$actDbServer = (Get-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\EMC\SourceOne).Server_JDF
				$actDb = (Get-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\EMC\SourceOne).DB_JDF
			}

		}
		catch
		{
			Write-Error "Cannot locate SourceOne Registry settings on this machine !"

		}

		#Return db server and database name
		$actDbServer
		$actDb
	}

	end {}

}

#-------------------------------------------------------------------------------
# Get IPM Achive Databases
# returns
#     Array of objects with the folowing fields
#     DBServer, DBName,EnableMigrationDB, EnableMigrationArchive
#-------------------------------------------------------------------------------

function Get-ES1IPMArchiveDatabases {
	<#
.SYNOPSIS
		 Get-ES1IPMArchiveDatabases return a list of IPM Archive databases database servers and
         attributes about the IPM database

.DESCRIPTION
         Get-ES1IPMArchiveDatabases return a list of IPM Archive database objects with the following properties:
		 DBServer, DBName,EnableMigrationDB, EnableMigrationArchive

.PARAMETER  activityDbServer
		optional

.PARAMETER activityDb
		optional

.EXAMPLE
		Get-ES1IPMArchiveDatabases 


.OUTPUTS
		

#>
	[CmdletBinding()]
	param
	(
		[Parameter(Position = 0, Mandatory = $false)]
		[string] $activityDbServer,

		[Parameter(Position = 1, Mandatory = $false)]
		[string] $activityDb
	)

	begin {} 
	process {

		if (!$activityDbServer -or !$activityDb)
		{
			#-------------------------------------------------------------------------------
			# Get Activity Database
			#-------------------------------------------------------------------------------
			$activityData = Get-ES1ActivityDatabase
			$activityDbServer = $activityData[0]
			$activityDb = $activityData[1]

		}

		$dtConnections = Get-ES1ArchiveDatabases $activityDbServer $activityDb

		#-------------------------------------------------------------------------------
		# Query Archive Database IPM Settings
		#-------------------------------------------------------------------------------
		$IPMSqlQuery = @'
SELECT
	ConfigXML.value('(/ExAsCommonCfg/InPlaceMigrationOptions/EnableMigrationDB)[1]','int') AS EnableMigrationDB,
	ConfigXML.value('(/ExAsCommonCfg/InPlaceMigrationOptions/EnableMigrationArchive)[1]','int') AS EnableMigrationArchive
FROM ServerInfo (NOLOCK)
WHERE ServerName = 'ExAsCommon'
'@

		$cDatabases = @()
		foreach ($row in $dtConnections)
		{
			#$dtOutput.Reset()
			$dbname = $row.DBName
			$dbserver = $row.DBServer

			try
			{
				# get the
				$dtOutput = @(Invoke-ES1SQLQuery $dbserver $dbname $IPMSqlQuery)

			}
			catch
			{
				Write-Output ""
				Write-Host "Caught Exception " -foregroundcolor red

				Write-output ""
				Write-Error $_
			}

			foreach ($rec in $dtOutput)
			{
				# if its an migration archive db, add it to the list
				if ($rec.EnableMigrationArchive -eq 1)
				{
					$oDatabase = New-Object System.Object
					$oDatabase | Add-Member -MemberType NoteProperty -Name DBServer -value $dbserver
					$oDatabase | Add-Member -MemberType NoteProperty -Name DBName -value $dbname
					$oDatabase | Add-Member -MemberType NoteProperty -Name EnableMigrationDB -value $rec.EnableMigrationDB
					$oDatabase | Add-Member -MemberType NoteProperty -Name EnableMigrationArchive -value $rec.EnableMigrationArchive
					$cDatabases += $oDatabase
				}
				else
				{
					#  Not an IPM Archive DB
				}

			}
		}

		$cDatabases
	}
	end {}

}


function Get-IPMControllerDB {
	<#
	.SYNOPSIS
		 Get-IPMControllerDB  return the IPM controller database and server

	.DESCRIPTION
		Returns the IPM control and audit database and database server.

	.PARAMETER  activityDbServer
		optional

	.PARAMETER activityDb
		optional

	.EXAMPLE
		$IPMControll=Get-IPMControllerDB
        

	.OUTPUTS
        [0] = IPM Control DB Server name
        [1] = IPM Control DB name

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.
#>
	[CmdletBinding()]
	param(
		[Parameter(Position = 0, Mandatory = $false)]
		[string] $activityDbServer,

		[Parameter(Position = 1, Mandatory = $false)]
		[string] $activityDb
	)

	begin {

	}
	process {
		try
		{

			if (!$activityDbServer -or !$activityDb)
			{
				#-------------------------------------------------------------------------------
				# Get Activity Database
				#-------------------------------------------------------------------------------
				$activityData = Get-ES1ActivityDatabase
				$activityDbServer = $activityData[0]
				$activityDb = $activityData[1]

			}
			#-------------------------------------------------------------------------------
			# Get Archive Databases
			#-------------------------------------------------------------------------------

			$dtIPMDatabases = @(Get-ES1IPMArchiveDatabases $actDbServer $actDb)
			if ($dtIPMDatabases.Length -eq 0)
			{
				Throw 'No IPM Archive databases could be found'
			}

			#
			#  Which one is the IPM Control and Audit DB
			#
			foreach ($db in $dtIPMDatabases)
			{
				if ($db.EnableMigrationDB -eq 1)
				{
					# found it !
					$IPMControlServer = $db.DBServer
					$IPMControlDB = $db.DBName
					break
				}
			}

		}
		catch
		{
			Throw $_
		}

		$IPMControlServer
		$IPMControlDB
	}
	end {

	}
}


New-Alias ES1ActivityDB Get-ES1ActivityDatabase
New-Alias ES1IPMControlDB Get-IPMControllerDB
New-Alias ES1IPMDBs Get-ES1IPMArchiveDatabases
New-Alias ES1ArchiveDBs Get-ES1ArchiveDatabases
New-Alias OnS1Master Test-IsOnS1Master

#
#   Public Exports
#
Export-ModuleMember -Function * -Alias *

