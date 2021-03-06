<#	
	.NOTES
	===========================================================================
 
	Copyright © 2018 Dell Inc. or its subsidiaries. All Rights Reserved.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
	       http://www.apache.org/licenses/LICENSE-2.0
	===========================================================================
    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
    WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
 	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
 	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
 	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

.DESCRIPTION
		Convience wrappers for direct SQL access
#>



#####################################################################
#  Function Invoke-ES1SQLQuery:
#           Given a SQL Server and database, execute 
#            the query and return the result in table form
#
#####################################################################
function Invoke-ES1SQLQuery 
{      
<#
	.SYNOPSIS
		Given a SQL Server and database, execute the query and return the result in table form
	
	.DESCRIPTION
		Given a SQL Server and database, execute the query and return the result in table form

	.EXAMPLE
		
	
#>
[CmdletBinding()]
     Param
    (
        [Parameter(Position=0)]
        [string] $SqlServer,

        [Parameter(Position=1)]
        [string] $DbName,

        [Parameter(Position=2)]
        [string] $SqlQuery,

        [Parameter(Position=3)]
        [int] $SqlTimeOut = 300 # In Seconds -- 300 sec is 5 minutes
          
    )
BEGIN{}
PROCESS{
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString =  "Server=$SqlServer;Database=$DbName;Integrated Security=True"
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlQuery
    $SqlCmd.CommandTimeout = $SqlTimeOut  # In Seconds 
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    
    try {
        $itemCount = $SqlAdapter.Fill($DataSet) 
    }
    catch {
       
        throw $_
    }
    
    
    $SqlConnection.Close()

    #$DataSet.Tables[0] 

    return $DataSet.Tables[0]
	}

END{}

}

#####################################################################
#  Function Invoke-ES1SQLQueryParams:
#           Given a SQL Server and database, substitute input params,
#           execute the query and return the result in table form
#
#####################################################################
function Invoke-ES1SQLQueryParams 
{        param ($SQLServer, $Database, $SQLText, $parameters=@{})


    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString =  "Server=$SQLSERVER;Database=$DATABASE;Integrated Security=True"
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlText
    $SqlCmd.CommandTimeout = 600 # In Seconds 
    
    foreach($p in $parameters.Keys)
    {
        [Void] $SqlCmd.Parameters.AddWithValue("@$p",$parameters.Get_Item($p))
    }
    
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    
    try {
        $itemCount = $SqlAdapter.Fill($DataSet) 
    }
    catch {
       
        throw $_
    }
    
    
    $SqlConnection.Close()

    #$DataSet.Tables[0] 

    return $DataSet.Tables[0]

}



#
#  
#
Export-ModuleMember -function *
