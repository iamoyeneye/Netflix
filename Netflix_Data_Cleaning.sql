-- The first step in the project is to create a schema
create schema netflixDB default character set utf8;

-- The next step is to create a table
CREATE TABLE netflix_not_normalised (
    imdb_id VARCHAR(15) NOT NULL,
    title VARCHAR(150) NOT NULL,
    popular_rank INT,
    certificate VARCHAR(10),
    startYear YEAR,
    endYear YEAR,
    episodes INT,
    runtime varchar(3),
    type VARCHAR(20),
    orign_country VARCHAR(50),
    language VARCHAR(50),
    plot VARCHAR(500),
    rating FLOAT,
    numVotes int,
    genres VARCHAR(40),
    isAdult VARCHAR(2),
    cast VARCHAR(500),
    PRIMARY KEY (imdb_id)
);

-- Loading the dataset--------------------------------------------------------------------------------------------------------------------------------
show variables like 'local_infile';
set global local_infile = 1;
load data local infile '/Users/Ebrahym/Documents/MY PROJECTS/NETFLIX/netflix_list_amend.csv'
into table netflix_not_normalised
fields terminated by ',' 
ignore 1 rows;

-- duplicating the netflix_not_normalised table so as to maintain the original dataset-----------------------------------------------------------------
create table cleaned_netflix as 
(select * from netflix_not_normalised);


-- adding primary key to the cleaned_netflix----------------------------------------------------------------------------------------------------------
alter table cleaned_netflix
add primary key (imdb_id);

-- Checking for duplicates----------------------------------------------------------------------------------------------------------------------------
-- Using the imdb_id as the unique identifier, there is no duplicate if all imdb_id count value  does not exceed 1
SELECT 
    imdb_id, COUNT(*) AS count
FROM
    cleaned_netflix
GROUP BY imdb_id
HAVING count > 1;

-- We now take the columns one after the other for necessary cleaning ---------------------------------------------------------------------------------
-- CERTIFICATE COLUMN
-- Removing the parenthesis in Banned
SELECT 
    *
FROM
    netflix_not_normalised
WHERE
    certificate = '(Banned)'; -- this gives 3 primary keys that were ffected

UPDATE cleaned_netflix 
SET 
    certificate = 'Banned'
WHERE
    imdb_id IN ('tt2049630' , 'tt3654796', 'tt4058426');

-- Merging 'Not Rated' with 'Unrated' in certificate column
SELECT 
    imdb_id
FROM
    netflix_not_normalised
WHERE
    certificate = 'Not Rated'; -- this gives 16 primary keys that were ffected

-- the 16 primary keys were housed in a View --
CREATE VIEW imdb_notrated AS
    SELECT 
        imdb_id
    FROM
        netflix_not_normalised
    WHERE
        certificate = 'Not Rated';

UPDATE cleaned_netflix 
SET 
    certificate = 'Unrated'
WHERE
    imdb_id IN (SELECT 
            imdb_id
        FROM
            imdb_notrated);

-- MISSING VALUES--------------------------------------------------------------------------------------------------------------------------------------
-- Filling the missing values in runtime column with the average runtime value-------------------------------------------------------------------------
-- The affected rows were first housed in a view
CREATE VIEW imdb_runtime_null AS
    SELECT 
        imdb_id
    FROM
        netflix_not_normalised
    WHERE
        runtime IS NULL;

CREATE VIEW runtime_mean AS
    SELECT 
        AVG(runtime)
    FROM
        netflix_not_normalised
    WHERE
        runtime IS NOT NULL;


UPDATE cleaned_netflix 
SET 
    runtime = (SELECT 
            *
        FROM
            runtime_mean)
WHERE
    imdb_id IN (SELECT 
            imdb_id
        FROM
            imdb_runtime_null);


-- Filling the missing values in type column with the mode type-------------------------------------------------------------------------------
-- checking the mode
SELECT 
    type, COUNT(*)
FROM
    cleaned_netflix
GROUP BY type; -- from this query, the mode is 'movie' with a count of 2923

-- checking the imdb_id of the records with missing type values
SELECT 
    imdb_id
FROM
    cleaned_netflix
WHERE
    type = ' '; -- there are 2 records that has null type values (tt14821886 and tt14825954)

UPDATE cleaned_netflix 
SET 
    type = 'movie'
WHERE
    imdb_id IN ('tt14821886' , 'tt14825954'); 

-- Filling the missing values in language column with 'No Record'
-- creating a view to house the imdb_id of those records with missing language values
CREATE VIEW imdb_No_language AS
    SELECT 
        imdb_id
    FROM
        netflix_not_normalised
    WHERE
        language = '-';

UPDATE cleaned_netflix 
SET 
    language = 'No Record'
WHERE
    imdb_id IN (SELECT 
            imdb_id
        FROM
            imdb_No_Language);

-- Filling the missing values in genres column with 'No Record'------------------------------------------------------------------------------------
UPDATE cleaned_netflix 
SET 
    genres = 'No Record'
WHERE
    imdb_id IN (SELECT 
            imdb_id
        FROM
            netflix_not_normalised
        WHERE
            genres = ' ' OR genres IS NULL);

-- AMENDING orign_country COLUMN NAME (origin was misspelt as ORIGN)---------------------------------------------------------------------------------------------
alter table cleaned_netflix
change orign_country origin_country varchar(50);

-- Filling the missing values in origin_country column with the modal value----------------------------------------------------------------------------
SELECT 
    orign_country, COUNT(*)
FROM
    netflix_not_normalised
GROUP BY 1
ORDER BY 2 DESC; -- United states has the highest count of films

UPDATE cleaned_netflix 
SET 
    origin_country = 'United States'
WHERE
    imdb_id IN (SELECT 
            imdb_id
        FROM
            netflix_not_normalised
        WHERE
            orign_country = '-');


-- deleting records where there are missing values in cast column--------------------------------------------------------------------------------------
CREATE VIEW imdb_no_leadActor AS
    SELECT 
        imdb_id
    FROM
        netflix_not_normalised
    WHERE
        cast = '-';

DELETE FROM cleaned_netflix 
WHERE
    imdb_id IN (SELECT 
        *
    FROM
        imdb_no_leadActor);


-- DROPPING IRRELEVANT COLUMNS-------------------------------------------------------------------------------------------------------------------------
-- isadult
SELECT DISTINCT
    (isadult)
FROM
    netflix_not_normalised; -- Dropped because it has just one type of value (i.e all films are rated adult)
    
alter table cleaned_netflix
drop column isadult; 

-- certificate
SELECT 
    certificate, COUNT(*)
FROM
    netflix_not_normalised
GROUP BY certificate; -- Dropped because 4599 out of 7008 (over 65%) records have no value for certificate

alter table cleaned_netflix
drop column certificate;

-- endyear was also dropped because 84% of the total records in the database has no value for endyear
alter table cleaned_netflix
drop column endyear;


-- SPLITTING THE CAST COLUMN---------------------------------------------------------------------------------------------------------------------------
-- first, we remove irrelevant characters found in the cast column and the result saved in the cleaned_cast view
create view cleaned_cast as
select imdb_id,
replace(replace(cast, '"', ''), '  ', ' ') AS cast1
FROM cleaned_netflix;

-- we extracted the first actor name in the cast column to represent the values in the lead_actor column to be created. 
-- This was saved in the extracted_cast view
CREATE VIEW extracted_cast AS
    SELECT 
        imdb_id, TRIM(SUBSTRING_INDEX(cast1, '  ', 1)) AS extracts
    FROM
        cleaned_cast;

CREATE VIEW replaced_extracts AS
    SELECT 
        imdb_id, REPLACE(extracts, ' ', '') AS trimmed_extracts
    FROM
        extracted_cast;


-- identifying the actor's name with the longest length to guide in defining the values in the lead_actor column to be created
SELECT 
    extracts, LENGTH(extracts)
FROM
    extracted_cast
ORDER BY 2 DESC; -- longest length is 35

-- creation of the new lead_actor column
alter table cleaned_netflix
add column lead_actor varchar(50) after genres;


-- temporary deactivation of the sql safe update mode
set sql_safe_updates=0;

-- populating values into the new lead_actor column
UPDATE cleaned_netflix AS cn
        INNER JOIN
    replaced_extracts AS rc ON cn.imdb_id = rc.imdb_id 
SET 
    cn.lead_actor = rc.trimmed_extracts;

-- restoration of the sql safe update mode
set sql_safe_updates=1;





















































	