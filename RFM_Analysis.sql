/*
RFM Analysis

Skills used: 
- CTEs 
- Temp Tables 
- Windows Functions 
- Aggregate Functions 
- Converting Data Types 

*/


-- Select all columns from the RFM table
SELECT * FROM RFM;


-- Checking unique values
SELECT DISTINCT status FROM RFM;
SELECT DISTINCT year_id FROM RFM;
SELECT DISTINCT PRODUCTLINE FROM RFM; 
SELECT DISTINCT COUNTRY FROM RFM ORDER BY country; 
SELECT DISTINCT DEALSIZE FROM RFM; 
SELECT DISTINCT TERRITORY FROM RFM; 


-- Total Revenue by Product Line
SELECT
    productline,
    SUM(CAST(sales AS FLOAT)) AS Revenue
FROM RFM GROUP BY productline ORDER BY 2 DESC; 


-- 2022 is the year with max revenue
SELECT
    YEAR_ID,
    SUM(CAST(sales AS FLOAT)) AS Revenue
FROM RFM GROUP BY YEAR_ID ORDER BY 2 DESC; 


-- Checking if sales in 2023 had a full year of operations
SELECT DISTINCT month_id FROM RFM
WHERE YEAR_id = 2023; 
-- => Only the first 5 months are available


-- Medium size deals generate the most revenue
SELECT
    DEALSIZE,
    SUM(CAST(sales AS FLOAT)) AS Revenue
FROM RFM GROUP BY DEALSIZE ORDER BY 2 DESC;


-- Best month for RFM in a specific year and the revenue earned
SELECT
    MONTH_ID,
    SUM(CAST(sales AS FLOAT)) AS Revenue,
    COUNT(ORDERNUMBER) AS Frequency
FROM RFM WHERE YEAR_ID = 2022 GROUP BY MONTH_ID ORDER BY 2 DESC; 
-- => November

-- Products sold in November
SELECT
    MONTH_ID,
    PRODUCTLINE,
    SUM(CAST(sales AS FLOAT)) AS Revenue,
    COUNT(ORDERNUMBER)
FROM RFM
WHERE  YEAR_ID = 2022 AND MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE ORDER BY 3 DESC;


-- RFM Analysis
-- Segmentation of customers using three key metrics
SELECT
    CUSTOMERNAME,
    SUM(CAST(sales AS FLOAT)) AS MonetaryValue,
    AVG(CAST(sales AS FLOAT)) AS AvgMonetaryValue,
    COUNT(ORDERNUMBER) AS Frequency,
    MAX(ORDERDATE) AS last_order_date
FROM RFM GROUP BY customername;

--Converting 
UPDATE RFM SET orderdate = CONVERT(NVARCHAR(10), orderdate, 104);

-- Changing column type from datetime to date
ALTER TABLE RFM
ALTER COLUMN orderdate DATE;

-- Recency by CustomerName
SELECT
    CUSTOMERNAME,
    MAX(ORDERDATE) AS Max_OrderDate,
    MAX(ORDERDATE) AS Max_OrderDateTable,
    DATEDIFF(DD, MAX(ORDERDATE), MAX(ORDERDATE)) AS Recency
FROM RFM GROUP BY CUSTOMERNAME;




-- RFM Calculation
WITH rfm AS (
    SELECT
        CUSTOMERNAME,
        SUM(CAST(sales AS FLOAT)) AS MonetaryValue,
        AVG(CAST(sales AS FLOAT)) AS AvgMonetaryValue,
        COUNT(ORDERNUMBER) AS Frequency,
        MAX(ORDERDATE) AS last_order_date,
        MAX(ORDERDATE) AS max_order_date,
        DATEDIFF(DD, MAX(ORDERDATE), MAX(ORDERDATE)) AS Recency
    FROM
        RFM
    GROUP BY
        CUSTOMERNAME
),
rfm_calc AS (
    SELECT
        r.*,
        NTILE(4) OVER (ORDER BY Recency DESC) AS rfm_recency,
        NTILE(4) OVER (ORDER BY Frequency) AS rfm_frequency,
        NTILE(4) OVER (ORDER BY MonetaryValue) AS rfm_monetary
    FROM
        rfm r
)
SELECT * FROM rfm_calc;
    



--creating temporary table
DROP TABLE IF EXISTS #rfm
;with rfm as 
(
	select 
		CUSTOMERNAME, 
		sum(cast(sales as float)) MonetaryValue,
		avg(cast(sales as float)) AvgMonetaryValue,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from RFM) max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from RFM)) Recency
	from RFM
	group by CUSTOMERNAME
),
rfm_calc as
(
	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by MonetaryValue) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency+ rfm_frequency+ rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary  as varchar)rfm_cell_string
into #rfm from rfm_calc c


-- used rfm_cell_string 
select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven't purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment
from #rfm

