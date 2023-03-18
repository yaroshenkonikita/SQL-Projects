CREATE OR REPLACE PROCEDURE PR_P2P_CHECK(PERSON_BEING_CHECKED VARCHAR,
                                         CHECKER VARCHAR,
                                         TASK_NAME VARCHAR,
                                         CHECK_STATUS CHECKSTATUS,
                                         CHECK_TIME TIME)
AS
$$
DECLARE
    NEW_CHECK_ID BIGINT := 0;
BEGIN

    IF CHECK_STATUS = 'Start' THEN
        NEW_CHECK_ID := (SELECT MAX(ID) + 1 FROM CHECKS);
        INSERT INTO CHECKS (ID, PEER, TASK, DATE)
        VALUES (NEW_CHECK_ID,
                PERSON_BEING_CHECKED,
                TASK_NAME,
                CURRENT_DATE);
    ELSE
        NEW_CHECK_ID := (SELECT C.ID
                         FROM P2P
                                  JOIN CHECKS C ON P2P.CHECK_ID = C.ID
                         WHERE PEER = PERSON_BEING_CHECKED
                           AND TASK = TASK_NAME
                         ORDER BY C.ID DESC
                         LIMIT 1);
    END IF;

    INSERT INTO P2P (ID, CHECK_ID, CHECKINGPEER, STATE, TIME)
    VALUES ((SELECT MAX(ID) + 1 FROM P2P),
            NEW_CHECK_ID,
            CHECKER,
            CHECK_STATUS,
            CHECK_TIME);
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE PROCEDURE PR_VERTER_CHECK(PERSON_BEING_CHECKED VARCHAR,
                                            TASK_NAME VARCHAR,
                                            CHECK_STATUS CHECKSTATUS,
                                            CHECK_TIME TIME)
    LANGUAGE PLPGSQL
AS
$$
DECLARE
    SUCCESS_CHECK BIGINT := (SELECT C.ID
                             FROM P2P
                                      JOIN CHECKS C ON P2P.CHECK_ID = C.ID AND P2P.STATE = 'Success'
                                 AND C.TASK = TASK_NAME AND C.PEER = PERSON_BEING_CHECKED
                             ORDER BY P2P.TIME
                             LIMIT 1);
BEGIN
    INSERT INTO VERTER (ID, CHECK_ID, STATE, TIME)
    VALUES ((SELECT MAX(ID) + 1 FROM VERTER),
            SUCCESS_CHECK,
            CHECK_STATUS,
            CHECK_TIME);
END;
$$;

CREATE OR REPLACE FUNCTION FNC_TRG_P2P_INSERT_START() RETURNS TRIGGER AS
$TRG_P2P_INSERT_START$
BEGIN
    IF (NEW.STATE = 'Start') THEN
        WITH NEW_TABLE AS (
            SELECT CHECKS.PEER AS PEER FROM P2P
                                                JOIN CHECKS ON P2P.CHECK_ID = CHECKS.ID
            WHERE STATE = 'Start' AND NEW.CHECK_ID = CHECKS.ID
        )
        UPDATE TRANSFERREDPOINTS
        SET POINTSAMOUNT = POINTSAMOUNT + 1
        FROM NEW_TABLE
        WHERE NEW_TABLE.PEER = TRANSFERREDPOINTS.CHECKEDPEER AND
                NEW.CHECKINGPEER = TRANSFERREDPOINTS.CHECKINGPEER;
        RETURN NEW;
    ELSE
        RETURN NULL;
    END IF;
END;
$TRG_P2P_INSERT_START$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER TRG_P2P_INSERT_START
    AFTER INSERT
    ON P2P
    FOR EACH ROW
EXECUTE FUNCTION FNC_TRG_P2P_INSERT_START();

CREATE OR REPLACE FUNCTION FNC_TRG_XP_INSERT_CHECK() RETURNS TRIGGER AS
$TRG_XP_INSERT_CHECK$
DECLARE
    STATUS VARCHAR(30);
    MAX_XP INTEGER;
BEGIN
    MAX_XP := (SELECT MAXXP
               FROM CHECKS C
                        JOIN TASKS T ON T.TITLE = C.TASK
               WHERE C.ID = NEW.CHECK_ID);

    STATUS := (SELECT P.STATE
               FROM CHECKS
                        JOIN P2P P ON CHECKS.ID = P.CHECK_ID
               WHERE CHECKS.ID = NEW.CHECK_ID
               ORDER BY 1 DESC
               LIMIT 1);

    IF NEW.XPAMOUNT > MAX_XP AND STATUS = 'Failure' THEN
        RAISE EXCEPTION 'Check is failure and the amount of xp is more than the maximum';
    ELSEIF NEW.XPAMOUNT > MAX_XP THEN
        RAISE EXCEPTION 'The amount of xp is more than the maximum';
    ELSEIF STATUS = 'Failure' THEN
        RAISE EXCEPTION 'Check is Failure';
    ELSE
        RETURN NEW;
    END IF;
END;
$TRG_XP_INSERT_CHECK$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER TRG_XP_INSERT_CHECK
    BEFORE INSERT
    ON XP
    FOR EACH ROW
EXECUTE FUNCTION FNC_TRG_XP_INSERT_CHECK();

----------------------------------------------------
-- CHECKING XP TRIGGERS

-- -- FAILURE CHECK
-- INSERT INTO XP (ID, CHECK_ID, XPAMOUNT)
-- VALUES ((SELECT MAX(ID) + 1 FROM XP), 5, 100);
--
-- -- BAD AMOUNT OF XP
-- INSERT INTO XP (ID, CHECK_ID, XPAMOUNT)
-- VALUES ((SELECT MAX(ID) + 1 FROM XP), 1, 800);
--
-- -- BOTH PROBLEMS
-- INSERT INTO XP (ID, CHECK_ID, XPAMOUNT)
-- VALUES ((SELECT MAX(ID) + 1 FROM XP), 5, 800);
--
-- EVERYTHING IS FINE
INSERT INTO XP (ID, CHECK_ID, XPAMOUNT)
VALUES ((SELECT MAX(ID) + 1 FROM XP), 1, 150);

DELETE
FROM XP
WHERE ID = (SELECT MAX(ID) FROM XP);

----------------------------------------------------
-- TEST OF ADDING P2P CHECKS AND VERTER CHECKS

CALL PR_P2P_CHECK('suppfill',
                  'inigosto',
                  'A6_s21_greend',
                  'Start',
                  '09:00:00');

CALL PR_P2P_CHECK('suppfill',
                  'inigosto',
                  'A6_s21_greend',
                  'Success',
                  '09:15:00');

CALL PR_VERTER_CHECK('suppfill',
                     'A6_s21_greend',
                     'Start',
                     '09:20:00');

CALL PR_VERTER_CHECK('suppfill',
                     'A6_s21_greend',
                     'Success',
                     '09:23:00');

----------------------------------------------------

CALL PR_P2P_CHECK('inigosto',
                  'regulusb',
                  'A8_s21_hectorian',
                  'Start',
                  '12:00:00');

CALL PR_P2P_CHECK('inigosto',
                  'regulusb',
                  'A8_s21_hectorian',
                  'Success',
                  '12:20:00');

CALL PR_VERTER_CHECK('inigosto',
                     'A8_s21_hectorian',
                     'Start',
                     '12:25:00');

CALL PR_VERTER_CHECK('inigosto',
                     'A8_s21_hectorian',
                     'Failure',
                     '12:30:00');

----------------------------------------------------

CALL PR_P2P_CHECK('suppfill',
                  'regulusb',
                  'A7_s21_roflan',
                  'Start',
                  '13:00:00');

CALL PR_P2P_CHECK('suppfill',
                  'regulusb',
                  'A7_s21_roflan',
                  'Failure',
                  '13:15:00');

----------------------------------------------------
