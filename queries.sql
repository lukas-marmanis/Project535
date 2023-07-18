--Change cdc from mm/dd/yyyy to yyyy-mm-dd
UPDATE cdc_vaccine
SET Date = substr(main.cdc_vaccine.Date, 7, 4) || '-' || substr(main.cdc_vaccine.Date, 1,2) || '-' || substr(main.cdc_vaccine.Date, 4,2)

-- check update (all good)
SELECT * FROM cdc_vaccine LIMIT 10;



/* columns we are going to keep
date text
fips (we can drop county name) integer
recip_state text
Administered_Dose1_Recip_PCT real
Series Complete real
Booster_Does_vax_pct real
metrostatus text
census2019 integer
 */

DROP TABLE main.model_cdc_vaccine;

CREATE TABLE main.model_cdc_vaccine (
    date TEXT,
    fips INTEGER,
    state TEXT,
    administered_dose1_pct REAL,
    series_complete_pct REAL,
    booster_pct REAL,
    metro_status REAL,
    census_pop_2019 INTEGER
)


-- update columns with data from original

BEGIN TRANSACTION;
INSERT INTO model_cdc_vaccine (date,fips,state,administered_dose1_pct,series_complete_pct,booster_pct,metro_status,census_pop_2019)
SELECT Date, FIPS, Recip_State, Administered_Dose1_Pop_Pct, Series_Complete_Pop_Pct, Booster_Doses_Vax_Pct, metro_status, Census2019
FROM cdc_vaccine;
END TRANSACTION;

--check out new table

SELECT * FROM model_cdc_vaccine ORDER BY date;
--- nyt clean up
SELECT *
FROM nyt_covid
LIMIT 10;

-- convert state name to state initial

UPDATE nyt_covid
SET state =
CASE state
WHEN 'Alabama' THEN 'AL'
WHEN 'Alaska' THEN 'AK'
WHEN 'Arizona' THEN 'AZ'
WHEN 'Arkansas' THEN 'AR'
WHEN 'California' THEN 'CA'
WHEN 'Colorado' THEN 'CO'
WHEN 'Connecticut' THEN 'CT'
WHEN 'Delaware' THEN 'DE'
WHEN 'District of Columbia' THEN 'DC'
WHEN 'Florida' THEN 'FL'
WHEN 'Georgia' THEN 'GA'
WHEN 'Hawaii' THEN 'HI'
WHEN 'Idaho' THEN 'ID'
WHEN 'Illinois' THEN 'IL'
WHEN 'Indiana' THEN 'IN'
WHEN 'Iowa' THEN 'IA'
WHEN 'Kansas' THEN 'KS'
WHEN 'Kentucky' THEN 'KY'
WHEN 'Louisiana' THEN 'LA'
WHEN 'Maine' THEN 'ME'
WHEN 'Maryland' THEN 'MD'
WHEN 'Massachusetts' THEN 'MA'
WHEN 'Michigan' THEN 'MI'
WHEN 'Minnesota' THEN 'MN'
WHEN 'Mississippi' THEN 'MS'
WHEN 'Missouri' THEN 'MO'
WHEN 'Montana' THEN 'MT'
WHEN 'Nebraska' THEN 'NE'
WHEN 'Nevada' THEN 'NV'
WHEN 'New Hampshire' THEN 'NH'
WHEN 'New Jersey' THEN 'NJ'
WHEN 'New Mexico' THEN 'NM'
WHEN 'New York' THEN 'NY'
WHEN 'North Carolina' THEN 'NC'
WHEN 'North Dakota' THEN 'ND'
WHEN 'Ohio' THEN 'OH'
WHEN 'Oklahoma' THEN 'OK'
WHEN 'Oregon' THEN 'OR'
WHEN 'Pennsylvania' THEN 'PA'
WHEN 'Rhode Island' THEN 'RI'
WHEN 'South Carolina' THEN 'SC'
WHEN 'South Dakota' THEN 'SD'
WHEN 'Tennessee' THEN 'TN'
WHEN 'Texas' THEN 'TX'
WHEN 'Utah' THEN 'UT'
WHEN 'Vermont' THEN 'VT'
WHEN 'Virginia' THEN 'VA'
WHEN 'Washington' THEN 'WA'
WHEN 'West Virginia' THEN 'WV'
WHEN 'Wisconsin' THEN 'WI'
WHEN 'Wyoming' THEN 'WY'
WHEN 'Alberta' THEN 'AB'
WHEN 'British Columbia' THEN 'BC'
WHEN 'Manitoba' THEN 'MB'
WHEN 'New Brunswick' THEN 'NB'
WHEN 'Newfoundland and Labrador' THEN 'NL'
WHEN 'Northwest Territories' THEN 'NT'
WHEN 'Nova Scotia' THEN 'NS'
WHEN 'Nunavut' THEN 'NU'
WHEN 'Ontario' THEN 'ON'
WHEN 'Prince Edward Island' THEN 'PE'
WHEN 'Quebec' THEN 'QC'
WHEN 'Saskatchewan' THEN 'SK'
WHEN 'Yukon Territory' THEN 'YT'
ELSE state
END


-- check for any null values

SELECT *
FROM nyt_covid
WHERE date is NULL OR
      county is NULL OR
      state is NULL OR
      fips is NULL OR
      cases is NULL OR
      deaths is NULL;

-- remove unknown county
DELETE FROM nyt_covid WHERE county = 'Unknown';

-- nyc has no fips someplace
UPDATE nyt_covid
SET fips = 36061
WHERE county = 'New York City';

--wyndote and the city of kansas have same fips
UPDATE nyt_covid
SET fips = 20209
WHERE county = 'Kansas City';

-- st.john st. croix and st.thomas are virgin islands VI
UPDATE nyt_covid
SET state = 'VI'
WHERE fips = 78010 OR fips = 78020 or fips = 78030;

-- puerto rico for fips = 720

UPDATE nyt_covid
SET state = 'PR'
WHERE substr(CAST(fips as TEXT),1,2) = '72';

-- set null deaths to 0

UPDATE nyt_covid
SET deaths = 0
WHERE deaths is NULL;

-- update JOPLIn to correct fips

SELECT * FROM nyt_covid WHERE county = 'Joplin';
UPDATE nyt_covid
SET fips = 2937592
WHERE county = 'Joplin';

UPDATE nyt_covid
SET state = 'Mariana Islands'
WHERE fips = 69120 or fips = 69110 or fips = 69100;


-- create a cases/deaths column in nyt_covid dataset for initial visualization

ALTER TABLE nyt_covid
ADD COLUMN cases_per_death REAL;


-- insert values into new column

UPDATE nyt_covid SET cases_per_death = nyt_covid.cases/nyt_covid.deaths;

--check that it worked

SELECT * FROM nyt_covid WHERE deaths > 0 LIMIT 10;

-- change all null values is cases_per_death to just 0.

UPDATE nyt_covid
SET cases_per_death = 0
WHERE cases_per_death is NULL


-- check that it worked

SELECT * FROM nyt_covid LIMIT 10;


-- in the end we are predicting deaths based on cases so keep the following columns:
/*
 date
 state
 fips
 cases
 deaths

so make sure to drop cases_per_deaths before modeling and use deaths as predictor
 */

DROP TABLE combined_table;

CREATE TABLE combined_table AS
SELECT nyt_covid.date as date, nyt_covid.state as state, nyt_covid.fips as fips, cases, deaths,cases_per_death,administered_dose1_pct,series_complete_pct,booster_pct, metro_status,census_pop_2019
FROM nyt_covid LEFT JOIN model_cdc_vaccine
    ON nyt_covid.date = model_cdc_vaccine.date AND
       nyt_covid.fips = model_cdc_vaccine.fips;

SELECT * FROM combined_table LIMIT 10;


SELECT * FROM model_cdc_vaccine ORDER BY date;

-- administered_dose1 series_complete, metrostatus don't get populated till 12/13/2020

--administered_dose1 and series complete can be set to 0 for call dates < 2020-12-13
UPDATE combined_table
SET administered_dose1_pct = 0,
    series_complete_pct = 0
WHERE date < '2020-12-13';

--check to confirm

SELECT * FROM combined_table ORDER BY date DESC;


SELECT * FROM model_cdc_vaccine WHERE booster_pct is not null ORDER BY date;
-- start tracking booster pct 12/15/2021

UPDATE combined_table
SET booster_pct = 0
WHERE date < '2021-12-15';

-- census pop ignores nulls so set census pop to avg cencus pop.
UPDATE combined_table
SET census_pop_2019 = avgPop FROM (
                                      SELECT AVG(census_pop_2019) avgPop, fips
                                      FROM combined_table
                                      GROUP BY fips
) A where combined_table.fips = A.fips;


SELECT * FROM combined_table order by date


-- ok finally deal with metro_status before 2020-12-13
--rationale: group by fips. set the value to max frequent value.

UPDATE combined_table
SET metro_status = status FROM (
    SELECT fips, metro_status as status
    FROM combined_table
    WHERE metro_status = 'Non-metro' OR
          metro_status = 'Metro'
    GROUP BY fips) A
    WHERE A.fips = combined_table.fips;


-- check

SELECT * FROM combined_table order by date


-- check for any other null values.

SELECT *
FROM combined_table
WHERE date is NULL OR
    state is NULL OR
    fips is NULL OR
    cases is NULL OR
    deaths is NULL OR
    cases_per_death is NULL OR
    series_complete_pct is NULL OR
    administered_dose1_pct is NULL OR
    booster_pct is NULL OR
    metro_status is NULL OR
    census_pop_2019 is NULL;


-- delete fips == null cause thats not helpfull.

UPDATE combined_table
SET metro_status = 'Non-metro'
WHERE metro_status is NULL;

-- no vaccine data
DELETE from combined_table WHERE fips = 15001 OR fips = 15003 or fips = 15009 or fips = 25007 or fips = 25019 or
                                 fips = 2937592 or fips = 69110 or fips = 69120 or fips = 25001 or fips = 15005;



DELETE FROM combined_table WHERE administered_dose1_pct is NULL and series_complete_pct is NULL;
-- fix population using http://www.statoids.com/uvi.html
UPDATE combined_table
SET census_pop_2019 = 50601 WHERE fips = 78010;

UPDATE combined_table
SET census_pop_2019 = 4170 WHERE fips = 78020;

UPDATE combined_table
SET census_pop_2019 = 51634 WHERE fips = 78030;

UPDATE combined_table
SET census_pop_2019 = 48220 WHERE fips = 69110;

UPDATE combined_table
SET census_pop_2019 = 3136 WHERE fips = 69120;

UPDATE combined_table
SET census_pop_2019 = 51762 WHERE fips = 2937592;

SELECT * FROM combined_table WHERE fips = 69110;

DELETE FROM combined_table WHERE fips = 2997; -- no data
DELETE FROM combined_table WHERE fips = 2998; -- no data

DELETE FROM combined_table WHERE fips is NULL


SELECT fips, count(*)
FROM combined_table
WHERE administered_dose1_pct is NULL
GROUP BY fips

UPDATE combined_table
SET administered_dose1_pct= avgdose FROM (
                                      SELECT AVG(administered_dose1_pct) avgdose, fips
                                      FROM combined_table
                                      GROUP BY fips
                                  ) A where combined_table.fips = A.fips and administered_dose1_pct is NULL;


SELECT * FROM combined_table LIMIT 10

-- group by year and week

CREATE TABLE combined_weekly AS
SELECT strftime('%Y-%W', date) year_week, state,
       fips,
       AVG(cases) as avg_cases,
       AVG(deaths) as avg_deaths,
       AVG(administered_dose1_pct) as administered_dose1_pct,
       AVG(booster_pct) as booster_pct,
       metro_status,
       census_pop_2019
FROM combined_table
GROUP BY year_week, fips
ORDER BY year_week DESC
