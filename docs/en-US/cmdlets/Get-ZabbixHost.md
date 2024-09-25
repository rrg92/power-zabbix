---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Get-ZabbixHost

## SYNOPSIS <!--!= @#Synop !-->
Gets Zabbix hosts

## DESCRIPTION <!--!= @#Desc !-->
Equivalent to API
https://www.zabbix.com/documentation/3.4/manual/api/reference/host/get

## SYNTAX <!--!= @#Syntax !-->

```
Get-ZabbixHost [[-Id] <Int32[]>] [[-Name] <String[]>] [[-Host] <String[]>] [[-Groups] <String[]>] [-Search] [-SearchByAny] [-StartSearch] [[-output] <Object>] [[-SelectGroups] 
<Object>] [[-SelectInterfaces] <Object>] [[-SelectInventory] <Object>] [[-HostStatus] <Object>] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -Id
Host id. Can be 1 or more ids separated by comma.

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

### -Name
Filter by Visible Name. You can specify multiple separated by comma.

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

### -Host
Filter by hostname. You can specify multiple separated by comma

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

### -Groups
Filter by host group. You can specify multiple separated by comma

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
Activates common search parameter

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
Activates searchByAny parameter from api

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
Activates common StartSearch parameter

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

### -output
Common output parameter

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

### -SelectGroups
Query to select host groups. Parameter selectGroups from api.

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

### -SelectInterfaces
Query to select interfaces. Parameter selectInterfaces from API

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 7
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -SelectInventory
Query to select inventory. Parameter selectInventory from API

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

### -HostStatus

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 9
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```




<!--**AiDocBlockStart**-->
_Automatically translated using PowershAI and AI. 
_
<!--**AiDocBlockEnd**-->
