--Counts the number of non nulls rows
INSERT INTO @Template VALUES 
    ('COUNT', 'SELECT COUNT(<C>) AS [Count] FROM <T>')

--Counts the number of null rows
INSERT INTO @Template VALUES 
    ('COUNT NULLS', 'SELECT COUNT(*) AS [Count Nulls] FROM <T> WHERE <C> IS NULL')

--Count the number of blanks
INSERT INTO @Template VALUES 
    ('COUNT BLANKS', 'SELECT COUNT(*) [Blanks] FROM <T> WHERE <C> = ''''')

--Count distinct rows
INSERT INTO @Template VALUES 
    ('DISTINCT VALUES', 'SELECT COUNT(DISTINCT <C>) [DistinctCount] 
                                FROM <T> WHERE <C> IS NOT NULL')

--Create a list of the top 10 valus
INSERT INTO @Template VALUES 
    ('TOP N DISTINCT VALUES' ,
	'SELECT TRIM(STRING_AGG(DISTINCT_LIST, '', '')) [Top 10 values] FROM
	(SELECT DISTINCT TOP 10 CONCAT_WS('' ('', <C>, COUNT(<C>)) + '')'' AS DISTINCT_LIST, COUNT(<C>) AS _
		FROM <T>
		WHERE <C> IS NOT NULL
		GROUP BY <C>
		ORDER BY COUNT(<C>) DESC
	) LIST')