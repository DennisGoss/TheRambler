<#
    .SYNOPSIS
        Utilizes the SharePoint Object Model to enumerate all SharePoint Workflows associated with webs and lists (2010 and 2013 if connected to Workflow Manager).
 
    .DESCRIPTION
        Will require permission to read the content within the web application(s) specified. 
        The Write-Log function allows for overriding the LogFile parameter and has a switch parameter to include the timestamp (disabled by default).

    .INPUTS
        None

    .OUTPUTS
        A comma delimited log file will be generated in the path specified that includes information about the Workflows and associated history lists.

    .EXAMPLE
        Specify a Few Static Variables (LogFolder, LogFile, Scope, ScopeUrl) and run the script with admin rights on a SharePoint server - content permission also required.
        FindWorkflowsAndHistoryLists.ps1

    .NOTES
        TAGS : SharePoint, Workflow
#>

#Static Variables
$LogFolder = "C:\Temp\Logs"
if(!(Test-Path -Path $LogFolder))
{
    Write-Host "The LogFolder specified $LogFolder does not exist"
    exit -1
}
$LogFile = $LogFolder + "\" + (Get-Date -UFormat "%Y%m%d") + "_FindWorkflows.log" #This can be overridden by the LogPath (named) parameter in the Write-Log function (FindWorkflows_$(Get-Date -Format yyyyMMdd_hhMMss).csv")
$scope = "WebApp" #Farm, WebApp or Site
$scopeUrl = "https://webappURL/" #this variable is only used if scope is not Farm
 
Function Write-Log
{
	param (
        [Parameter(Mandatory=$True)]
        [array]$LogOutput,
        [string]$LogPath = $Logfile, #utilizes LogFile specified above unless overridden
        [switch]$WithTime = $False
	)
	$currentDate = (Get-Date -UFormat "%Y%m%d")
	$currentTime = (Get-Date -UFormat "%T")+","
    if($WithTime)
    {
	    "$currentDate $currentTime $LogOutput" | Out-File $LogPath -Append
    }
    else
    {
        $LogOutput | Out-File $LogPath -Append
    }
}

Write-Log -LogOutput ("Begin Logging for FindWorkflows and History Lists: "+$PSCommandPath) -WithTime
$hdr = "WebTitle,WebURL,ListTitle,WFTitle,WFEnabled,WFVersion,WFRunningInstances,WFisDeclaritive,WFLastModified,WFAuthor,HistListTitle,HistListURL,HistListItemCount"
Write-Log -LogOutput ($hdr) -WithTime

Add-PSSnapin Microsoft.SharePoint.PowerShell -EA 0

$exclude = @("widesite","team","Nintex","war") #terms to match against in site collection and web Urls for exclusion

Function Get-WorkflowInfo 
{
	param (
        [Parameter(Mandatory=$True)]
        $sites
	)

    foreach($siteUrl in $sites)
    {
        if(!$null -ne ($exclude | ? { $siteUrl -match $_ }))
        {
            $site = Get-SPSite $siteUrl
            foreach($web in $site.AllWebs)
            {
                Write-Host "Checking"$web.Title"for workflows" -ForegroundColor Yellow
                Write-Host ""

                if(!$null -ne ($exclude | ? {$web.Url -match $_}))
                {
                    Write-Host "Checking for 2010 Site Workflows"
                    if($web.WorkflowAssociations.Count -gt 0)
                    {
                        Write-Host "2010 Site Workflow(s) found!"
                        foreach($wfa in $web.WorkflowAssociations | ? {$_.Name -notlike "*(*"})
                        {
                            $str = $web.Title+","+$web.Url+",SiteWorkflow,"+$wfa.Name+","+$wfa.Enabled+",2010,"+$wfa.RunningInstances+","+$wfa.IsDeclarative+","+$wfa.Modified+","+$web.SiteUsers.GetByID($wfa.Author).LoginName+","+$wfa.HistoryListTitle+","+($web.Site.WebApplication.Url).Trim('/')+$web.Lists[$wfa.HistoryListTitle].DefaultViewUrl+","+$web.Lists[$wfa.HistoryListTitle].ItemCount
                            Write-Host $str
                            Write-Host ""
                            Write-Log -LogOutput ($str) -WithTime
                        }
                    }
                    if((New-object Microsoft.SharePoint.WorkflowServices.WorkflowServicesManager($web)).IsConnected -ne $False)
                    {
                        Write-Host "Checking for 2013 Site Workflows"
                        $wfm = New-object Microsoft.SharePoint.WorkflowServices.WorkflowServicesManager($web)
                        $wfis = $wfm.GetWorkflowInstanceService()
                        $sub = $wfm.GetWorkflowSubscriptionService()
                        $subs = $sub.EnumerateSubscriptions() | ? {$_.StatusColumnCreated -eq $False}
                        if($subs.Count -gt 0)
                        {
                            foreach($s in $subs)
                            {
                                $runningInstances = ($wfis.Enumerate($s) | ? {$_.Status -ne "Completed"}).Count
                                $modified = ($s.PropertyDefinitions.'SharePointWorkflowContext.Subscription.ModifiedDate')
                                $author = ($s.PropertyDefinitions.'ModifiedBy')
                                $histListID = ($s.PropertyDefinitions.'HistoryListId')
                                $histListTitle = $web.Lists.GetList($histListID,$false).Title
                                $histListUrl = $web.Lists.GetList($histListID,$false).DefaultViewUrl
                                $histListItemCount = $web.Lists.GetList($histListID,$false).ItemCount
                                
                            }
                                $strOut = $web.Title+","+$web.Url+",SiteWorkflow,"+$s.Name+","+$s.Enabled+",2013,"+$runningInstances+",True,"+$modified+","+$author+","+$histListTitle+","+($web.Site.WebApplication.Url).Trim('/')+$histListUrl+","+$histListItemCount
                                Write-Host $strOut
                                Write-Host ""
                                Write-Log -LogOutput ($strOut) -WithTime
                        }
                    }

                    Write-Host "Checking for List Workflows"
                    foreach($list in $web.lists)# | ?{$_.WorkflowAssociations.Count -ne 0})
                    {
                        if($list.WorkflowAssociations -ne 0)
                        {
                            Write-Host $list.Title
                            foreach($wfa in $list.WorkflowAssociations | ? {$_.Name -notlike "*(*"})
                            {
                                $str = $web.Title+","+$web.Url+","+$list.title+","+$wfa.Name+","+$wfa.Enabled+",2010,"+$wfa.RunningInstances+","+$wfa.IsDeclarative+","+$wfa.Modified+","+$web.SiteUsers.GetByID($wfa.Author).LoginName+","+$wfa.HistoryListTitle+","+($web.Site.WebApplication.Url).Trim('/')+$web.Lists[$wfa.HistoryListTitle].DefaultViewUrl+","+$web.Lists[$wfa.HistoryListTitle].ItemCount
                                Write-Host $str
                                Write-Host ""
                                Write-Log -LogOutput ($str) -WithTime
                            }
                        }
                        if((New-object Microsoft.SharePoint.WorkflowServices.WorkflowServicesManager($web)).IsConnected -ne $False)
                        {
                            $wfm = New-object Microsoft.SharePoint.WorkflowServices.WorkflowServicesManager($web)
                            $sub = $wfm.GetWorkflowSubscriptionService()
                            $wf = $sub.EnumerateSubscriptionsByList($list.ID)
                            $wfis = $wfm.GetWorkflowInstanceService()
                            #Start-Sleep -Seconds 3 #On occasion the Workflow Manager Enumeration call times out on first use - comment the sleep line if WFM is sure to be active
                            foreach($s in $sub.EnumerateSubscriptionsByList($list.ID))
                            {
                                $runningInstances = ($wfis.Enumerate($s) | ? {$_.Status -ne "Completed"}).Count
                                $modified = ($s.PropertyDefinitions.'SharePointWorkflowContext.Subscription.ModifiedDate')
                                $author = ($s.PropertyDefinitions.'ModifiedBy')
                                $histListID = ($s.PropertyDefinitions.'HistoryListId')
                                $histListTitle = $web.Lists.GetList($histListID,$false).Title
                                $histListUrl = $web.Lists.GetList($histListID,$false).DefaultViewUrl
                                $histListItemCount = $web.Lists.GetList($histListID,$false).ItemCount

                                $strOut = $web.Title+","+$web.Url+","+$list.Title+","+$s.Name+","+$s.Enabled+",2013,"+$runningInstances+",True,"+$modified+","+$author+","+$histListTitle+","+($web.Site.WebApplication.Url).Trim('/')+$histListUrl+","+$histListItemCount
                                Write-Host $strOut
                                Write-Host ""
                                Write-Log -LogOutput ($strOut) -WithTime
                            }
                        }
                    }
                }
            }
        }
    }
}

switch ($scope)
{
    Farm
        {
            #Build Collection of all Site Collections in the Farm
            $allSites = Get-SPWebApplication | select -ExpandProperty Sites | select -ExpandProperty Url
            Write-Host "Checking for Workflows in the Farm -"$allSites.count"sites"
            #Call Function for Workflow Enumeration
            Get-WorkflowInfo $allSites
            Write-Log -LogOutput ("End Logging for FindWorkflows and History Lists: "+$PSCommandPath) -WithTime
        }
    
    WebApp
        {
            #Build Collection of all Site Collections in the web app specified in $scopeURL
            Try
                {
                    $allSites = Get-SPWebApplication $scopeUrl -ErrorAction Stop | select -ExpandProperty Sites | select -ExpandProperty Url 
                }
            Catch
                {
                    Write-Host "The URL specified in $scopeUrl is not a valid Web Application URL"`n -ForegroundColor Red
                    Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red -BackgroundColor White
                    exit -1
                }
            Write-Host "Checking for Workflows in the WebApp -"$allSites.count"site collections"
            #Call Function for Workflow Enumeration
            Get-WorkflowInfo $allSites
            Write-Log -LogOutput ("End Logging for FindWorkflows and History Lists: "+$PSCommandPath) -WithTime
        }
    
    Site
        {
            #Build Collection of all Site Collections in the Farm
            Try
                {
                    $allSites = Get-SPSite $scopeUrl -ErrorAction Stop | select -ExpandProperty Url 
                }
            Catch
                {
                    Write-Host "The URL specified in $scopeUrl is not a valid Site Collection URL"`n -ForegroundColor Red
                    Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red -BackgroundColor White
                    exit -1
                }
            Write-Host "Checking for Workflows in the Site Collection"$scopeUrl"- "(Get-SPSite $scopeUrl).AllWebs.Count"webs"
            #Call Function for Workflow Enumeration
            Get-WorkflowInfo $allSites
            Write-Log -LogOutput ("End Logging for FindWorkflows and History Lists: "+$PSCommandPath) -WithTime
        }
}