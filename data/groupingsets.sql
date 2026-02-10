----For this exericse, you'll be working with a database derived from the Medicare Part D Prescriber Public Use File. More information about the data is contained in the Methodology PDF file. See also the included entity-relationship diagram.
----a. Which prescriber had the highest total number of claims (totaled over all drugs)? Report the npi and the total number of claims.
SELECT
    prescriber.specialty_description,
    SUM(prescription.total_claim_count) AS total_claims
FROM prescriber
JOIN prescription
  ON prescriber.npi = prescription.npi
WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY prescriber.specialty_description
ORDER BY prescriber.specialty_description;

----Now, let's say that we want our output to also include the total number of claims between these two groups. Combine two queries with the UNION keyword to accomplish this. Your output should look like this
SELECT *
FROM (
    -- individual + total
    SELECT
        prescriber.specialty_description,
        SUM(prescription.total_claim_count) AS total_claims
    FROM prescriber
    JOIN prescription
      ON prescriber.npi = prescription.npi
    WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
    GROUP BY prescriber.specialty_description

    UNION ALL

    SELECT
        'TOTAL' AS specialty_description,
        SUM(prescription.total_claim_count) AS total_claims
    FROM prescriber
    JOIN prescription
      ON prescriber.npi = prescription.npi
    WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
) AS combined
ORDER BY
    CASE WHEN specialty_description = 'TOTAL' THEN 0 ELSE 1 END,
    specialty_description;

----Now, instead of using UNION, make use of GROUPING SETS (https://www.postgresql.org/docs/10/queries-table-expressions.html#QUERIES-GROUPING-SETS) to achieve the same output.
SELECT 
    COALESCE(prescriber.specialty_description, 'TOTAL') AS specialty_description,
    SUM(prescription.total_claim_count) AS total_claims
FROM prescriber
JOIN prescription 
  ON prescriber.npi = prescription.npi
WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY GROUPING SETS (
    (prescriber.specialty_description), 
    ()
)
ORDER BY (prescriber.specialty_description IS NULL) DESC, specialty_description;

----In addition to comparing the total number of prescriptions by specialty, let's also bring in information about the number of opioid vs. non-opioid claims by these two specialties. Modify your query (still making use of GROUPING SETS so that your output also shows the total number of opioid claims vs. non-opioid claims by these two specialites
SELECT
    prescriber.specialty_description,
    drug.opioid_drug_flag,
    SUM(prescription.total_claim_count) AS total_claims
FROM prescriber
JOIN prescription
  ON prescriber.npi = prescription.npi
JOIN drug 
  ON prescription.drug_name = drug.drug_name
WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY GROUPING SETS (
    (),                          
    (drug.opioid_drug_flag),
    (prescriber.specialty_description)
)
ORDER BY 
    (prescriber.specialty_description IS NULL AND drug.opioid_drug_flag IS NULL) DESC,
    (prescriber.specialty_description IS NULL) DESC,
    drug.opioid_drug_flag DESC,
    prescriber.specialty_description DESC;

----Modify your query by replacing the GROUPING SETS with ROLLUP(opioid_drug_flag, specialty_description). How is the result different from the output from the previous query?
SELECT
    prescriber.specialty_description,
    drug.opioid_drug_flag,
    SUM(prescription.total_claim_count) AS total_claims
FROM prescriber
JOIN prescription
  ON prescriber.npi = prescription.npi
JOIN drug 
  ON prescription.drug_name = drug.drug_name
WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY ROLLUP(drug.opioid_drug_flag, prescriber.specialty_description)
ORDER BY 
    (prescriber.specialty_description IS NULL AND drug.opioid_drug_flag IS NULL) DESC,
    (prescriber.specialty_description IS NULL) DESC,
    drug.opioid_drug_flag DESC,
    prescriber.specialty_description DESC;

----Switch the order of the variables inside the ROLLUP. That is, use ROLLUP(specialty_description, opioid_drug_flag). How does this change the result?
SELECT
    prescriber.specialty_description,
    drug.opioid_drug_flag,
    SUM(prescription.total_claim_count) AS total_claims
FROM prescriber
JOIN prescription
  ON prescriber.npi = prescription.npi
JOIN drug 
  ON prescription.drug_name = drug.drug_name
WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY ROLLUP(prescriber.specialty_description, drug.opioid_drug_flag)
ORDER BY 
    (prescriber.specialty_description IS NULL AND drug.opioid_drug_flag IS NULL) DESC,
    (drug.opioid_drug_flag IS NULL) DESC,
    prescriber.specialty_description DESC,
    drug.opioid_drug_flag DESC;

----Finally, change your query to use the CUBE function instead of ROLLUP. How does this impact the output?
SELECT
    prescriber.specialty_description,
    drug.opioid_drug_flag,
    SUM(prescription.total_claim_count) AS total_claims
FROM prescriber
JOIN prescription
  ON prescriber.npi = prescription.npi
JOIN drug 
  ON prescription.drug_name = drug.drug_name
WHERE prescriber.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY CUBE(prescriber.specialty_description, drug.opioid_drug_flag)
ORDER BY 
    (prescriber.specialty_description IS NULL AND drug.opioid_drug_flag IS NULL) DESC,
    (prescriber.specialty_description IS NULL) DESC,
    prescriber.specialty_description DESC,
    drug.opioid_drug_flag DESC;

----In this question, your goal is to create a pivot table showing for each of the 4 largest cities in Tennessee (Nashville, Memphis, Knoxville, and Chattanooga), the total claim count for each of six common types of opioids: Hydrocodone, Oxycodone, Oxymorphone, Morphine, Codeine, and Fentanyl. For the purpose of this question, we will put a drug into one of the six listed categories if it has the category name as part of its generic name. For example, we could count both of "ACETAMINOPHEN WITH CODEINE" and "CODEINE SULFATE" as being "CODEINE" for the purposes of this question. The end result of this question should be a table formatted like this.
CREATE EXTENSION IF NOT EXISTS tablefunc;
SELECT *
FROM crosstab(
    'SELECT 
        nppes_provider_city,
        CASE 
            WHEN d.generic_name LIKE ''%CODEINE%'' THEN ''codeine''
            WHEN d.generic_name LIKE ''%FENTANYL%'' THEN ''fentanyl''
            WHEN d.generic_name LIKE ''%HYDROCODONE%'' THEN ''hydrocodone''
            WHEN d.generic_name LIKE ''%MORPHINE%'' THEN ''morphine''
            WHEN d.generic_name LIKE ''%OXYCODONE%'' THEN ''oxycodone''
            WHEN d.generic_name LIKE ''%OXYMORPHONE%'' THEN ''oxymorphone''
        END AS drug_label,
        SUM(p.total_claim_count)::numeric
    FROM prescriber pr
    JOIN prescription p ON pr.npi = p.npi
    JOIN drug d ON p.drug_name = d.drug_name
    WHERE nppes_provider_city IN (''NASHVILLE'', ''MEMPHIS'', ''KNOXVILLE'', ''CHATTANOOGA'')
      AND (d.generic_name LIKE ''%CODEINE%'' 
           OR d.generic_name LIKE ''%FENTANYL%'' 
           OR d.generic_name LIKE ''%HYDROCODONE%'' 
           OR d.generic_name LIKE ''%MORPHINE%'' 
           OR d.generic_name LIKE ''%OXYCODONE%'' 
           OR d.generic_name LIKE ''%OXYMORPHONE%'')
    GROUP BY 1, 2
    ORDER BY 1, 2',

    'VALUES (''codeine''), (''fentanyl''), (''hydrocodone''), (''morphine''), (''oxycodone''), (''oxymorphone'')'
) AS final_result (
    city TEXT,
    codeine NUMERIC,
    fentanyl NUMERIC,
    hydrocodone NUMERIC,
    morphine NUMERIC,
    oxycodone NUMERIC,
    oxymorphone NUMERIC
);