
# Companies

- [ ] Still need to load the newest record per id as the delta will be loaded afterwards

```sqlite
select id as CompanyId, ExtractTimestamp, createdAt, updatedAt, archived
from hubspot_items hp
where object = 'companies'
	and ExtractTimestamp = (select max(ExtractTimestamp) from hubspot_properties where object = 'companies')
```

## Variables

```sqlite

/*

check numerics with decimals
how to identify arrays/flag arrays?

*/


SELECT *
FROM (
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'Description' AS PropertyName
		,'CP '||p.value AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'label'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'notes' AS PropertyName
		,p.value AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'description'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'FolderName' AS PropertyName
		,substr(p.value, 0, 9) AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'groupName'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'FolderDescription' AS PropertyName
		,substr(p.value, 0, 80) AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'groupName'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataType' AS PropertyName
		,'Text' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom = 'string'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataType' AS PropertyName
		,'Numeric' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom = 'number'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataType' AS PropertyName
		,'Array' AS PropertyValue
	FROM hubspot_properties hp --, json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND json_extract(hp.property, '$.type') IN (
			'enumeration'
			,'bool'
			)
		AND json_extract(hp.property, '$.fieldType') = 'checkbox'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataType' AS PropertyName
		,'Selector' AS PropertyValue
	FROM hubspot_properties hp --, json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND json_extract(hp.property, '$.type') IN (
			'enumeration'
			,'bool'
			)
		AND json_extract(hp.property, '$.fieldType') != 'checkbox'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataType' AS PropertyName
		,'Date' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom = 'date'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataType' AS PropertyName
		,'DateTime' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom = 'datetime'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'UnclassifiedDescription' AS PropertyName
		,'Nicht klassifiziert' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom IN (
			'enumeration'
			,'bool'
			)
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataType' AS PropertyName
		,'Numeric' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom = 'number'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'NumericType' AS PropertyName
		,'Integer' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom = 'number'
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DateInputFormat' AS PropertyName
		,'YYYYMMDD' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom IN (
			'date'
			,'datetime'
			)
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'DataDescriptionFormat' AS PropertyName
		,'DD.MM.YYYY' AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
		AND p.atom IN (
			'date'
			,'datetime'
			)
	
	UNION ALL
	
	SELECT 'c'||substr(replace(hp.id,'_',''), 3, 2) || substr(replace(hp.id,'_',''), -4, 2)||coalesce(substr(createdAt,-4,3),substr(replace(hp.id,'_',''), 7, 3)) AS Reference
		,'QuestionCode' AS PropertyName
		,hp.id AS PropertyValue
	FROM hubspot_properties hp
		,json_each(property) p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND p.KEY = 'type'
/*
		AND p.atom IN (
			'string'
			,'number'
			,'date'
			,'datetime'
			)
*/
	)
	--where reference = 'chs_r_id'
ORDER BY Reference

```

## Attributes

```sqlite


SELECT *
FROM (
	SELECT hp.id AS QuestionCode
		,json_extract(p.value, '$.value') AS AnswerCode
		,json_extract(p.value, '$.label') AS AnswerDescription
		,'c' || substr(replace(hp.id, '_', ''), 3, 2) || substr(replace(hp.id, '_', ''), - 4, 2) || coalesce(substr(createdAt, - 4, 3), substr(replace(hp.id, '_', ''), 7, 3)) AS VariableReference
		,json_extract(p.value, '$.displayOrder') AS DisplayOrder
	FROM hubspot_properties hp
		,json_each(property, '$.options') p
	WHERE OBJECT = 'companies'
		AND ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_properties
			WHERE OBJECT = 'companies'
			)
		AND json_extract(p.value, '$.hidden') = 0
	
	UNION ALL
	
	SELECT DISTINCT p.KEY AS QuestionCode
		,p.atom AS AnswerCode
		,p.atom AS AnswerDescription
		,'c' || substr(replace(hp.id, '_', ''), 3, 2) || substr(replace(hp.id, '_', ''), - 4, 2) || coalesce(substr(hp.createdAt, - 4, 3), substr(replace(hp.id, '_', ''), 7, 3)) AS VariableReference
		,- 1 AS DisplayOrder
	FROM hubspot_items hi
		,json_each(properties) p
		,(
			SELECT
				--*, json_extract(property,'$.options')
				--id
				*
			FROM hubspot_properties h
			WHERE json_extract(property, '$.type') = 'enumeration'
				AND json_array_length(property, '$.options') = 0
				AND OBJECT = 'companies'
				AND ExtractTimestamp = (
					SELECT max(ExtractTimestamp)
					FROM hubspot_properties
					WHERE OBJECT = 'companies'
					)
			) hp
	WHERE hi.OBJECT = 'companies'
		AND hi.ExtractTimestamp = (
			SELECT max(ExtractTimestamp)
			FROM hubspot_items
			WHERE OBJECT = 'companies'
			)
		AND p.value IS NOT NULL
		AND p.KEY = hp.id
	)
ORDER BY QuestionCOde
	,DisplayOrder


```

## Answers

```sqlite
SELECT hi.id AS URN
	,p.KEY AS QuestionCode
	,p.value AS AnswerCode
FROM hubspot_items hi
	,json_each(properties) p
WHERE OBJECT = 'companies'
	AND ExtractTimestamp = (
		SELECT max(ExtractTimestamp)
		FROM hubspot_items
		WHERE OBJECT = 'companies'
		)
	AND ( p.value IS NOT NULL or p.value != '')
ORDER BY hi.id
```

# Contacts

```sqlite
select json_extract(hp.properties,'$.associatedcompanyid') as CompanyId, id as ContactId, ExtractTimestamp, createdAt, updatedAt, archived
from hubspot_items hp
where object = 'contacts'
	and ExtractTimestamp = (select max(ExtractTimestamp) from hubspot_properties where object = 'contacts')
```