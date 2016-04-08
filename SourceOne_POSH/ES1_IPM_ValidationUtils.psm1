######################################################################################
#  Copyright (c) EMC Corporation.  All rights reserved.
#  
# THIS SAMPLE CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
# CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 
#
######################################################################################
#requires -Version 2
#######################################
#
function Compare-ES1ToEXRoutes {
<#
.SYNOPSIS
Given a 4x format message ID, retrieve and compare the routes between EmailXtender and SourceOne

.DESCRIPTION
Given a 4x format message ID, retrieve and compare the routes between EmailXtender and SourceOne

.PARAMETER MsgId
4x format message ID

.PARAMETER ES1SQLSERVER
SourceOne IPM Native archive SQL server (and instance if applicable)
.PARAMETER ES1Database
SourceOne IPM Native archive database
.PARAMETER EXSQLSERVER
EmailXtender SQL server
.PARAMETER ExDatabase
EmailXtender database name


.EXAMPLE
Compare-ES1ToEXRoutes -msgid 42C4DB1AEB7EC77E658A5CAF -es1sql DBACL20SQL2\es1_ex -es1arDB ES1InplaceArchive -exsql EXSQL -exardb EmailXtender

#>
[CmdletBinding()]

Param([string][parameter(Mandatory = 1,HelpMessage='EX Format Message ID')][Alias('id')]$MsgId="",
        [Parameter(Mandatory=$True,HelpMessage='S1 SQL server name.  Include instance if needed')]
        [Alias('es1sql')]
        [string]$ES1SQLSERVER="",
        [Parameter(Mandatory=$True,HelpMessage='S1 IPM Archive database name')]
        [Alias('es1arDB')]
        [string] $ES1Database="ES1IPMArchive",
        [Parameter(Mandatory=$True,HelpMessage='EX SQL server name.  Include instance if needed')]
        [Alias('exsql')]
        [string]$EXSQLSERVER="",
        [Parameter(Mandatory=$False,HelpMessage='EX database name')]
        [Alias('exarDB')]
        [string] $ExDatabase="EmailXtender" )
 

BEGIN {

}
PROCESS {



try {

    $bRet = $True

    $excontent = @()
    $excontent = @(Get-ExRoutes -msgid $MsgId -exsql $ExSqlServer -exardb $ExDatabase )
    [int] $exCount = $excontent.length
    
    
    $es1content = @()    
    $es1content = @(Get-ES1Routes -msgid $MsgId -es1sql $Es1SqlServer -es1arDB $Es1Database )
    [int] $es1Count = $es1content.length


#    if ($es1Count -ne $exCount)
#   {
       
#         if ($es1Count -lt $exCount)
         #{
           $missingEX=$true
#         }
         
         # Sort the lists
         $excontent =@($excontent | sort-object -property Emailaddress )

         $es1content=@($es1content | sort-object -property Emailaddress,FolderId )
         
             
         if ($missingEX -eq $true)
         
         {
            $missingRoutes=@()
            foreach ($route in $excontent)
            {
                $foundRoute=$false
                
                foreach ($s1route in $es1content)
                {
                    if ($route.EmailID -eq $s1route.EmailID)
                    {
                        $foundRoute=$true
                       # $route.EmailID
                       break
                    }
                }
               
                if($foundRoute)
                {
                   # Write-host 'Found Route:' $route.EmailID ',' $route.EmailAddress
                }
                else
                {
                    $missingRoutes+= $route
             
                    # Write-host 'S1 Missing Route: ' -foregroundcolor red     
                     #$route | format-table -autosize -wrap -Property $IDFormat,RouteTypeDesc, RouteTypeID,Emailaddress 
                     #Write-host -object $route -foregroundcolor red     
                }
                
            }
             
         }

         
  #  }
}

catch {
            Write-Output ""
            Write-Host "Unexpected Exception !! " -foregroundcolor red
            Write-output ""
            Write-Error $_
            return $FALSE
        
 }
 
 if ($missingRoutes.length -gt 0)         
 {
     $bRet = $False
  }
        
   return $bRet,$excontent, $es1content, $missingRoutes
}
END {}
}



#############################################
#
function Get-ExRoutes {
<#
.SYNOPSIS
Given a 4x format message ID, retrieve EmailXtender routes

.DESCRIPTION
Given a 4x format message ID, retrieve EmailXtender routes

.PARAMETER MsgId
4x format message ID

.PARAMETER EXSQLSERVER
EmailXtender SQL server
.PARAMETER ExDatabase
EmailXtender database name

#>

[CmdletBinding()]
Param([string][parameter(Mandatory = 1,HelpMessage='EX Format Message ID')][Alias('id')][string]$MsgId="",
       
        [Parameter(Mandatory=$True,HelpMessage='EX SQL server name.  Include instance if needed')]
        [Alias('exsql')]
        [string]$EXSQLSERVER="",
        [Parameter(Mandatory=$False,HelpMessage='EX database name')]
        [Alias('exarDB')]
        [string] $ExDatabase="EmailXtender" )

$excontent = @()

try {
    
    # Parse the date off the ID
    $ExDate = [Convert]::ToInt32($MsgId.Substring(0,8),16)

    # Parse the message ID hash
    $ExID=[Convert]::ToInt64($MsgId.Substring(8),16)

    #
    # Transform to a SourceOne comapatible ID
    $Es1MsgID= (("0" * (40- $MsgId.length )) + $MsgId) +"01"


    # Format string for displaying EmailID as hex
    $IDFormat = @{Label="EmailID";Expression={$_.EmailID};FormatString="X"}
    
    # EmailXtender Query to get route for a given message ID
    $ExSqlText = "SELECT     EmailAddress.EmailKey as EmailID, EmailAddress.Emailaddress,RouteTypeId,
     RouteDesc = case RouteTypeId
     when '0' then 'All'
     when '1' then 'To'
     when '2' then 'From'
     when '4' then 'CC'
     when '8' then 'BCC'
     when '16' then 'DL'
     when '32' then 'Discovered'
     when '64' then 'Routable'     
     END
    FROM        [EmailAddress] with (NOLOCK), Message with (NOLOCK), Route with (NOLOCK)
    WHERE       EmailAddress.EmailId = Route.Emailid
    AND         Message.MD5HashKey = Route.MD5HashKey
    AND         Message.MD5hashkey = $ExID
    AND         Message.TimeStamp = $ExDate"


    $excontent = @()
    $excontent = @(Invoke-ES1SQLQuery $ExSqlServer $ExDatabase $ExSqlText )
 }
 catch {
            Write-Output ""
            Write-Host "Unexpected Exception !! " -foregroundcolor red
            Write-output ""
            Write-Error $_
          
        
 }
  
    $excontent


}
######################################
#
function Get-ES1Routes {
<#
.SYNOPSIS
Given a 4x format message ID, retrieve SourceOne routes

.DESCRIPTION
Given a 4x format message ID, retrieve SourceOne routes

.PARAMETER MsgId
4x format message ID

.PARAMETER ES1SQLSERVER
SourceOne IPM Native archive SQL server (and instance if applicable)
.PARAMETER ES1Database
SourceOne IPM Native archive database

.EXAMPLE

#>
[CmdletBinding()]
Param([string][parameter(Mandatory = 1,HelpMessage='EX Format Message ID')][Alias('id')]$MsgId="",
        [Parameter(Mandatory=$True,HelpMessage='S1 SQL server name.  Include instance if needed')]
        [Alias('es1sql')]
        [string]$ES1SQLSERVER="",
        [Parameter(Mandatory=$True,HelpMessage='S1 IPM Archive database name')]
        [Alias('es1arDB')]
        [string] $ES1Database="ES1IPMArchive" )

$es1content = @()

try {
    
    # Parse the date off the ID
    $ExDate = [Convert]::ToInt32($MsgId.Substring(0,8),16)

    # Parse the message ID hash
    $ExID=[Convert]::ToInt64($MsgId.Substring(8),16)

    #
    # Transform to a SourceOne comapatible ID
    $Es1MsgID= (("0" * (40- $MsgId.length )) + $MsgId) +"01"


    # Format string for displaying EmailID as hex
    $IDFormat = @{Label="EmailID";Expression={$_.EmailID};FormatString="X"}
    
    # SourceOne Query to get route for a given message ID
    $Es1SqlText = "SELECT      EmailAddress.EmailId, EmailAddress.Emailaddress, RouteType ,
        RouteDesc = case RouteType
        when '0' then 'All'
        when '1' then 'To'
        when '2' then 'From'
        when '3' then 'CC'
        when '4' then 'BCC'
        when '5' then 'DL'
        when '6' then 'Disc/Routable'  
        END,
        RouteMask,Folderid
    FROM        [EmailAddress] with (NOLOCK), Message with (NOLOCK), Route with (NOLOCK)
    WHERE       EmailAddress.EmailId = Route.Emailid
    AND         Message.MessageID = Route.MessageID
    AND         CAST(Message.MessageID as varbinary) =0x$Es1MsgID"


    $es1content = @()
    $es1content = @(Invoke-ES1SQLQuery $Es1SqlServer $Es1Database $Es1SqlText )


 }
 catch {
            Write-Output ""
            Write-Host "Unexpected Exception !! " -foregroundcolor red
            Write-output ""
            Write-Error $_
          
        
 }
  
 $es1content


}



################
New-Alias ES1CompareRoutes Compare-ES1ToEXRoutes 

#
#   Public Exports
#
Export-ModuleMember -function Compare-ES1ToEXRoutes 
Export-ModuleMember -alias ES1CompareRoutes

Export-ModuleMember -function    Get-ES1Routes
Export-ModuleMember -function    Get-ExRoutes
