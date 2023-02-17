-- session 1 
BEGIN TRANSACTION; -- 1
UPDATE pizzeria SET rating = 2.8 WHERE id = 1; -- 3
UPDATE pizzeria SET rating = 2.2 WHERE id = 2; -- 5
COMMIT WORK; -- 7

-- session 2
BEGIN TRANSACTION; -- 2
UPDATE pizzeria SET rating = 3.8 WHERE id = 2; -- 4
UPDATE pizzeria SET rating = 3.2 WHERE id = 1; -- 6
COMMIT WORK; -- 8