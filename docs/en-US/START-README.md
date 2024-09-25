![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/powerzabbix)
![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/powerzabbix)

# PowerZabbix

* [english](/docs/en-US/START-README.md)

PowerZabbix is a powershell module that encapsulates Zabbix API calls, allowing you to invoke them directly from Powershell, using powershell features such as pipeline, etc.  

With a few commands, you can automate the creation of hosts, host groups, items, etc.  

**IMPORTANT: This project was stalled for a while, and now I decided to update it again. There are still many endpoints and documentation. I'm aware of the issues that have been opened. If you know powershell and want to contribute, I'm accepting help to help me keep this project updated!**

PowerZabbix allows query zabbix data via the zabbix api and access frontend using powershell code!
In addition to the cmdlets that represent API calls, this tool adds some other cmdlets and parameters to enhance de user experience with zabbix API.

It is easy start managing zabbix, gathering data to generate custom reports, download maps, etc. with this tool! Check examples section to ideas.


## Installation  


The easiest way to install powerzabbix is using the `Install-Module powerzabbix` command:

```powershell 
Install-Module powerzabbix
```  


If you have problems, you can clone this repository and import it:

```powershell
cd C:\temp
git clone https://github.com/rrg92/power-zabbix
cd power-zabbix 
import-module .\powerzabbix 
```

**IMPORTANT: You may need to enable script execution in your environment, with Set-ExecutionPolicy**
	
	
## Basic Usage

Before using this module, it is important to have the following on hand:

- The zabbix URL (make sure it is accessible from your computer. Ex: test authentication in the browser before)
- User/Password or an API Token

Then, the first thing to do is to authenticate:

```powershell
import-module powerzabbix # obviously, you need to import the module in the session!

# Use the Connect-Zabbix command to authenticate!
Connect-Zabbix 'http://IpOrDNS'

# The credentials will be requested!
# After authenticating, you can use the commands, for example:
Get-ZabbixHost # list the hosts!

```

The Connect-Zabbix command is the starting point for authentication.  
You can specify various URL formats and even an API Token. Learn more about using `get-help Connect-Zabbix`.  

### Multiple sessions 

You can create multiple connections, with different zabbix servers, or with the same server using different users.
However, only one of these sessions is active at a time (this may change soon):

```powershell

# Create two sessions 
$s1 = Connect-Zabbix -URL 'https://ZabbixHost1/zabbix';
$s2 = Connect-Zabbix -URL 'https://ZabbixHost2/zabbix';

# Define the session returned in $2 as default:
$s2 | Set-DefaultZabbixSession

# check the default!
Get-DefaultZabbixSession
```

### Example: Listing and updating hosts

The `Get-ZabbixHost` command is the main one to get the list of hosts.  
It is equivalent to the host.get API method. Many parameters have already been added, and the others will be added:

```powershell

# Get a host with a specific id
Get-ZabbixHost -Id 10084


# Get all hosts from the "DATABASE" group
Get-ZabbixHost -Groups 'TEST'

# Get all hosts that are in the MSSQL or POSTGRES group
Get-ZabbixHost -Groups 'MSSQL','POSTGRES'

# All hosts in the LINUX group, returning only the hostid, hostname and visible name properties.
Get-ZabbixHost -Groups 'LINUX'  -output 'hostid','host','name'

# The next example is a bit more complex if you are not used to powershell
# First, we store all hosts in the WINDOWS group in a variable.
# This is useful if you need to access this data several times 
# Instead of looking up this information in zabbix all the time, you save it in your powershell session!
# Thanks to the -output parameter, we return only a few data from the api.
$AllHosts = Get-ZabbixHost -Groups 'WINDOWS' -output 'hostid','host'

# Suppose you wanted to update all host names in the WINDOWS group. 
# For example, you want to add the prefix "WIN-" at the beginning. ]
# This would be easy to do for 10 hosts. But for 1000, things can get a bit complicated...
# Let's say the result of the previous command contains this list. Then, first, we add the prefix with a simple foreach (%) command, from powershell:
$AllHosts | %{  $_.host = "WIN-"+$_.host };

# The command above is just powershell, nothing special. It iterates over the array of hosts in $Allhosts, and for each one, it changes the host property.

# So far, we have only updated in the memory of our session!
# To make this effective in abbix, we need to use the Update-ZabbixHost command
# We can use the pipe to pass the values.
# And, before updating, the -WhatIf parameter can be used to just simulate what would happen:
$AllHosts | Update-ZabbixHost -WhatIf

# and, once you have confirmed, just run!
$AllHosts | Update-ZabbixHost;


# To show you some more facilities of PowerZabbix, consider this example:
#	We want to add a bunch of hosts to a hostgroup
#	The API doesn't define a way to add groups to a host. It expects a complete list that will overwrite the previous list.
#	For example, imagine that a host A belongs to groups 1,13,40,20,59 and a host B belongs to group 1 and 2. You want to add these hosts to group 100.
# To do this, you would have to do the following using the API:
#	Get the current list
#	Add the new id 
#	invoke the host.update method with the updated list.
#
# The Update-ZabbixHost cmdlet simplifies this, thanks to the -Append parameter
$LotOfHosts = Get-ZabbixHost -output @('hostid')

# Adds to the MY_NEW_GROUP group
$LotOfHosts | Update-ZabbixHost -Groups 'MY_NEW_GROUP' -append

#To show you the enhacements and facilites provided to PowerZabbix, consider this example.
# We want add a lot of hosts to a hostgroup!
# The API dont define a way to append hosts groups to the hosts.
# The API expects that you inform all groups ids when updating a hostgroup for a host.
# For example, supposed the host A belongs to groupsids 1,13,40,20,59 and host B belongs to group 1 and 2. You want add this host to the group 100.
# By default, the api expects you specify new groups ids, that will replace current groups ids.
# In order to complete this task using just api, for each host, you must do this:
#		1) Get the current groups ids
#		2) Add new groups ids
#		3) Call host.update method passing the complete list (older + new groups)
# The Update-ZabbixHost simplifie this actions with -Append parameter. Just specify the groups in the -Groups paraemter and the magic happens!

# Here we get all hosts. Is not important the groups...
# note that specify the unique property 'hostid'. This is because we not need any property to do this...
# The @('hostid') is need due to fact we specify a unique value and the API expects this as array. With this, we ask to powershell to treat this values as array, not a string...


# Tip when using Update-* commands
# Most of these commands expect the return of the respective Get-* cmdlet
# Use the -output parameter of the Get-* command to bring only what you need to update. This reduces unnecessary traffic and helps relieve your zabbix and database.
```

## Nomenclature

Most of the commands are wrappers for the zabbix API, with the possibility of additional options to make it easier to use.  
Knowing this, it's easier to find a command for your need:

### Commands that implement the API directly  

There is a group of commands that implement the direct functionality of the API.
They have parameters and behavior very close to that of the respective API method. 
The format is:

	Verb + -Zabbix + ObjectCamelCaseName
	
	
* Verb  
The action. It is usually the second part. For example, host.get, will be Get-ZabbixHost.  
Not every action has an approved verb directly in powershell, so, the closest approved verb will be used.  
For example, host.create is not Create-ZabbixHost, but rather New-ZabbixHost, because the name Create is not approved as a powershell verb.  
However, to make it intuitive, aliases can be created.

* -Zabbix = is a fixed string. Every command exported from the powerzabbix module must have this string in the name.  

* ObjectCamelCaseName  
This is the camel case standard of the respective object that the api affects.  For example, hostgroup.get becomes Get-ZabbixHostGroup. 


Some examples:

* Get-ZabbixHost => host.get
* Update-Zabbixhost => host.update 
* New-ZabbixHostGroup => hostgroup.create
* Confirm-ZabbixEvent => event.acknowledge
* Remove-ZabbixItem => item.delete

### FRONTEND

Some zabbix functionality is not provided by the API, but by the frontend.  
For example, the download of map images is not possible through the API. It is a frontend feature.  
Or because, in a certain version, there is support.  

However, to provide the best possible experience in powerzabbix, we use some hacks to bring the frontend functionality to the command line.  
It's important to know that, due to this nature, depending on the version of your zabbix, if you update, for example, these implementations can fail.  
If this is your case, open issues so we can quickly evaluate alternatives and corrections.  

To keep it separate from the official API implementation, frontend commands follow this format pattern:

	Verb + -ZabbixFrontEnd + ObjectCamelCaseName
	
Examples:

* Add-ZabbixFrontendMapImage => Adds the bytes of the map returned by Get-ZabbixMap.

```powershell
# gets a map object!
$MyMap = Get-ZabbixMap -Name "topology of my network"

# generates the map image with severity 3, and adds the image bytes to the object!
$MyMap | Add-ZabbixFrontendMapImage -Minseverity 3

# Now, just write to a file!
[Io.File]::WriteAllBytes('C:\temp\maps.png', $MyMap.mapImage.bytes);
```

### Auxiliary cmdlets

Some cmdlets don't necessarily interact with the API, implement something from the API, but complement by creating objects or making it easier to create complex structures:


Examples:

* Get-ZabbixSessions	=> list sessions
* Get-InterfaceConfig	=> makes it easier to create an interface object, to be used with New-ZabbixHost
	

## Explore

Use `Get-Command -Module powerzabbix`c to see all commands
Use `Get-Help -full NomeComando` to get help about the command!  
With each new version, we will further improve the documentation of these commands with details and examples.


## Contribute  

You can contribute to powerzabbix in several ways:

- You can help by suggesting improvements and additions to the documentation 
- You can suggest new features 
- you can submit pull requests with fixes 
- You can help by flagging when new features of the new zabbix versions are released 

Use the issues!

















<!--**AiDocBlockStart**-->
_Automatically translated using PowershAI and AI. 
_
<!--**AiDocBlockEnd**-->
