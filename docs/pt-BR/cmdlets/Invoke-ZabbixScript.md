---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Invoke-ZabbixScript

## SYNOPSIS <!--!= @#Synop !-->
Equivale a API script.execute

## DESCRIPTION <!--!= @#Desc !-->
https://www.zabbix.com/documentation/current/en/manual/api/reference/script/execute

## SYNTAX <!--!= @#Syntax !-->

```
Invoke-ZabbixScript [-ScriptID] <Int32> [[-ZabbixHost] <String>] [[-ManualParams] <Object>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -ScriptID

```yml
Parameter Set: (All)
Type: Int32
Aliases: Id
Accepted Values: 
Required: true
Position: 1
Default Value: 0
Accept pipeline input: true (ByPropertyName)
Accept wildcard characters: false
```

### -ZabbixHost

```yml
Parameter Set: (All)
Type: String
Aliases: Host
Accepted Values: 
Required: false
Position: 2
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -ManualParams

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 3
Default Value: 
Accept pipeline input: false
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