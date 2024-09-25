---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# New-ZabbixItem

## SYNOPSIS <!--!= @#Synop !-->
Equivalente ao método da API item.create

## DESCRIPTION <!--!= @#Desc !-->
https://www.zabbix.com/documentation/current/en/manual/api/reference/item/create
Propriedades: 
	https://www.zabbix.com/documentation/current/en/manual/api/reference/item/object

## SYNTAX <!--!= @#Syntax !-->

```
New-ZabbixItem [[-HostName] <Object>] [[-Name] <Object>] [[-Key] <Object>] [[-Type] <Object>] [[-ValueType] <Object>] [[-Params] <String>] [[-Delay] <String>] [[-ManualParams] 
<Object>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -HostName

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 1
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Name

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 2
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Key

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

### -Type
The type.

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 4
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -ValueType

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 5
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Params
The params

```yml
Parameter Set: (All)
Type: String
Aliases: Formula
Accepted Values: 
Required: false
Position: 6
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Delay

```yml
Parameter Set: (All)
Type: String
Aliases: UpdateInterval
Accepted Values: 
Required: false
Position: 7
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
Position: 8
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