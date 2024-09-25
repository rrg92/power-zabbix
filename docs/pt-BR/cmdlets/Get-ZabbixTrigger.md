---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Get-ZabbixTrigger

## SYNOPSIS <!--!= @#Synop !-->
Equivalente ao método da API trigger.get

## DESCRIPTION <!--!= @#Desc !-->
https://www.zabbix.com/documentation/3.2/manual/api/reference/trigger/get

## SYNTAX <!--!= @#Syntax !-->

```
Get-ZabbixTrigger [[-Id] <Int32[]>] [[-Hosts] <String[]>] [[-Groups] <String[]>] [[-Name] <String[]>] [-Search] [-SearchByAny] [-StartSearch] [[-limit] <Object>] [[-output] 
<Object>] [-Trigged] [-NoExpand] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -Id

```yml
Parameter Set: (All)
Type: Int32[]
Aliases: 
Accepted Values: 
Required: false
Position: 1
Default Value: @()
Accept pipeline input: false
Accept wildcard characters: false
```

### -Hosts

```yml
Parameter Set: (All)
Type: String[]
Aliases: 
Accepted Values: 
Required: false
Position: 2
Default Value: @()
Accept pipeline input: false
Accept wildcard characters: false
```

### -Groups

```yml
Parameter Set: (All)
Type: String[]
Aliases: 
Accepted Values: 
Required: false
Position: 3
Default Value: @()
Accept pipeline input: false
Accept wildcard characters: false
```

### -Name

```yml
Parameter Set: (All)
Type: String[]
Aliases: 
Accepted Values: 
Required: false
Position: 4
Default Value: @()
Accept pipeline input: false
Accept wildcard characters: false
```

### -Search

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```

### -SearchByAny

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```

### -StartSearch

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```

### -limit

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

### -output

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 6
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Trigged

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```

### -NoExpand

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```