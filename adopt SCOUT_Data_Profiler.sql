/*
Copyright 2021 SCOUT
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

DROP PROCEDURE IF EXISTS [SCOUT].[SCOUTS_Data_Profiler]
DROP TYPE IF EXISTS [SCOUT].[Templates]
DROP SCHEMA IF EXISTS [SCOUT]
GO
CREATE SCHEMA SCOUT
GO

CREATE TYPE SCOUT.Templates AS TABLE 
(
	[NAME] NVARCHAR(32), TEMPLATE NVARCHAR(1024)
)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Copyright 2021 SCOUT
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--     http://www.apache.org/licenses/LICENSE-2.0
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Author:      SCOUT
-- Description: SP version of the data profiler
-- =============================================
CREATE PROCEDURE [SCOUT].[SCOUTS_Data_Profiler]
(
    @DATABASE AS NVARCHAR(32),
    @SCHEMA AS NVARCHAR(32),
	@TABLE AS NVARCHAR(64),
	@TEMPLATES_AS_REF AS Templates READONLY
)
AS
BEGIN

    SET NOCOUNT ON

DECLARE @TARGET_OBJECTS TABLE (ID INT, TABLE_FULL_NAME NVARCHAR(128), COLUMN_FULL_NAME NVARCHAR(128));

DROP TABLE IF EXISTS #OBJECT_META_DATA
SELECT 
	ROW_NUMBER() OVER (ORDER BY TABLE_CATALOG) ID,
	TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, DATETIME_PRECISION
	INTO #OBJECT_META_DATA
	FROM 
	INFORMATION_SCHEMA.COLUMNS

INSERT INTO @TARGET_OBJECTS
SELECT
	ID,
	CONCAT_WS('.', QUOTENAME(TABLE_CATALOG), QUOTENAME(TABLE_SCHEMA), QUOTENAME(TABLE_NAME)) AS TABLE_FULL_NAME,
	CONCAT_WS('.', QUOTENAME(TABLE_CATALOG), QUOTENAME(TABLE_SCHEMA), QUOTENAME(TABLE_NAME), QUOTENAME(COLUMN_NAME)) AS COLUMN_FULL_NAME
	FROM #OBJECT_META_DATA 
	WHERE TABLE_CATALOG = @DATABASE AND TABLE_SCHEMA = @SCHEMA AND TABLE_NAME = @TABLE

DROP TABLE IF EXISTS #PROFILE_STATEMENTS
SELECT 
	ROW_NUMBER() OVER (ORDER BY TargetObj.ID) Row_Num,
	TargetObj.ID, Templ_Ref.NAME AS ProfileName, ObjMetaData.DATA_TYPE, ObjMetaData.TABLE_NAME, ObjMetaData.TABLE_SCHEMA, ObjMetaData.COLUMN_NAME,
	REPLACE(REPLACE(Templ_Ref.TEMPLATE, '<T>', TargetObj.TABLE_FULL_NAME), '<C>', TargetObj.COLUMN_FULL_NAME) AS D_SQL
	INTO #PROFILE_STATEMENTS
	FROM @TARGET_OBJECTS TargetObj
	LEFT JOIN #OBJECT_META_DATA ObjMetaData ON TargetObj.ID = ObjMetaData.ID
	CROSS JOIN @TEMPLATES_AS_REF Templ_Ref

---------------BEGIN Profiling----------------------
DROP TABLE IF EXISTS #PROFILE
CREATE TABLE #PROFILE 
	(ID INT
	,TableName NVARCHAR(255)
	,SchemaName NVARCHAR(255)
	,ColumnName NVARCHAR(255)
	,DataType NVARCHAR(32)
	,ProfileName NVARCHAR(32)
	,Result NVARCHAR(4000))

DECLARE @D_SQL AS NVARCHAR(2048)
DECLARE @RESULT AS NVARCHAR(MAX)

DECLARE @NEXT AS INT
DECLARE @END AS INT

SET @NEXT = (SELECT MIN(Row_Num) FROM #PROFILE_STATEMENTS)
SET @END = (SELECT MAX(Row_Num) FROM #PROFILE_STATEMENTS)

WHILE @NEXT <= @END
BEGIN
	
	SET @D_SQL = (SELECT D_SQL FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT)

	INSERT INTO #PROFILE
		(ID, TableName,	SchemaName,	ColumnName,	DataType, ProfileName, Result)
		VALUES
		(
			(SELECT ID FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT),
			(SELECT TABLE_NAME FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT),
			(SELECT TABLE_SCHEMA FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT),
			(SELECT COLUMN_NAME FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT),
			(SELECT DATA_TYPE FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT),
			(SELECT ProfileName FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT),
			NULL
		)
	
	SET @D_SQL =
		'UPDATE #PROFILE
			SET Result = ( ' + @D_SQL + ' )
			WHERE 
				ID = (SELECT ID FROM #PROFILE_STATEMENTS 
				WHERE Row_Num = ' + CONVERT(NVARCHAR, @NEXT) + ')
			AND ProfileName = (SELECT ProfileName FROM #PROFILE_STATEMENTS
				WHERE Row_Num = ' + CONVERT(NVARCHAR, @NEXT) + ')'
	
	BEGIN TRY
		EXEC(@D_SQL)
	END TRY
	BEGIN CATCH
		UPDATE #PROFILE SET Result = N'N/A' 
			WHERE ID = (SELECT ID FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT) 
			AND ProfileName = (SELECT ProfileName FROM #PROFILE_STATEMENTS WHERE Row_Num = @NEXT)
	END CATCH
	SET @NEXT = (SELECT MIN(Row_Num) FROM #PROFILE_STATEMENTS WHERE Row_Num > @NEXT)
END

---------------END Profiling------------------
---------------Result-------------------------
DECLARE @COLUMNS AS NVARCHAR(4000) = ''
SELECT @COLUMNS += QUOTENAME(ProfileName) + ',' FROM (SELECT DISTINCT ProfileName FROM #PROFILE) DistinctProfileName

SET @COLUMNS = LEFT(@COLUMNS, LEN(@COLUMNS) -1)

DECLARE @PVT_SQL AS NVARCHAR(4000) =
'SELECT * FROM
(
	SELECT [ID], [TableName], [SchemaName], [ColumnName], [DataType], [ProfileName], [Result] FROM #PROFILE
) AS [Profile]
PIVOT(
	MAX(Result)
	FOR ProfileName IN ( ' + @COLUMNS + ' )) AS Pvt
'
EXEC(@PVT_SQL)

END
GO
