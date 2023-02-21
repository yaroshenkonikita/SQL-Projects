WITH RECURSIVE 
    temp AS
        (SELECT city_2,
                ('{' || city_1) AS path,
                cost            AS total_cost
         FROM cities
         where city_1 = 'a'

         UNION

         SELECT cities.city_2,
                (temp.path || ',' || cities.city_1) AS path,
                temp.total_cost + cities.cost       AS total_cost
         FROM cities
                  JOIN temp ON temp.city_2 = cities.city_1
         WHERE path NOT LIKE ('%' || cities.city_1 || '%')),

    graph_result AS (SELECT total_cost, (path || ',a}') AS tour
                     FROM temp
                     WHERE city_2 = 'a'
                       AND LENGTH(path) = 8),
    min_result AS (SELECT *
                   FROM graph_result
                   WHERE total_cost = (SELECT MIN(total_cost) FROM graph_result)),
    max_result AS (SELECT *
                   FROM graph_result
                   WHERE total_cost = (SELECT MAX(total_cost) FROM graph_result))

SELECT *
FROM min_result
UNION
SELECT *
FROM max_result
ORDER BY 1, 2;
