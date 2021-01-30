# SCOUTS-DATA-PROFILER
A flexible pure T-SQL data profiler 

```SQL
--Setup templates
DECLARE @Template SCOUT.Templates

INSERT INTO @Template VALUES ('MAX', 'SELECT MAX(<C>) AS [Max] FROM <T>')
INSERT INTO @Template VALUES ('MIN', 'SELECT MIN(<C>) AS [Min] FROM <T>')
INSERT INTO @Template VALUES ('COUNT', 'SELECT COUNT(<C>) AS [Count] FROM <T>')
INSERT INTO @Template VALUES ('COUNT NULLS', 'SELECT COUNT(*) AS [Count] FROM <T> WHERE <C> IS NULL')
INSERT INTO @Template VALUES ('COUNT BLANKS', 'SELECT COUNT(*) [Blanks] FROM <T> WHERE <C> = ''''')
INSERT INTO @Template VALUES ('DISTINCT VALUES', 'SELECT COUNT(DISTINCT <C>) [DistinctCount] FROM <T> WHERE <C> IS NOT NULL')
INSERT INTO @Template VALUES ('TOP N DISTINCT VALUES' ,
	'SELECT TRIM(STRING_AGG(DISTINCT_LIST, '', '')) [Top 10 values] FROM
	(SELECT DISTINCT TOP 10 CONCAT_WS('' ('', <C>, COUNT(<C>)) + '')'' AS DISTINCT_LIST, COUNT(<C>) AS _
		FROM <T>
		WHERE <C> IS NOT NULL
		GROUP BY <C>
		ORDER BY COUNT(<C>) DESC
	) LIST')

--Run the profiler
EXEC [SCOUT].[SCOUTS_Data_Profiler]
	@Database = 'WideWorldImportersDW-Standard',
	@SCHEMA = 'Fact',
	@TABLE = 'Order',
	@Templates_as_ref = @Template
```