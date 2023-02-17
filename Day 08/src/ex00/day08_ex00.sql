-- session 1
BEGIN TRANSACTION; -- 1
UPDATE pizzeria SET rating = 4.6 WHERE name = 'Pizza Hut'; -- 4
COMMIT WORK; -- 5

-- session 2
BEGIN TRANSACTION; -- 2
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 3
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 6
