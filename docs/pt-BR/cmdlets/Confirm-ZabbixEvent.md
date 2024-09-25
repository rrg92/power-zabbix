---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Confirm-ZabbixEvent

## SYNOPSIS <!--!= @#Synop !-->
Equivalente ao método da API event.acknowledge

## DESCRIPTION <!--!= @#Desc !-->
https://www.zabbix.com/documentation/3.4/manual/api/reference/event/get

## SYNTAX <!--!= @#Syntax !-->

```
Confirm-ZabbixEvent [-EventId] <Int32> [[-Message] <String>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -EventId

```yml
Parameter Set: (All)
Type: Int32
Aliases: 
Accepted Values: 
Required: true
Position: 1
Default Value: 0
Accept pipeline input: true (ByPropertyName)
Accept wildcard characters: false
```

### -Message

```yml
Parameter Set: (All)
Type: String
Aliases: 
Accepted Values: 
Required: false
Position: 2
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