# PowerZabbix

PowerZabbix allows query zabbix data via the zabbix api and access frontend using powershell code!
In addition to the cmdlets that represent API calls, this tool adds some other cmdlets and parameters to enhance de user experience with zabbix API.

It is easy start managing zabbix, gathering data to generate custom reports, download maps, etc. with this tool! Check examples section to ideas.


## Download, install and start using

This tool is a powershell module. Powershell modules are way to pack many powershell commands. For use the commands, you must import the module to the powershell session.
If you is a experient powershell user, then just install download the project and install module in your way.
If you is not a experient user, follow this steps to download:

* Download latest stable release of this. It will a zipped file. There are many ways to install this module.

### Way 1: Install module to a module path

* Extracts the contents of the zipped files to a powershell module path. Powershell provide many locations as module paths. Use following powershell command to determine available powershell module locations. You can extract the contents to one of them (remeber that you must have write permissions to extracts contents to directory of your choose):
```powershell
$Env:PsModulePath -split ";"
```
Tip: The directory in C:\Users\<UserName>\Documents\WindowsPowershell\Modules can not exists. You must create and can extract to it. If you download to it, just user _UserName_ can use module in this way.

* To start using, in powershell, run:
```powershell
import-module power-zabbix -force;
```

### Way 2: Install the module in any directory of your preference

* Choose a folder where to extract the zipped file. For example, C:\temp
* To start using, in powershell, run:
```powershell
import-module C:\temp\power-zabbix -force;
```

* After it, you can start using the cmdlets available.

#### About powershell execution policies

Powershell contains a mechanism that prevents script execution by default. They are execution policies.
You must run the powershell in a session allowed to run scripts. If you receive a error containing "script execution disabled", you have some options to fix it:

* **Option 1**: If you are a Administrator and want disable this check, opens powershell as Administrador and runs: Set-ExecutionPolicy Unrestricted. Reopen all sessions where you want use module.

* **Option 2**: If you are not a Administrator, then start powershell using following commad: powershell -ExecutionPolicy Unrestrcited. You can call this from a cmd prompt or another powershell session.
	
	
	
## Basic usage

Before getting of updating zabbix, you must authenticate on the server, just like you do when accessing zabbix via the web.
For this, we provide a cmdlet called *Auth-Zabbix*. This is simple form to use it:

```powershell
Auth-Zabbix -URL 'http://myZabbixIPOrDNSName/zabbix'
```

After this, the cmdlet will prompts you credentials. If any erros occurs in the authentication, a error will be trhown.
Note that URL Passed must be the same URL that you use to access zabbix web. If your URL not include the "/zabbix", then not use them.

You just call Auth-Zabbix one time. If the authentication is sucessfully, then a session is created and them it is cached is used by all cmdlets.
A session is pair of URL/Username. If you try authenticate again with same URL and UserName, the session in cache is used. You can use the -Force parameter to force a new authentication, generating a new session.

### About using multiple sessions

You can use Auth-Zabbix to generate multiple sessions. For example, you can use Auth-Zabbix to authenticate in ZabbixHost1 and ZabbixHost2.
When you authenticate in just one session, the PowerZabbix uses it as default session, and all cmdlets will use this session.
When multiple sessions exists, you must explicity define a default session, otherwise the cmdlet will fail with "NO DEFAULT SESSION" error.
You can use the Get-ZabbixSessions (or result of Auth-Zabbix) and Set-DefaultZabbixSession to define default session. For example:

```powershell

#Creates a session o Host1
$s1 = Auth-Zabbix -URL 'https://ZabbixHost1/zabbix';
$s2 = Auth-Zabbix -URL 'https://ZabbixHost2/zabbix';

#Setting a default zabbix sessions, using the output of Auth-Zabbix
$s2 | Set-DefaultZabbixSession

#Choosing a session from all session list!
$AllSessions = Get-ZabbixSessions;

#View the default session
Get-DefaultZabbixSession

#Changing the default session to the first session returned.
$s[0] | Set-DefaultZabbixSession
```

Use the Get-Help Auth-Zabbix to more help and parameters avaliable.


### Example 1: Getting hosts

The cmdlet Get-ZabbixHost is useful to retrive hosts.
It have a lot of parameters like the host.get. We are working to adding all parameters! Keep updated!

```powershell

# Get a host with specific id
Get-ZabbixHost -Id 10084


# Get all hosts in the group "DATABASE"
Get-ZabbixHost -Groups 'TEST'

#Get all hosts in the group mssql and postgres
Get-ZabbixHost -Groups 'MSSQL','POSTGRES'

# Get all hosts in the group LINUX, and output just hostid, hostname and visible name.
Get-ZabbixHost -Groups 'LINUX'  -output 'hostid','host','name'

# The next example if more complex, but just use simples constructs from PowerZabbix and powershell language.
# First, we store hosts from WINDOWS group in a variable. Up to here, we just out the result to the console.
# This is useful if we need access this data multiple times or if want change the data and pipe to another cmdlet. 
# Instead querying zabbix server everty time, we just cache in local memory via a powershell variable.
# We use the -output parameter to specify that we want the 'hostid' and 'hostname' properties.
$AllHosts = Get-ZabbixHost -Groups 'WINDOWS' -output 'hostid','host'

#Suppose you want update all hostsnames of the hosts in WINDOWS group. For example, you want add the string "WIN-" at the start of the hostname. This simple for 1 or 10 hosts. But if you have 1000 hosts, this script can save time (and money).
#Because we already have all hosts in WINDOWS GROUP in $AllHosts variable, we just need use them (we suppose that no more hosts were added since last call to Get-ZabbixHost)
$AllHosts | %{  $_.host = "WIN-"+$_.host };

# TO update host, just use the "Update-ZabbixHost". You can pipe the hosts to it.
# Before update, you can use WhatIf to see what the cmdlet will do and JSON submeted to zabbix server:
$AllHosts | Update-ZabbixHost -WhatIf

#Now, if you secure, then just update!
$AllHosts | Update-ZabbixHost;


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
$LotOfHosts = Get-ZabbixHost -output @('hostid')

#Check what will be updated...
$LotOfHosts | Update-ZabbixHost -Groups 'MY_NEW_GROUP' -append -WhatIf

#Now, update!
$LotOfHosts | Update-ZabbixHost -Groups 'MY_NEW_GROUP' -append

#Some tips when using Update-* cmdlets
# Most of this cmdlets expects objects returned by respectived Get- cmdlet.
# Use output parameter to return just properties that you will update. This reduce network traffic and zabbix processing.

```


## CmdLets return type

Most of cmdlets returns a object (or array of objects) with same properties returned by the equivalent api method.
You must always check the cmdlet documentation to more information, using Get-Help.


## CmdLets nomenclature

The PowerZabbix provides implementations of zabbix api and facilites to help managing zabbix.
Following sections explain the type of cmdlets the PowerZabbix defines.

### API implementations cmdlets
This cmdlets is created to directly implement a API method. Parameters names and behvarios are close to the respective method parameters.
The cmdlets that are created to implement a API method contains following format:

	Verb + -Zabbix + ObjectCamelCaseName
	
The Parts are:
	
* Verb = The action that cmdlet will do.
* -Zabbix = Fixed string. This represent the cmdlet is a API implementation.
* ObjectCamelCaseName = This is camel case name of object. For example, for hostgroup, will be HostGroup


	
These are examples:

* Get-ZabbixHost 			=> host.get
* Update-Zabbixhost 		=> host.update 
* Create-ZabbixHostGroup 	=> hostgroup.create
* Ack-ZabbixEvent			=> event.acknowledge
* Delete-ZabbixItem			=> item.delete

### FRONTEND functionality

This cmdlets fill a lack in API by providing data or actions via the calls to zabbix web URL.
For example, the API currently dont support download of maps. This is a feature of the frontend.
Thanks to this cmdlets, the PowerZabbix provides a progrmatic way to access maps images.
It generally must run in conjunction with result of some API cmdlet.
The cmdlet name format is:

	Verb + -ZabbixFrontEnd + ObjectCamelCaseName
	
Examples:

* Add-ZabbixFrontendMapImage		=> This cmdlet adds a mapp to the maps returned by Get-ZabbixMap.
```powershell
#Gets a zabbix map object (contains mapid, etc...)
$MyMap = Get-ZabbixMap -Name "My network topology"

#Adds the map bytes to the $MyMap object! This will add the mapImage property to the $myMap object.
$MyMap | Add-ZabbixFrontendMapImage -Minseverity 3

#Write the map to a file in local computer!
[Io.File]::WriteAllBytes('C:\temp\maps.png', $MyMap.mapImage.bytes);
```

### Auxiliary cmdlets

This cmdlets provided some additional features in order to facilitie some operation.
It are anything that not in previous categoires.


Examples:

* Auth-Zabbix			=> Provides a way to generate zabbix sessions and handles URLs, users and passwords.
* Get-ZabbixSessions	=> List all zabbix sessions created using Auth-Zabbix
* Get-InterfaceConfig	=> Returns a hashtable with parameters to input in Create-ZabbixHost, parameter Interface.
	

## Getting help

You can use Get-Command -Module power-zabbix to get all avaliable cmdlets.
You also can use Get-Help to get help.
We are working to implement new API methods and enhance the documentation.


## Help enhance

USe the issues to inform bugs or enhancements.












