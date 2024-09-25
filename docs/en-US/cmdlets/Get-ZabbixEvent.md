---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Get-ZabbixEvent

## SYNOPSIS <!--!= @#Synop !-->

Get Zabbix events.

## SYNTAX <!--!= @#Syntax !-->

```
Get-ZabbixEvent [[-Id] <int[]>] [[-Hosts] <string[]>] [[-Groups] <string[]>] [[-ObjectId] <string[]>] [[-TimeFrom] <Object>] [[-TimeTill] <Object>] [[-Object] {trigger | 
discovered host | discovered service | auto-registered host | item | LLD rule | 0 | 1 | 2 | 3 | 4 | 5}] [[-Value] <Object>] [[-selectHosts] <Object>] [[-selectRelatedObject] 
<Object>] [[-selectAcknowledges] <Object>] [[-limit] <Object>] [[-acknowledged] <Object>] [[-ManualParams] <Object>] [[-Correlate] <Object>] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -Correlate

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 14
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -Groups

```yml
Parameter Set: (All)
Type: string[]
Aliases: 
Accepted Values: 
Required: false
Position: 2
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -Hosts

```yml
Parameter Set: (All)
Type: string[]
Aliases: 
Accepted Values: 
Required: false
Position: 1
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -Id

```yml
Parameter Set: (All)
Type: int[]
Aliases: 
Accepted Values: 
Required: false
Position: 0
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -ManualParams

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 13
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -Object

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 6
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -ObjectId

```yml
Parameter Set: (All)
Type: string[]
Aliases: 
Accepted Values: 
Required: false
Position: 3
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -TimeFrom

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 4
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -TimeTill

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 5
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -Value

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 7
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -acknowledged

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 12
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -limit

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 11
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -selectAcknowledges

```yml
Parameter Set: (All)
Type: Object
Aliases: selectAcks
Accepted Values: 
Required: false
Position: 10
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -selectHosts

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 8
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```

### -selectRelatedObject

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 9
Default Value: 
Accept pipeline input: false
Accept wildcard characters: 
```




<!--**AiDocBlockStart**-->
_Automatically translated using PowershAI and AI. 
_
<!--**AiDocBlockEnd**-->
