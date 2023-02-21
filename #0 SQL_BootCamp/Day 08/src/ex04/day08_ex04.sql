-- session 1
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE; -- 1
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 3
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 6
COMMIT WORK; -- 7
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 8

-- session 2
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE; -- 2
UPDATE pizzeria SET rating = 3.0 WHERE name = 'Pizza Hut'; -- 4
COMMIT WORK; -- 5
SELECT * FROM pizzeria WHERE name = 'Pizza Hut'; -- 9