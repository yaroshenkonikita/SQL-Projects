INSERT INTO MENU VALUES ((SELECT MAX(ID) FROM MENU) + 1,
                         (SELECT ID FROM PIZZERIA WHERE NAME = 'Dominos'),
                         'sicilian pizza',
                         900);
-- DELETE FROM MENU WHERE ID = (SELECT MAX(ID) FROM MENU);
