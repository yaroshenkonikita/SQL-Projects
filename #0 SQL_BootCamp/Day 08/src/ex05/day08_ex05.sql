-- session 1
BEGIN TRANSACTION; -- 1
SELECT sum(rating) FROM pizzeria; -- 3
SELECT sum(rating) FROM pizzeria; -- 6
COMMIT WORK; -- 7
SELECT sum(rating) FROM pizzeria; -- 8

-- session 2
BEGIN TRANSACTION; -- 2
UPDATE pizzeria SET rating = 1 WHERE name = 'Pizza Hut'; -- 4
COMMIT WORK; -- 5
SELECT sum(rating) FROM pizzeria; -- 9