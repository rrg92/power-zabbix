---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Get-ZabbixHost

## SYNOPSIS <!--!= @#Synop !-->
Obtém os hosts do zabbix

## DESCRIPTION <!--!= @#Desc !-->
Equivalente a API
https://www.zabbix.com/documentation/3.4/manual/api/reference/host/get

## SYNTAX <!--!= @#Syntax !-->

```
Get-ZabbixHost [[-Id] <Int32[]>] [[-Name] <String[]>] [[-Host] <String[]>] [[-Groups] <String[]>] [-Search] [-SearchByAny] [-StartSearch] [[-output] <Object>] [[-SelectGroups] 
<Object>] [[-SelectInterfaces] <Object>] [[-SelectInventory] <Object>] [[-HostStatus] <Object>] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -Id
Id do host. Pode ser 1 ou mais ids separados por vírgula.

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
Filtra pelo nome de exibição (Visible Name). Pode especificar vários separado por vírgula.

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
Filtr por hostname, pode especificar vários separado por vírgula

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
Filtrar por host group. Pode especificar vários separados por vírgula

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
Ativa o parâmetro common search

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
Ativa o parâmetro searchByAny da api

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
ATiva o parâmetro common StartSearch

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
Parâemtro common output

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
Query para selecionar host groups. Parãmetro selectGroups da api.

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
Query para selecionar interfaces. Parãmetro selectInterfaces da API

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
Query para selecionar inventory. Parãmetro selectInventory da API

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