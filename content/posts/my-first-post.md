---
title: "Find Workflow Associations and History Lists"
date: 2020-07-21T11:24:09+02:00
draft: False
tags: [
    "SharePoint",
    "PowerShell",
	"Workflow",
	
]
categories: [
    "Scripts",
]
---

### Find all 2010 and 2013 Workflows, their associated history lists and running instances

As SharePoint 2010 Workflows are sunsetting in SharePoint Online [SharePoint 2010 Workflow Retirement](https://support.microsoft.com/en-us/office/sharepoint-2010-workflow-retirement-1ca3fff8-9985-410a-85aa-8120f626965f), it becomes even more important to inventory, rework and/or dispose of SharePoint 2010 workflows in your on premises SharePoint Farms.  To that end, I have written a PowerShell script to find all workflows (2010 or 2013) and record the interesting details about the workflow in a CSV file.


	Add-PSSnapin Microsoft.SharePoint.PowerShell -EA 0
	Get-SPWebApplication | ? {$_.URL -like "*https*"}
