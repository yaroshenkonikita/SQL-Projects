DROP table IF EXISTS cities;

CREATE TABLE cities
(
    id     bigint primary key,
    cost   integer not null,
    city_1 varchar not null,
    city_2 varchar not null
);

INSERT INTO cities
VALUES (1, 15, 'a', 'c');
INSERT INTO cities
VALUES (2, 15, 'c', 'a');

INSERT INTO cities
VALUES (3, 20, 'a', 'd');
INSERT INTO cities
VALUES (4, 20, 'd', 'a');

INSERT INTO cities
VALUES (5, 10, 'a', 'b');
INSERT INTO cities
VALUES (6, 10, 'b', 'a');

INSERT INTO cities
VALUES (7, 35, 'c', 'b');
INSERT INTO cities
VALUES (8, 35, 'b', 'c');

INSERT INTO cities
VALUES (9, 30, 'c', 'd');
INSERT INTO cities
VALUES (10, 30, 'd', 'c');

INSERT INTO cities
VALUES (11, 25, 'b', 'd');
INSERT INTO cities
VALUES (12, 25, 'd', 'b');


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
                   WHERE total_cost = (SELECT MIN(total_cost) FROM graph_result))

SELECT *
FROM min_result
ORDER BY 1, 2;
