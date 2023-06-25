-- DATABASE CREATION

-- CREATING THE DIMENSION TABLES-----------------------------------------------------------------------------------------------------------------------
-- YearDim
create table YearDim (
    year_id int auto_increment primary key
    ) as select distinct
    StartYear
    from cleaned_netflix;

-- CountryDim
create table CountryDim (
country_id int auto_increment primary key
) as select distinct
origin_country
from cleaned_netflix;


-- LanguageDim
create table LanguageDim(
language_id int auto_increment primary key
) as select distinct
language
from cleaned_netflix;

-- ActorDim
create table ActorDim(
actor_id int auto_increment primary key
) as select distinct
lead_actor
from cleaned_netflix;


-- CREATING THE FACT TABLE-----------------------------------------------------------------------------------------------------------------------------
-- FilmFact
CREATE TABLE FilmFact (
    film_id INT AUTO_INCREMENT PRIMARY KEY
) AS SELECT 
	ye.year_id,
    co.country_id,
    ac.actor_id,
    la.language_id,
    cn.imdb_id,
    cn.title,
    cn.popular_rank,
    cn.episodes,
    cn.runtime,
    cn.type,
    cn.plot,
    cn.rating,
    cn.numVotes,
    cn.genres,
    cn.cast FROM
    cleaned_netflix cn 
    cross join YearDim ye on cn.startYear = ye.startyear
    cross join countrydim co on cn.origin_country = co.origin_country
    cross join actordim ac on cn.lead_actor = ac.lead_actor
    cross join languagedim la on cn.language = la.language;
    

-- ADDING FOREIGN KEY CONSTRIANTS---------------------------------------------------------------------------------------------------------------------
alter table FilmFact
add constraint fk_country foreign key (country_id) references countrydim (country_id),
add constraint fk_actor  foreign key (actor_id) references actordim (actor_id),
add constraint fk_language  foreign key (language_id) references languagedim (language_id),
add constraint fk_year foreign key (year_id) references YearDim (year_id);




-- DATA ANALYSIS---------------------------------------------------------------------------------------------------------------------------------------


-- Viewing the fact table
SELECT 
    *
FROM
    filmfact;


-- Different types of film in the database
SELECT DISTINCT
    (type) AS Film_Type
FROM
    filmfact;
    

-- Count of films per type in the database
SELECT 
    type AS Film_Type, COUNT(*) AS 'Number_of_Films'
FROM
    filmfact
GROUP BY type
ORDER BY 2 DESC;


-- Top 5 lead actors per Film count
SELECT 
    lead_actor, COUNT(film_id) as 'Nos_of_Films'
FROM
    actordim ac
        LEFT JOIN
    filmfact ff ON ac.actor_id = ff.actor_id
 GROUP BY 1
 ORDER BY 2 DESC
 LIMIT 5;
 
 
-- Films and their Average runtimes
SELECT 
    title,
    ROUND(AVG(runtime)) AS 'Average_Runtime'
FROM
    filmfact ff
GROUP BY title;

    
-- Count of films per country
SELECT 
    origin_country, COUNT(film_id) AS 'Nos_of_Films'
FROM
    countrydim co
        LEFT JOIN
    filmfact ff ON co.country_id = ff.country_id
GROUP BY origin_country
ORDER BY 2 DESC;

    
-- Most popular film per country in the database 
-- shows the name of the most popular film in each country and the year it was first viewed
SELECT 
    co.origin_country, ff.title, ye.startyear, ff.popular_rank
FROM
    filmfact ff
        INNER JOIN
    countrydim co ON ff.country_id = co.country_id
        INNER JOIN
    yeardim ye ON ff.year_id = ye.year_id
WHERE
    (co.country_id , ff.popular_rank) IN (SELECT 
            country_id, MAX(popular_rank)
        FROM
            filmfact
        GROUP BY country_id)
ORDER BY 1;


-- Top 5 Film Genres by number of films in the database
SELECT 
    CASE
        WHEN genres LIKE 'Action%' THEN 'Action'
        WHEN genres LIKE 'Adventure%' THEN 'Adventure'
        WHEN genres LIKE 'Animation%' THEN 'Animation'
        WHEN genres LIKE 'Biography%' THEN 'Biography'
        WHEN genres LIKE 'Comedy%' THEN 'Comedy'
        WHEN genres LIKE 'Crime%' THEN 'Crime'
        WHEN genres LIKE 'Documentary%' THEN 'Documentary'
        WHEN genres LIKE 'Drama%' THEN 'Drama'
        WHEN genres LIKE 'Family%' THEN 'Family'
        WHEN genres LIKE 'Fantasy%' THEN 'Fantasy'
        WHEN genres LIKE 'Horror%' THEN 'Horror'
        WHEN genres LIKE 'Music%' THEN 'Musical'
        WHEN genres LIKE 'Sci-Fi%' THEN 'Sci-Fi'
        WHEN genres LIKE 'Sport%' THEN 'Sport'
        WHEN genres LIKE 'Romance%' THEN 'Romance'
        ELSE 'Others'
    END AS Film_category,
    COUNT(film_id) as 'Nos_of_Films'
FROM
    filmfact
GROUP BY film_category
ORDER BY 2 DESC limit 5;


-- Most rated films per country
SELECT 
    origin_country, title, rating
FROM
    filmfact ff
        INNER JOIN
    countrydim co ON ff.country_id = co.country_id
WHERE
    (co.country_id , rating) IN (SELECT 
            country_id, MAX(rating)
        FROM
            filmfact
        GROUP BY country_id)
ORDER BY 1; 


-- Total number of films per country per year greater than 50
-- Showing a trend of number of films produced in a year in each country from 1932 till date where annual film production exceeds 50
SELECT 
    startyear, origin_country, COUNT(film_id) 'Nos_of_films'
FROM
    yeardim ye
        INNER JOIN
    filmfact ff ON ye.year_id = ff.year_id
        INNER JOIN
    countrydim co ON ff.country_id = co.country_id
GROUP BY 1,2
HAVING COUNT(film_id) > 50
ORDER BY 1 deSC;
     

-- films with their percentage share of total votes
SELECT 
    imdb_id,
    title,
    numVotes,
    ROUND((numVotes / total_numVotes) * 100, 2) AS percentage_votes
FROM
    filmfact
        CROSS JOIN
    (SELECT 
        SUM(numVotes) AS total_numVotes
    FROM
        filmfact) AS t
ORDER BY percentage_votes DESC;


-- Top 5 longest film
SELECT 
    title, origin_country, runtime AS film_Length
FROM
    filmfact ff
        INNER JOIN
    countrydim co ON ff.country_id = co.country_id
ORDER BY 3 DESC
LIMIT 5;
