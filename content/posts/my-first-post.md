---
title: "My First Post"
date: 2020-07-21T11:24:09+02:00
draft: False
tags: [
    "SharePoint",
    "PowerShell",
]
categories: [
    "SharePoint",
    "Scripts",
]
---

## Something along the lines of a Post intro or BLUF.

### We are cooking with Gas now!


	Add-PSSnapin Microsoft.SharePoint.PowerShell -EA 0
	Get-SPWebApplication | ? {$_.URL -like "*https*"}
