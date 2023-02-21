INSERT INTO PERSON_ORDER VALUES ((SELECT MAX(ID) FROM PERSON_ORDER) + 1,
                                  (SELECT ID FROM PERSON WHERE NAME = 'Denis'),
                                  (SELECT ID FROM MENU WHERE PIZZA_NAME = 'sicilian pizza'),
                                  '2022-02-24');
INSERT INTO PERSON_ORDER VALUES ((SELECT MAX(ID) FROM PERSON_ORDER) + 1,
                                  (SELECT ID FROM PERSON WHERE NAME = 'Irina'),
                                  (SELECT ID FROM MENU WHERE PIZZA_NAME = 'sicilian pizza'),
                                  '2022-02-24');
-- DELETE FROM PERSON_ORDER WHERE ID = (SELECT MAX(ID) FROM PERSON_ORDER);
