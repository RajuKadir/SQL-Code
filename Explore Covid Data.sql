/*
Source: Covid 19 Data - ourworldindata.org 

Skills used: Joins, CTE's, Temp Tables, Create Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types
*/

--Check the raw data

SELECT *
FROM PortfolioProject..CovidDeathsRaw
ORDER BY 3,4

SELECT *
FROM PortfolioProject..CovidVacsRaw
ORDER BY 3,4

-- Select the data and create a new Covid Deaths Table (Remove North Korea as reported numbers aren't showing correctly)

SELECT Continent,
       Location,
       Date,
       ISNULL(Total_Cases,0) as Total_Cases,
       ISNULL(New_Cases,0) as New_Cases,
	   ISNULL(New_Deaths,0) as New_Deaths,
       ISNULL(Total_Deaths,0) as Total_Deaths,
       Population
INTO PortfolioProject..CovidDeathsUpdated
FROM PortfolioProject..CovidDeathsRaw
WHERE Continent is not null AND Population is not null AND Location <> 'North Korea'
  
-- Looking at Countries Total Cases vs Total Deaths

SELECT Location,
       Date,
       Total_Cases,
       Total_Deaths,
       ISNULL((NULLIF(Total_Deaths,0) / NULLIF(Total_Cases,0)),0) * 100 AS DeathPerc
FROM PortfolioProject..CovidDeathsUpdated
ORDER BY 1,2
  
-- Looking at Countries Total Cases vs Population

SELECT Location,
       Date,
       Total_Cases,
       Population,
       ISNULL((NULLIF(Total_Cases,0) / Population),0) * 100 AS PopulationPerc
FROM PortfolioProject..CovidDeathsUpdated
ORDER BY 1,2
  
-- Looking at the Highest Countries Total Cases compared to Population

SELECT Location,
       Population,
       MAX(Total_Cases) AS TotalCasesCount,
       MAX((Total_Cases / Population)) * 100 AS MaxPopulationPerc
FROM PortfolioProject..CovidDeathsUpdated
GROUP BY Location,
         Population
ORDER BY MaxPopulationPerc DESC
  
-- Looking at Countries Highest Death Count

SELECT Location,
       MAX(CAST(Total_Deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeathsUpdated
GROUP BY Location
ORDER BY TotalDeathCount DESC
  
-- Looking at Continents Highest Death Count

SELECT Continent,
       MAX(CAST(Total_Deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeathsUpdated
GROUP BY Continent
ORDER BY TotalDeathCount DESC
  
-- Global Numbers
0
SELECT Date,
       SUM(New_Cases) as TotalCases,
       SUM(CAST(New_Deaths as int)) as TotalDeaths,
       ISNULL(NULLIF(SUM(CAST(New_Deaths as int)),0) / NULLIF(SUM(New_Cases),0),0) * 100 as DeathPerc
FROM PortfolioProject..CovidDeathsUpdated
GROUP BY Date
ORDER BY 1,2

-- Join Covid Deaths data and Vaccinations data

SELECT dea.*,
       ISNULL(vac.New_Vaccinations,0) AS New_Vaccinations
FROM PortfolioProject..CovidDeathsUpdated dea
    Join PortfolioProject..CovidVacsRaw vac
        on dea.Location = vac.Location
           and dea.Date = vac.Date
  
-- Looking  at Total Population vs Vaccinations

SELECT dea.Location,
       dea.Date,
       dea.Population,
       ISNULL(vac.New_Vaccinations,0) AS New_Vaccinations,
       ISNULL(SUM(CAST(vac.New_Vaccinations as bigint)) OVER (Partition by dea.Location Order by dea.Location, dea.Date),0) as RollingVac
FROM PortfolioProject..CovidDeathsUpdated dea
    Join PortfolioProject..CovidVacsRaw vac
        on dea.Location = vac.Location
           and dea.Date = vac.Date
ORDER BY 1,2,3

-- Use CTE to perform Calculation on Partition By in previous query

WITH PopVsVac (Location, Date, Population, New_Vaccinations, RollingVac)
AS (SELECT dea.Location,
           dea.Date,
           dea.Population,
           ISNULL(vac.New_Vaccinations,0) AS New_Vaccinations,
           ISNULL(SUM(CAST(vac.New_Vaccinations as bigint)) OVER (Partition by dea.Location Order by dea.Location, dea.Date),0) AS RollingVac
    FROM PortfolioProject..CovidDeathsUpdated dea
        Join PortfolioProject..CovidVacsRaw vac
            ON dea.Location = vac.Location
               and dea.Date = vac.Date
   )
SELECT *,
       ISNULL((RollingVac / Population),0) * 100 AS PerPopVac
FROM PopVsVac

-- Using Temp Table to perform Calculation on Partition By in previous query

DROP TABLE IF exists #PercPopVac
CREATE TABLE #PercPopVac
(
    Location nvarchar(255),
    Date datetime,
    Population numeric,
    New_vaccinations numeric,
    RollingVaccinated numeric
)
INSERT INTO #PercPopVac
SELECT dea.Location,
       dea.Date,
       dea.Population,
       ISNULL(vac.New_Vaccinations,0) AS New_Vaccinations,
       ISNULL(SUM(CONVERT(bigint, vac.New_Vaccinations)) OVER (Partition by dea.Location Order by dea.Location, dea.Date),0) AS RollingVac
FROM PortfolioProject..CovidDeathsUpdated dea
    Join PortfolioProject..CovidVacsRaw vac
        on dea.Location = vac.Location
           and dea.Date = vac.Date
SELECT *,
       ISNULL((RollingVaccinated / Population),0) * 100 AS PerPopVac
FROM #PercPopVac



-- Creating Views to store data for visualisations (Create Calculations in Power BI DAX) 

CREATE VIEW CovidDeathsAndVaccData AS
SELECT dea.*,
       ISNULL(vac.New_Vaccinations,0) AS New_Vaccinations
FROM PortfolioProject..CovidDeathsUpdated dea
    Join PortfolioProject..CovidVacsRaw vac
        on dea.Location = vac.Location
           and dea.Date = vac.Date