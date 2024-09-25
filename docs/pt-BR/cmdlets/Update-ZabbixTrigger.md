---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Update-ZabbixTrigger

## SYNOPSIS <!--!= @#Synop !-->
Equivalente ao método trigger.update.

## DESCRIPTION <!--!= @#Desc !-->
https://www.zabbix.com/documentation/3.2/manual/api/reference/trigger/update
Utilize com Get-ZabbixTrigger:
$MinhaTrigger = Get-ZabbixTrigger
$MinhaTrigger.prop = newval
$MinhaTrigger | Update-ZabbixTrigger

## SYNTAX <!--!= @#Syntax !-->

```
Update-ZabbixTrigger [-ZabbixTrigger] <Object> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -ZabbixTrigger
If piped with Get-ZabbixTrigger, get the returned object from it!
Note that this cmdlet expects a object returned by Get-ZabbixTrigger cmdlet!

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: true
Position: 1
Default Value: 
Accept pipeline input: true (ByValue)
Accept wildcard characters: false
```

### -WhatIf

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: wi
Accepted Values: 
Required: false
Position: named
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Confirm

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: cf
Accepted Values: 
Required: false
Position: named
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```