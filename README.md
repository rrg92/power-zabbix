# PowerZabbix

PowerZabbix allows query zabbix data via the zabbix api and access frontend using powershell code!
In addition to the cmdlets that represent API calls, this tool adds some other cmdlets and parameters to enhance de user experiencie.

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
Tip: The directory in C:\Users\<UserName>\Documents\WindowsPowershell\Modules can not exists. You must create and can extract to it. If you download to it, just user <UserName> can use module in this way.

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
* **WARNING**: You must run the powershell in a session allowed to run scripts. If you receive a error containing "script execution disabled", you have some options to fix it:
	* Option 1: If you are a Administrator and want disable this check, opens powershell as Administrador and runs: Set-ExecutionPolicy Unrestricted. Reopen all sessions where you want use module.
	* Option 2: If you are not a Administrator, then start powershell using following commad: powershell -ExecutionPolicy Unrestrcited. You can call this from a cmd prompt or another powershell session.
	
	
	
## Basic flows
















