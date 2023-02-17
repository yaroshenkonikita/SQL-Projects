-- session 1
BEGIN TRANSACTION;        -- 1
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 3
UPDATE pizzeria SET rating = 4 WHERE name = 'Pizza Hut'; -- 5
COMMIT WORK; -- 7
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 9

-- session 2
BEGIN TRANSACTION; -- 2
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 4
UPDATE pizzeria SET rating = 3.6 WHERE name = 'Pizza Hut'; -- 6
COMMIT WORK; -- 8
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 10