-- Query 1: Total Sales by Store
SELECT
    st.StoreKey,
    st.Country,
    st.State,
    SUM(sa.Quantity) AS TotalUnitsSold,
    ROUND(SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange), 2) AS TotalRevenueUSD
FROM Sales sa
JOIN Stores st ON sa.StoreKey = st.StoreKey
JOIN Products p ON sa.ProductKey = p.ProductKey
JOIN ExchangeRates er ON sa.CurrencyCode = er.Currency
    AND sa.OrderDate = er.ExchangeDate
WHERE sa.StoreKey != 0
GROUP BY st.StoreKey, st.Country, st.State
ORDER BY TotalRevenueUSD DESC;

-- Query 2: Ranking Stores by Revenue
SELECT
    st.StoreKey,
    st.Country,
    st.State,
    ROUND(SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange), 2) AS TotalRevenueUSD,
    RANK() OVER (ORDER BY SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange) DESC) AS RevenueRank
FROM Sales sa
JOIN Stores st ON sa.StoreKey = st.StoreKey
JOIN Products p ON sa.ProductKey = p.ProductKey
JOIN ExchangeRates er ON sa.CurrencyCode = er.Currency
    AND sa.OrderDate = er.ExchangeDate
WHERE sa.StoreKey != 0
GROUP BY st.StoreKey, st.Country, st.State
ORDER BY RevenueRank;

-- Query 3: Store Size vs. Sales Comparison (CTE)
WITH StoreSales AS (
    SELECT
        st.StoreKey,
        st.Country,
        st.State,
        st.SquareMeters,
        ROUND(SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange), 2) AS TotalRevenueUSD
    FROM Sales sa
    JOIN Stores st ON sa.StoreKey = st.StoreKey
    JOIN Products p ON sa.ProductKey = p.ProductKey
    JOIN ExchangeRates er ON sa.CurrencyCode = er.Currency
        AND sa.OrderDate = er.ExchangeDate
    WHERE sa.StoreKey != 0
    GROUP BY st.StoreKey, st.Country, st.State, st.SquareMeters
)
SELECT
    StoreKey,
    Country,
    State,
    SquareMeters,
    TotalRevenueUSD
FROM StoreSales
ORDER BY TotalRevenueUSD DESC;

-- Query 4: Stored Procedure - Store Performance Classification
DROP PROCEDURE IF EXISTS ClassifyStorePerformance;
GO
CREATE PROCEDURE ClassifyStorePerformance
AS
BEGIN
    DECLARE @AvgRevenue FLOAT

    SELECT @AvgRevenue = AVG(TotalRevenue)
    FROM (
        SELECT SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange) AS TotalRevenue
        FROM Sales sa
        JOIN Stores st ON sa.StoreKey = st.StoreKey
        JOIN Products p ON sa.ProductKey = p.ProductKey
        JOIN ExchangeRates er ON sa.CurrencyCode = er.Currency
            AND sa.OrderDate = er.ExchangeDate
        WHERE sa.StoreKey != 0
        GROUP BY st.StoreKey
    ) AS StoreRevenues

    SELECT
        PerformanceCategory,
        COUNT(*) AS NumberOfStores,
        ROUND(SUM(TotalRevenueUSD), 2) AS TotalRevenueUSD
    FROM (
        SELECT
            st.StoreKey,
            ROUND(SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange), 2) AS TotalRevenueUSD,
            CASE
                WHEN SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange) >= @AvgRevenue * 1.5 THEN 'High Performer'
                WHEN SUM(sa.Quantity * p.UnitPriceUSD * er.Exchange) >= @AvgRevenue THEN 'Medium Performer'
                ELSE 'Low Performer'
            END AS PerformanceCategory
        FROM Sales sa
        JOIN Stores st ON sa.StoreKey = st.StoreKey
        JOIN Products p ON sa.ProductKey = p.ProductKey
        JOIN ExchangeRates er ON sa.CurrencyCode = er.Currency
            AND sa.OrderDate = er.ExchangeDate
        WHERE sa.StoreKey != 0
        GROUP BY st.StoreKey
    ) AS StoreCategories
    GROUP BY PerformanceCategory
    ORDER BY TotalRevenueUSD DESC
END
GO

EXEC ClassifyStorePerformance;


