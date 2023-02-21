-- session 1
BEGIN TRANSACTION; -- 1
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; -- 3
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 5
UPDATE pizzeria SET rating = 4 WHERE name = 'Pizza Hut'; -- 7
COMMIT WORK; -- 9
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 11

-- session 2
BEGIN TRANSACTION; -- 2
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; -- 4
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 6
UPDATE pizzeria SET rating = 3.6 WHERE name = 'Pizza Hut'; -- 8
COMMIT WORK; -- 10
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 12