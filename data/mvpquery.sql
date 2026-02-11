----For this exericse, you'll be working with a database derived from the Medicare Part D Prescriber Public Use File. More information about the data is contained in the Methodology PDF file. See also the included entity-relationship diagram. 
----a. Which prescriber had the highest total number of claims (totaled over all drugs)? Report the npi and the total number of claims.
SELECT
    npi,
    SUM(total_claim_count) AS total_number_of_claims
FROM prescription
GROUP BY npi
ORDER BY total_number_of_claims DESC;

----b. Repeat the above, but this time report the nppes_provider_first_name, nppes_provider_last_org_name, specialty_description, and the total number of claims.
SELECT
    prescriber.nppes_provider_first_name,
    prescriber.nppes_provider_last_org_name,
    prescriber.specialty_description,
    SUM(prescription.total_claim_count) AS total_number_of_claims
FROM prescription
JOIN prescriber
  ON prescription.npi = prescriber.npi
GROUP BY
    prescriber.nppes_provider_first_name,
    prescriber.nppes_provider_last_org_name,
    prescriber.specialty_description
ORDER BY total_number_of_claims DESC;

----2a. Which specialty had the most total number of claims (totaled over all drugs)?
SELECT
    prescriber.specialty_description,
    SUM(prescription.total_claim_count) AS total_number_of_claims
FROM prescription
JOIN prescriber
  ON prescription.npi = prescriber.npi
GROUP BY prescriber.specialty_description
ORDER BY total_number_of_claims DESC
LIMIT 1;

----b. Which specialty had the most total number of claims for opioids?
SELECT specialty_description
	, SUM(total_claim_count) AS total_claims
	from prescription
	INNER JOIN prescriber
	USING(npi)
	INNER JOIN drug
	on prescription.drug_name = drug.drug_name
	WHERE opioid_drug_flag = 'Y'
	GROUP BY specialty_description
	ORDER BY total_claims DESC
LIMIT 1;

----c. Challenge Question: Are there any specialties that appear in the prescriber table that have no associated prescriptions in the prescription table?
SELECT DISTINCT specialty_description
FROM prescriber
EXCEPT
SELECT DISTINCT specialty_description
FROM prescriber
JOIN prescription
USING(npi);

----d. Difficult Bonus: Do not attempt until you have solved all other problems! For each specialty, report the percentage of total claims by that specialty which are for opioids. Which specialties have a high percentage of opioids?
SELECT specialty_description
	, ROUND(SUM(CASE WHEN opioid_drug_flag = 'Y' THEN prescription.total_claim_count END) /
	 SUM(total_claim_count), 3) * 100 AS opioid_percent
	from prescription
	INNER JOIN prescriber
	USING(npi)
	INNER JOIN drug 
	on prescription.drug_name = drug.drug_name
	GROUP BY specialty_description
	ORDER BY opioid_percent DESC NULLS LAST;

----b. Which drug (generic_name) has the hightest total cost per day? Bonus: Round your cost per day column to 2 decimal places. Google ROUND to see how this works.
SELECT
    drug.generic_name,
    ROUND(
        SUM(prescription.total_drug_cost) / SUM(prescription.total_day_supply),
        2
    ) AS cost_per_day
FROM prescription
JOIN drug
  ON prescription.drug_name = drug.drug_name
GROUP BY drug.generic_name
ORDER BY cost_per_day DESC
LIMIT 1;

----4a. For each drug in the drug table, return the drug name and then a column named 'drug_type' which says 'opioid' for drugs which have opioid_drug_flag = 'Y', says 'antibiotic' for those drugs which have antibiotic_drug_flag = 'Y', and says 'neither' for all other drugs. Hint: You may want to use a CASE expression for this. See https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-case/
SELECT
    drug.drug_name,
    CASE
        WHEN drug.opioid_drug_flag = 'Y' THEN 'opioid'
        WHEN drug.antibiotic_drug_flag = 'Y' THEN 'antibiotic'
        ELSE 'neither'
    END AS drug_type
FROM drug;

----b. Building off of the query you wrote for part a, determine whether more was spent (total_drug_cost) on opioids or on antibiotics. Hint: Format the total costs as MONEY for easier comparision.
select
  case
    when d.opioid_drug_flag = 'Y' THEN 'opioid'
    when d.antibiotic_drug_flag = 'Y' THEN 'antibiotic'
  END AS drug_type,
  sum(p.total_drug_cost)::money AS total_spent
FROM drug d
JOIN prescription as p
ON p.drug_name = d.drug_name
WHERE d.opioid_drug_flag = 'Y' OR d.antibiotic_drug_flag = 'Y'
GROUP BY drug_type;

----5.a. How many CBSAs are in Tennessee? Warning: The cbsa table contains information for all states, not just Tennessee.
SELECT COUNT(DISTINCT cbsa) 
FROM cbsa
INNER JOIN fips_county
USING (fipscounty)
WHERE state = 'TN';

----b. Which cbsa has the largest combined population? Which has the smallest? Report the CBSA name and total population.
WITH cbsa_population AS (
    SELECT
        cbsa.cbsaname,
        SUM(population.population) AS total_population
    FROM cbsa
    JOIN population
      ON cbsa.fipscounty = population.fipscounty
    GROUP BY cbsa.cbsaname
)
SELECT *
FROM cbsa_population
WHERE total_population = (SELECT MAX(total_population) FROM cbsa_population)
   OR total_population = (SELECT MIN(total_population) FROM cbsa_population);

----c. What is the largest (in terms of population) county which is not included in a CBSA? Report the county name and population.
SELECT
    fips_county.county,
    population.population
FROM population
LEFT JOIN cbsa
  ON population.fipscounty = cbsa.fipscounty
JOIN fips_county
  ON population.fipscounty = fips_county.fipscounty
WHERE cbsa.fipscounty IS NULL
ORDER BY population.population DESC
LIMIT 1;

----6a. Find all rows in the prescription table where total_claims is at least 3000. Report the drug_name and the total_claim_count.
SELECT
    prescription.drug_name,
    prescription.total_claim_count
FROM prescription
WHERE prescription.total_claim_count >= 3000;

----b. For each instance that you found in part a, add a column that indicates whether the drug is an opioid.
SELECT
    prescription.drug_name,
    prescription.total_claim_count,
    CASE
        WHEN drug.opioid_drug_flag = 'Y' THEN 'opioid'
        ELSE 'not opioid'
    END AS drug_type
FROM prescription
JOIN drug
  ON prescription.drug_name = drug.drug_name
WHERE prescription.total_claim_count >= 3000;

----c. Add another column to you answer from the previous part which gives the prescriber first and last name associated with each row.
SELECT
    prescription.drug_name,
    prescription.total_claim_count,
    CASE
        WHEN drug.opioid_drug_flag = 'Y' THEN 'opioid'
        ELSE 'not opioid'
    END AS drug_type,
    prescriber.nppes_provider_first_name,
    prescriber.nppes_provider_last_org_name
FROM prescription
JOIN drug
  ON prescription.drug_name = drug.drug_name
JOIN prescriber
  ON prescription.npi = prescriber.npi
WHERE prescription.total_claim_count >= 3000
ORDER BY prescription.total_claim_count DESC;

----The goal of this exercise is to generate a full list of all pain management specialists in Nashville and the number of claims they had for each opioid. Hint: The results from all 3 parts will have 637 rows.
----7a. First, create a list of all npi/drug_name combinations for pain management specialists (specialty_description = 'Pain Management) in the city of Nashville (nppes_provider_city = 'NASHVILLE'), where the drug is an opioid (opiod_drug_flag = 'Y'). Warning: Double-check your query before running it. You will only need to use the prescriber and drug tables since you don't need the claims numbers yet.
SELECT *
FROM prescriber
CROSS JOIN drug
WHERE prescriber.specialty_description = 'Pain Management'
  AND prescriber.nppes_provider_city = 'NASHVILLE'
  AND drug.opioid_drug_flag = 'Y'
ORDER BY prescriber.npi, drug.drug_name;

----b. Next, report the number of claims per drug per prescriber. Be sure to include all combinations, whether or not the prescriber had any claims. You should report the npi, the drug name, and the number of claims (total_claim_count).
WITH prescriber_drug_combinations AS (
    SELECT
        prescriber.npi,
        drug.drug_name
    FROM prescriber
    CROSS JOIN drug
    WHERE prescriber.specialty_description = 'Pain Management'
      AND prescriber.nppes_provider_city = 'NASHVILLE'
      AND drug.opioid_drug_flag = 'Y'
)
SELECT
    prescriber_drug_combinations.npi,
    prescriber_drug_combinations.drug_name,
    prescription.total_claim_count
FROM prescriber_drug_combinations
LEFT JOIN prescription
  ON prescriber_drug_combinations.npi = prescription.npi
 AND prescriber_drug_combinations.drug_name = prescription.drug_name
ORDER BY prescriber_drug_combinations.npi, prescriber_drug_combinations.drug_name;

----c. Finally, if you have not done so already, fill in any missing values for total_claim_count with 0. Hint - Google the COALESCE function.
SELECT npi
	, drug_name
	, COALESCE(total_claim_count, 0) as total_claims
	FROM prescriber
	CROSS JOIN drug
	LEFT JOIN prescription
	USING(npi, drug_name)
	WHERE specialty_description = 'Pain Management'
		AND nppes_provider_city = 'NASHVILLE'
		AND opioid_drug_flag = 'Y'
	ORDER BY total_claims DESC;