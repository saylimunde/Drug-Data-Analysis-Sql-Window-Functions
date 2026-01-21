use drug;

-- 1. For each condition, what is the average satisfaction level of drugs that are "On Label" vs "Off Label"?

SELECT 
    `Condition`,
    Indication,
    ROUND(AVG(Satisfaction), 2) AS avg_satisfaction
FROM drug_clean
WHERE Indication IN ('On Label', 'Off Label')
GROUP BY `Condition`, Indication
ORDER BY `Condition`, Indication;
 
 
 -- 2.For each drug type (RX, OTC, RX/OTC), what is the average ease of use and 
 -- satisfaction level of drugs with a price above the median for their type?
 

WITH ranked_prices AS (
    SELECT
        drug_type,
        Price,
        EaseOfUse,
        Satisfaction,
        ROW_NUMBER() OVER (PARTITION BY drug_type ORDER BY price) AS rn,
        COUNT(*) OVER (PARTITION BY drug_type) AS cnt
    FROM drug_clean
),
median_price AS (
    SELECT
        drug_type,
        AVG(Price) AS median_price
    FROM ranked_prices
    WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
    GROUP BY drug_type
)
SELECT
    d.drug_type,
    ROUND(AVG(d.EaseOfUse), 2) AS avg_ease_of_use,
    ROUND(AVG(d.Satisfaction), 2) AS avg_satisfaction
FROM drug_clean d
JOIN median_price m
    ON d.drug_type = m.drug_type
WHERE d.Price > m.median_price
GROUP BY d.drug_type
ORDER BY d.drug_type;

 
 
 ALTER TABLE drug
 RENAME COLUMN Type to drug_type;

ALTER TABLE drug_clean
CHANGE `Condition` drug_condition VARCHAR(100);


ALTER TABLE drug_clean
CHANGE `Type` drug_type VARCHAR(100);
 
-- 3 .What is the cumulative distribution of EaseOfUse ratings for each drug type (RX, OTC, RX/OTC)? 
-- Show the results in descending order by drug type and cumulative distribution. 
-- (Use the built-in method and the manual method by calculating on your own. For the manual method, 
-- use the "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW" and 
-- see if you get the same results as the built-in method.)

with agg as
(
select drug_type,sum(EaseOfUse) as total_ease from drug_clean
group by drug_type
)
select drug_type,total_ease ,
sum(total_ease) over(order by total_ease desc ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total
from agg;

-- 4. What is the median satisfaction level for each medical condition? 
-- Show the results in descending order by median satisfaction level. 
-- (Don't repeat the same rows of your result.)


with median as(
select drug_condition,Satisfaction,
row_number() over(partition by drug_condition order by Satisfaction) as rn,
count(*) over(partition by drug_condition) as cnt
from drug_clean
),
median_level as 
(
select drug_condition,avg(Satisfaction) as median_satisfaction
from median
 WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
    GROUP BY drug_condition
)
select drug_condition,median_satisfaction
from median_level
order by median_satisfaction desc;


--  What is the running average of the price of drugs for each medical condition? 
-- Show the results in ascending order by medical condition and drug name.

select drug_condition,Drug,
round(avg(Price) over(partition by drug_condition order by drug_condition,Drug 
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) as running_avg_satisfaction
from drug_clean;

-- What is the percentage change in the number of reviews for each drug between the previous row and the current row? 
-- Show the results in descending order by percentage change.

select drug_condition,Drug,Reviews,
(Reviews - lag(Reviews) over(partition by drug_condition,Drug order by Reviews desc)) * 100/
lag(Reviews) over(partition by drug_condition,Drug order by Reviews desc) as pct_change from drug_clean
order by pct_change desc;


-- What is the percentage of total satisfaction level for each drug type (RX, OTC, RX/OTC)? 
-- Show the results in descending order by drug type and percentage of total satisfaction.

with temp_df as
(select Drug,drug_type,sum(Satisfaction) over(partition by drug_type order by Drug desc)*100/sum(Satisfaction) over() as total_satisfaction
from drug where drug_type in ('RX','OTC','RX/OTC') order by drug_type asc ,total_satisfaction desc)
select drug_type,total_satisfaction from temp_df;


-- What is the cumulative sum of effective ratings for each medical condition and drug form combination? 
-- Show the results in ascending order by medical condition, drug form and the name of the drug.

select drug_condition,
Form,
Effective,
sum(Effective) over(partition by drug_condition ,Form order by drug_condition asc ,Form asc,Drug asc
rows between unbounded preceding and current row) as cum_sum from drug_clean;

-- What is the rank of the average ease of use for each drug type (RX, OTC, RX/OTC)? 
-- Show the results in descending order by rank and drug type.

select drug_type,avg(EaseOfUse),
rank() over(order by avg(EaseOfUse) desc) as rank_of_ease from drug
where drug_type in ('RX','OTC','RX/OTC')
group by drug_type;

-- For each condition, what is the average effectiveness of the top 3 most reviewed drugs?

ALTER TABLE drug
CHANGE `Condition` drug_condition VARCHAR(100);  

 select t.drug_condition,t.drug,effectiveness,rn from (select drug_condition,Drug,
 avg(Effective) as effectiveness ,
 row_number() over(partition by drug_condition order by sum(Reviews))  as rn from
 drug
 group by drug_condition,Drug) t
 where rn <= 3
 order by drug_condition,rn
 

