----------------------------------------------------- 3.1 !
-- Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде

CREATE OR REPLACE FUNCTION FN_TRANSFERED_POINTS()
    RETURNS TABLE
            (
                PEER1        VARCHAR,
                PEER2        VARCHAR,
                POINTSAMOUNT BIGINT
            )
    LANGUAGE PLPGSQL
AS
$$
BEGIN
    RETURN QUERY
        SELECT CASE WHEN CHECKEDPEER > CHECKINGPEER THEN CHECKEDPEER ELSE CHECKINGPEER END,
               CASE WHEN CHECKINGPEER < CHECKEDPEER THEN CHECKINGPEER ELSE CHECKEDPEER END,
               SUM(CASE WHEN CHECKEDPEER > CHECKINGPEER THEN TP.POINTSAMOUNT ELSE -TP.POINTSAMOUNT END)
        FROM TRANSFERREDPOINTS TP
        GROUP BY 1, 2;
END;
$$;

SELECT *
FROM FN_TRANSFERED_POINTS();

------------------------------------------------------ 3.2 !
-- Написать функцию, которая возвращает таблицу вида:
-- ник пользователя, название проверенного задания, кол-во полученного XP

CREATE OR REPLACE FUNCTION FN_SUCCESS_CHECKS()
    RETURNS TABLE
            (
                PEER VARCHAR,
                TASK VARCHAR,
                XP   INTEGER
            )
    LANGUAGE PLPGSQL
AS
$$
BEGIN
    RETURN QUERY
        SELECT C.PEER, T.TITLE, X.XPAMOUNT
        FROM CHECKS C
        JOIN TASKS T ON C.TASK = T.TITLE
        JOIN XP X ON C.ID = X.CHECK_ID;
END
$$;

-- SELECT * FROM FN_SUCCESS_CHECKS();

-----------------------------------------  3.3 !
--  Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня

CREATE OR REPLACE FUNCTION FN_NO_LEFT_CAMPUS(DAY DATE) RETURNS SETOF RECORD
    LANGUAGE PLPGSQL AS
$$
BEGIN
    RETURN QUERY
        SELECT PEER FROM TIMETRACKING
        WHERE DATE = DAY AND STATE IN (1,2)
        GROUP BY PEER
        HAVING COUNT(PEER) = 2;
END;
$$;

-- SELECT * FROM FN_NO_LEFT_CAMPUS('2023-01-10') AS (PEERS VARCHAR);

----------------------------------------------------- 3.4 !
-- Найти процент успешных и неуспешных проверок за всё время

CREATE OR REPLACE PROCEDURE PD_PERCENTGE_TASK(SUCCESSFULCHECKS OUT BIGINT, UNSUCCESSFULCHECKS OUT BIGINT)
    LANGUAGE PLPGSQL AS
$$
DECLARE
    ONE_     NUMERIC;
    SUCCESS_ NUMERIC;
BEGIN
    SELECT COUNT(*) INTO SUCCESS_ FROM XP;
    SELECT COUNT(*) / 100. INTO ONE_ FROM CHECKS;
    SELECT SUCCESS_ / ONE_ INTO SUCCESS_;

    SELECT SUCCESS_ INTO SUCCESSFULCHECKS;
    SELECT 100 - SUCCESS_ INTO UNSUCCESSFULCHECKS;
END;
$$;

CALL PD_PERCENTGE_TASK(0, 0);

---------------------------------------------  3.5 !
-- Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints


CREATE OR REPLACE PROCEDURE PD_PEER_POINTS_CHANGE(PEER INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN PEER FOR
        SELECT TMP_T.PEER, SUM(TMP_T.POINTSCHANGE) POINTSCHANGE FROM
        ((SELECT CHECKINGPEER PEER, -SUM(POINTSAMOUNT) POINTSCHANGE FROM TRANSFERREDPOINTS GROUP BY CHECKINGPEER)
        UNION ALL
        (SELECT CHECKEDPEER PEER, SUM(POINTSAMOUNT) POINTSCHANGE FROM TRANSFERREDPOINTS GROUP BY CHECKEDPEER)) TMP_T
        GROUP BY TMP_T.PEER
        ORDER BY 1, 2 DESC;
END;
$$;



-- BEGIN;
--     CALL PD_PEER_POINTS_CHANGE('A');
--     FETCH ALL IN "A";
-- END;

---------------------------------------------  3.6 !
-- Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой функцией из Part 3.1


CREATE OR REPLACE PROCEDURE PD_PEER_POINTS_CHANGE2(PEER INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN PEER FOR
        WITH P1 AS (
            SELECT PEER1 AS PEER, SUM(POINTSAMOUNT) AS POINTSCHANGE
            FROM FN_TRANSFERED_POINTS()
            GROUP BY PEER1
        ),
        P2 AS (
            SELECT PEER2 AS PEER, SUM(POINTSAMOUNT) AS POINTSCHANGE
            FROM FN_TRANSFERED_POINTS()
            GROUP BY PEER2
        )

        SELECT COALESCE(P1.PEER, P2.PEER) AS PEER, (COALESCE(P1.POINTSCHANGE, 0) - COALESCE(P2.POINTSCHANGE, 0)) AS POINTSCHANGE
        FROM P1
        FULL JOIN P2 ON P1.PEER = P2.PEER
        ORDER BY POINTSCHANGE DESC;
END;
$$;

-- BEGIN;
--     CALL PD_PEER_POINTS_CHANGE2('A');
--    FETCH ALL IN "A";
-- END;

---------------------------------------------  3.7 !
-- Определить самое часто проверяемое задание за каждый день

CREATE OR REPLACE PROCEDURE PD_MAX_TASK_CHECK(IN RESULT REFCURSOR)
AS
$$
BEGIN
    OPEN RESULT FOR
        WITH T1 AS (SELECT DATE        AS D,
                           CHECKS.TASK,
                           COUNT(TASK) AS TC
                    FROM CHECKS
                    GROUP BY CHECKS.TASK, D)
        SELECT T2.D AS DAY, T2.TASK
        FROM (SELECT T1.TASK,
                     T1.D,
                     RANK() OVER (PARTITION BY T1.D ORDER BY TC DESC) AS RANK
              FROM T1) AS T2
        WHERE RANK = 1
        ORDER BY DAY;
END
$$ LANGUAGE PLPGSQL;

-- BEGIN;
-- CALL PD_MAX_TASK_CHECK('RESULT');
-- FETCH ALL IN "RESULT";
-- END;

---------------------------------------------  3.8 !
-- Определить длительность последней P2P проверки

CREATE OR REPLACE PROCEDURE PD_DURATION_LAST_CHECK_P2P(RESULT INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN RESULT FOR
        WITH TEMP AS
            (SELECT P2P.TIME, STATE FROM P2P INNER JOIN (SELECT MAX(CHECK_ID) ID
                                                         FROM P2P
                                                         WHERE STATE != 'Start') LC ON LC.ID = P2P.CHECK_ID)
        SELECT DISTINCT ((SELECT TIME FROM TEMP WHERE STATE != 'Start') -
               (SELECT TIME FROM TEMP WHERE STATE = 'Start'))::TIME
            AS DURATION_LAST_CHECK
        FROM TEMP;
END;
$$;

-- BEGIN;
--     CALL PD_DURATION_LAST_CHECK_P2P('RESULT');
--     FETCH ALL IN "RESULT";
-- END;

---------------------------------------------  3.9 !
-- Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания

CREATE OR REPLACE PROCEDURE PD_COMPLETED_BLOCK_OF_TASKS(IN NAME_BLOCK_ VARCHAR, RESULT INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN RESULT FOR
        SELECT T2.PEER, MAX(T2.DATE) FROM
        (
            SELECT T1.PEER, T1.DATE FROM (
                SELECT ID, PEER, DATE FROM CHECKS
                WHERE TASK IN (SELECT TITLE FROM TASKS WHERE TITLE LIKE '%' || NAME_BLOCK_ || '%')
            ) T1
        JOIN P2P
        ON P2P.CHECK_ID = T1.ID
        WHERE STATE = 'Success'
        ) T2
        GROUP BY 1
        ORDER BY 1 DESC;
END;
$$;

-- BEGIN;
--     CALL PD_COMPLETED_BLOCK_OF_TASKS('A6', 'RESULT');
--     FETCH ALL IN "RESULT";
-- END;

---------------------------------------------  3.10 !
-- Определить, к какому пиру стоит идти на проверку каждому обучающемуся

CREATE OR REPLACE FUNCTION FN_AMOUNT_OF_RECOMMENDATION(PEER_ VARCHAR) RETURNS VARCHAR
    LANGUAGE PLPGSQL AS
$$
DECLARE
    RESULT VARCHAR;
BEGIN
    SELECT R.RECOMENDEDPEER, PEER, COUNT(RECOMENDEDPEER) AS AMOUNT_OF_RECOMENDATION
    INTO RESULT
    FROM ((SELECT PEER2 AS PEER_FRIEND
           FROM PEERS
                    JOIN FRIENDS ON PEERS.NICKNAME = FRIENDS.PEER2
           WHERE PEER1 = PEER_)
          UNION ALL
          (SELECT PEER1 AS PEER_FRIEND
           FROM PEERS
                    JOIN FRIENDS ON PEERS.NICKNAME = FRIENDS.PEER1
           WHERE PEER2 = PEER_)) AS TEMP
             JOIN RECOMMENDATIONS R ON R.PEER = PEER_FRIEND
    WHERE RECOMENDEDPEER != PEER_
    GROUP BY R.RECOMENDEDPEER, PEER
    ORDER BY 2 DESC
    LIMIT (1);
    RETURN RESULT;
END;
$$;

CREATE OR REPLACE PROCEDURE PD_FIND_BEST_PEER(RESULT INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN RESULT FOR
        SELECT NICKNAME, FN_AMOUNT_OF_RECOMMENDATION(NICKNAME) AS RECOMENDED_PEER
        FROM PEERS;
END;
$$;

-- BEGIN;
--     CALL PD_FIND_BEST_PEER('RESULT');
--     FETCH ALL IN "RESULT";
-- END;

----------------------------------------------  3.11 !
-- Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному

CREATE OR REPLACE PROCEDURE PD_START_BLOCKS(IN_BLOCK1 VARCHAR, IN_BLOCK2 VARCHAR, RESULT INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN RESULT FOR
        WITH
        BLOCK_1_STARTED AS (
            SELECT PEER FROM CHECKS
            WHERE TASK IN (SELECT TITLE FROM TASKS WHERE TITLE LIKE '%' || IN_BLOCK1 || '%')
        ),
        BLOCK_2_STARTED AS (
            SELECT PEER FROM CHECKS
            WHERE TASK IN (SELECT TITLE FROM TASKS WHERE TITLE LIKE '%' || IN_BLOCK2 || '%')
        ),
        STARTEDBLOCK1 AS (
            SELECT PEER FROM BLOCK_1_STARTED
            EXCEPT
            SELECT PEER FROM BLOCK_2_STARTED
        ),
        STARTEDBLOCK2 AS (
            SELECT PEER FROM BLOCK_2_STARTED
            EXCEPT
            SELECT PEER FROM BLOCK_1_STARTED
        ),
        STARTEDBOTHBLOCKS AS (
            SELECT PEER FROM BLOCK_1_STARTED
            INTERSECT
            SELECT PEER FROM BLOCK_2_STARTED
        ),
        DIDNTSTARTANYBLOCK AS (
            SELECT NICKNAME AS PEER FROM PEERS
            LEFT JOIN CHECKS ON PEERS.NICKNAME = CHECKS.PEER
            WHERE PEER IS NULL
        )

        SELECT
            ((SELECT COUNT(PEER)*100 FROM STARTEDBLOCK1) / (SELECT COUNT(NICKNAME) FROM PEERS)) AS SARTEDBLOCK1,
            ((SELECT COUNT(PEER)*100 FROM STARTEDBLOCK2) / (SELECT COUNT(NICKNAME) FROM PEERS)) AS SARTEDBLOCK2,
            ((SELECT COUNT(PEER)*100 FROM STARTEDBOTHBLOCKS) / (SELECT COUNT(NICKNAME) FROM PEERS)) AS STARTEDBOTHBLOCKS,
            ((SELECT COUNT(PEER)*100 FROM DIDNTSTARTANYBLOCK) / (SELECT COUNT(NICKNAME) FROM PEERS)) AS DIDNTSTARTANYBLOCK;
END;
$$;

-- BEGIN;
--    CALL PD_START_BLOCKS('A5_s21_memory', 'A8_s21_hectorian', 'CUR');
--    FETCH ALL IN "CUR";
-- END;
-- -- in second A6_s21_greend

---------------------------------------------  3.12 !
-- Определить N пиров с наибольшим числом друзей

CREATE OR REPLACE PROCEDURE PD_AMOUNT_OF_FRIENDS(N INT, RESULT INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN RESULT FOR
        SELECT PEER1,
               COUNT(*)
        FROM FRIENDS GROUP BY 1 ORDER BY 2 DESC LIMIT(N);
END;
$$;

-- BEGIN;
--     CALL PD_AMOUNT_OF_FRIENDS(3, 'RESULT');
--     FETCH ALL IN "RESULT";
-- END;

---------------------------------------------  3.13 !
-- Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
-- Также определите процент пиров, которые хоть раз проваливали проверку в свой день рождения


CREATE OR REPLACE PROCEDURE PD_PERCENT_CHECK_ON_BIRTHDAY(IN RESULT REFCURSOR = 'pr_result')
    LANGUAGE PLPGSQL AS
$$
DECLARE
    FAILS INT;
    SUCCESSES INT;
BEGIN
        SELECT COUNT(*) INTO FAILS FROM (SELECT * FROM CHECKS
            INNER JOIN PEERS
                ON CHECKS.PEER = PEERS.NICKNAME
                       AND CHECKS.DATE = PEERS.BIRTHDAY
            LEFT OUTER JOIN XP
                ON XP.CHECK_ID = CHECKS.ID) CR
                                   WHERE CR.XPAMOUNT IS NULL;
        SELECT COUNT(*) INTO SUCCESSES FROM (SELECT * FROM CHECKS
            INNER JOIN PEERS
                ON CHECKS.PEER = PEERS.NICKNAME
                       AND CHECKS.DATE = PEERS.BIRTHDAY
            LEFT OUTER JOIN XP
                ON XP.CHECK_ID = CHECKS.ID) CR
                                       WHERE CR.XPAMOUNT IS NOT NULL;

        IF (FAILS + SUCCESSES > 0) THEN
            OPEN RESULT FOR
                SELECT SUCCESSES * 100 / (FAILS + SUCCESSES) SUCCESSFUL_CHECKS,
                       FAILS * 100 / (FAILS + SUCCESSES) UNSUCCESSFUL_CHECKS;
        ELSE
            OPEN RESULT FOR SELECT NULL SUCCESSFUL_CHECKS,
                                   NULL UNSUCCESSFUL_CHECKS;
        END IF;
END;
$$;

-- INSERT INTO CHECKS (ID, PEER, TASK, DATE)
-- VALUES ((SELECT MAX(ID) FROM CHECKS) + 1, 'inigosto', 'A5_s21_memory', '2004-01-01');
-- INSERT INTO XP
-- VALUES ((SELECT MAX(ID) FROM XP) + 1, (SELECT MAX(ID) FROM CHECKS), 150);
--
-- INSERT INTO CHECKS (ID, PEER, TASK, DATE)
-- VALUES ((SELECT MAX(ID) FROM CHECKS) + 1, 'rollback', 'A5_s21_memory', '2001-11-13');
-- INSERT INTO XP
-- VALUES ((SELECT MAX(ID) FROM XP) + 1, (SELECT MAX(ID) FROM CHECKS), 150);
-- BEGIN;
--     CALL PD_PERCENT_CHECK_ON_BIRTHDAY();
--     FETCH ALL IN pr_result;
-- END;

--------------------------------------------- task 3.14 !
--  Определить кол-во XP, полученное в сумме каждым пиром

CREATE OR REPLACE FUNCTION FN_XP_ALL_PEERS()
    RETURNS TABLE
        (
            PEERS VARCHAR,
            XP    BIGINT
        )
AS
$$
BEGIN
    RETURN QUERY
        SELECT TEMP.PEER, SUM(XPAMOUNT)
        FROM (SELECT MAX(CHECKS.ID), CHECKS.PEER, XP.XPAMOUNT, CHECKS.TASK
              FROM CHECKS
                  JOIN XP ON XP.CHECK_ID = CHECKS.ID
              GROUP BY 2,3,4) AS TEMP
        GROUP BY TEMP.PEER
        ORDER BY 2;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE PROCEDURE PD_XP_ALL_PEERS(RES_ARG INOUT REFCURSOR)
AS
$$
BEGIN
    OPEN RES_ARG FOR SELECT GG.PEERS, GG.XP FROM FN_XP_ALL_PEERS() AS GG;
END;
$$ LANGUAGE PLPGSQL;

BEGIN;
    CALL PD_XP_ALL_PEERS(RES_ARG := 'DATA');
    FETCH ALL IN "DATA";
END;

------------------------------------------ task 3.15 !
-- Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3

CREATE OR REPLACE PROCEDURE PD_GET_PEERS_WITH_COND(RES_ARG INOUT REFCURSOR, IN_FIRST_T VARCHAR,
                                                   IN_SECOND_T VARCHAR, IN_UNCOMPLETE VARCHAR)
AS
$$
BEGIN
    OPEN RES_ARG FOR
        (SELECT DISTINCT CHECKS.PEER
        FROM CHECKS
        JOIN XP ON CHECKS.ID = XP.CHECK_ID
        AND TASK = IN_FIRST_T)
        INTERSECT
        (SELECT DISTINCT CHECKS.PEER
        FROM CHECKS
        JOIN XP ON CHECKS.ID = XP.CHECK_ID
        AND TASK = IN_SECOND_T)
        EXCEPT
        (SELECT DISTINCT CHECKS.PEER
        FROM CHECKS
        JOIN XP ON CHECKS.ID = XP.CHECK_ID
        AND TASK = IN_UNCOMPLETE);
END;
$$ LANGUAGE PLPGSQL;

-- INSERT INTO CHECKS VALUES ((SELECT MAX(ID) FROM CHECKS) + 1, 'rollback', 'A5_s21_memory', '2022-05-11');
-- INSERT INTO XP VALUES ((SELECT MAX(ID) FROM XP) + 1, (SELECT MAX(ID) FROM CHECKS), 150);
-- INSERT INTO CHECKS VALUES ((SELECT MAX(ID) FROM CHECKS) + 1, 'rollback', 'A6_s21_greend', '2022-05-11');
-- INSERT INTO XP VALUES ((SELECT MAX(ID) FROM XP) + 1, (SELECT MAX(ID) FROM CHECKS), 200);
-- INSERT INTO CHECKS VALUES ((SELECT MAX(ID) FROM CHECKS) + 1, 'rollback', 'A7_s21_roflan', '2022-05-11');
-- -- INSERT INTO XP VALUES ((SELECT MAX(ID) FROM XP) + 1, (SELECT MAX(ID) FROM CHECKS), 200);

-- BEGIN;
--     CALL PD_GET_PEERS_WITH_COND(RES_ARG := 'DATA', IN_FIRST_T := 'A5_s21_memory', IN_SECOND_T := 'A6_s21_greend', IN_UNCOMPLETE := 'A7_s21_roflan');
--     FETCH ALL IN "DATA";
-- END;

-------------------------------------------- task 3.16 !
-- Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач

CREATE OR REPLACE PROCEDURE PD_TASK_LIST_UNTIL(RES_ARG INOUT REFCURSOR)
AS
$$
BEGIN
    OPEN RES_ARG FOR
        WITH RECURSIVE RECOURSE_WITH AS
                           (SELECT CASE
                                       WHEN (TASKS.PARENTTASK IS NULL) THEN 0
                                       ELSE 1
                                       END          AS COUNTER,
                                   TASKS.TITLE,
                                   TASKS.PARENTTASK AS CURRENT_TASKS,
                                   TASKS.PARENTTASK
                            FROM TASKS

                            UNION ALL

                            SELECT (CASE
                                        WHEN CHILD.PARENTTASK IS NOT NULL THEN COUNTER + 1
                                        ELSE COUNTER
                                END)                AS COUNTER,
                                   CHILD.TITLE      AS TITLE,
                                   CHILD.PARENTTASK AS CURRENT_TASKS,
                                   PARRENT.TITLE    AS PARRENTTASK
                            FROM TASKS AS CHILD
                                     CROSS JOIN RECOURSE_WITH AS PARRENT
                            WHERE PARRENT.TITLE LIKE CHILD.PARENTTASK)
        SELECT TITLE        AS TASK,
               MAX(COUNTER) AS PREVCOUNT
        FROM RECOURSE_WITH
        GROUP BY TITLE
        ORDER BY 1;
END;
$$ LANGUAGE PLPGSQL;

-- BEGIN;
--     CALL PD_TASK_LIST_UNTIL(RES_ARG := 'DATA');
--     FETCH ALL IN "DATA";
-- END;

----------------------------------------------  3.17 !
-- Найти "удачные" для проверок дни. День считается "удачным", если в нем есть хотя бы N идущих подряд успешных проверки

CREATE OR REPLACE PROCEDURE PD_LUCKY_DAYS_CHECKS(IN_N BIGINT, RES INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
DECLARE
    COUNT_TRUE INT     = 0;
    TEMP       RECORD;
    FLAG_TRUE  BOOLEAN = FALSE;
    RANG       INT     = 0;
BEGIN
    DROP TABLE IF EXISTS TEMP_TABLE;
    CREATE TEMPORARY TABLE TEMP_TABLE
    (
        DAYS DATE
    );
    FOR TEMP IN
        SELECT DENSE_RANK() OVER (ORDER BY CHECKS.DATE) AS NUM, CHECKS.ID, DATE, X.XPAMOUNT IS NOT NULL AS RESULT
        FROM CHECKS
                 LEFT JOIN XP X ON CHECKS.ID = X.CHECK_ID
        ORDER BY 2
        LOOP
            IF FLAG_TRUE = FALSE OR RANG != TEMP.NUM
            THEN
                COUNT_TRUE = 0;
            END IF;
            IF TEMP.RESULT = TRUE THEN
                COUNT_TRUE = COUNT_TRUE + 1;
                FLAG_TRUE = TRUE;
            ELSE
                COUNT_TRUE = 0;
                FLAG_TRUE = FALSE;
            END IF;
            IF COUNT_TRUE = IN_N THEN INSERT INTO TEMP_TABLE VALUES (TEMP.DATE); END IF;
            RAISE NOTICE 'TEMP = %, FLAG_TRUE :%, COUNT :%', TEMP, FLAG_TRUE, COUNT_TRUE;
            RANG = TEMP.NUM;
        END LOOP;
    OPEN RES FOR
        SELECT * FROM TEMP_TABLE;
END
$$;

-- BEGIN;
--     CALL PD_LUCKY_DAYS_CHECKS(3,'RES');
--     FETCH ALL IN "RES";
-- END;

-- task 3.18 !
-- Определить пира с наибольшим числом выполненных заданий

CREATE OR REPLACE PROCEDURE PD_GET_MAX_COUNT_TASKS(RESULT INOUT REFCURSOR)
    LANGUAGE PLPGSQL AS
$$
BEGIN
    OPEN RESULT FOR
        SELECT PEER, COUNT(TASK) XP FROM (SELECT DISTINCT peer, task
            FROM FN_SUCCESS_CHECKS()
            ) T
        GROUP BY 1
        ORDER BY 2 DESC LIMIT(1);
END;
$$;

-- BEGIN;
--    CALL PD_GET_MAX_COUNT_TASKS('RESULT');
--    FETCH ALL IN "RESULT";
-- END;

----------------------------------------------  3.19 !
-- Определить пира с наибольшим количеством XP

CREATE OR REPLACE PROCEDURE PD_GET_THE_HIGHEST_XP_PEER(RES_ARG INOUT REFCURSOR)
AS
$$
BEGIN
    OPEN RES_ARG FOR
        SELECT *
        FROM FN_XP_ALL_PEERS()
        ORDER BY XP DESC
        LIMIT 1;
END;
$$ LANGUAGE PLPGSQL;

-- BEGIN;
-- CALL PD_GET_THE_HIGHEST_XP_PEER(RES_ARG := 'DATA');
-- FETCH ALL "DATA";
-- END;

----------------------------------------------  3.20 !
-- Определить пира, который провел сегодня в кампусе больше всего времени

CREATE OR REPLACE PROCEDURE PD_MOST_MOTIVATED_PEER(RES_ARG INOUT REFCURSOR)
AS
$$
BEGIN
    OPEN RES_ARG FOR
        SELECT LAST_CALL.PEER
             FROM (SELECT GABELLA.PEER, (GABELLA.SUM - GG.SUM)
                   FROM (SELECT PEER, SUM(TIME)
                         FROM TIMETRACKING
                         WHERE STATE = 2 AND DATE = CURRENT_DATE
                         GROUP BY PEER) AS GABELLA
                            JOIN
                        (SELECT PEER, SUM(TIME)
                         FROM TIMETRACKING
                         WHERE STATE = 1 AND DATE = CURRENT_DATE
                         GROUP BY PEER) AS GG
                        ON GG.PEER = GABELLA.PEER
                   ORDER BY 2 DESC
                   LIMIT 1) AS LAST_CALL;
END;
$$ LANGUAGE PLPGSQL;

-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'regulusb', CURRENT_DATE, '16:20:40', 1);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'regulusb', CURRENT_DATE, '17:20:40', 2);
--
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'inigosto', CURRENT_DATE, '12:00:20', 1);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'inigosto', CURRENT_DATE, '15:00:40', 2);

-- BEGIN;
--     CALL PD_MOST_MOTIVATED_PEER(RES_ARG := 'DATA');
--     FETCH ALL "DATA";
-- END;

----------------------------------------------  3.21 !
--  Определить пиров, приходивших раньше заданного времени не менее N раз за всё время

CREATE OR REPLACE PROCEDURE PD_PEERS_GONE_UNTIL_TIME(RES_ARG INOUT REFCURSOR, IN_VALUE TIME, IN_NUMBER INTEGER)
AS
$$
BEGIN
    OPEN RES_ARG FOR SELECT PEER
         FROM TIMETRACKING
         WHERE TIME < IN_VALUE AND STATE = 1
         GROUP BY PEER
         HAVING COUNT(*) >= IN_NUMBER;
END;
$$ LANGUAGE PLPGSQL;

-- BEGIN;
--     CALL PD_PEERS_GONE_UNTIL_TIME(RES_ARG := 'DATA', IN_VALUE := '11:00:00', IN_NUMBER := 2);
--     FETCH ALL "DATA";
-- END;

----------------------------------------------  3.22 !
-- Определить пиров, выходивших за последние N дней из кампуса больше M раз

CREATE OR REPLACE PROCEDURE PD_LOST_CAMPUS(RES_ARG INOUT REFCURSOR, IN_DAY INTEGER, IN_NUMBER INTEGER)
AS
$$
BEGIN
    OPEN RES_ARG FOR
        SELECT PEER
        FROM TIMETRACKING
        WHERE DATE > NOW()::DATE - IN_DAY + 1
          AND STATE = '2'
        GROUP BY PEER
        HAVING COUNT(*) > IN_NUMBER;
END;
$$ LANGUAGE PLPGSQL;

-- BEGIN;
--     CALL PD_LOST_CAMPUS(RES_ARG := 'DATA', IN_DAY := 3, IN_NUMBER := 3);
--     FETCH ALL "DATA";
-- END;

----------------------------------------------  3.23 !
-- Определить пира, который пришел сегодня последним

CREATE OR REPLACE PROCEDURE PD_LAST_COME_PEER(RES_ARG INOUT REFCURSOR)
AS
$$
BEGIN
    OPEN RES_ARG FOR
        SELECT PEER
        FROM TIMETRACKING
        WHERE STATE = '1'
          AND DATE = CURRENT_DATE
        ORDER BY TIME DESC
        LIMIT 1;
END;
$$ LANGUAGE PLPGSQL;

-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'kegsbett', CURRENT_DATE, '19:20:40', 1);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'rollback', CURRENT_DATE, '19:40:40', 1);

-- BEGIN;
--     CALL PD_LAST_COME_PEER(RES_ARG := 'DATA');
--     FETCH ALL "DATA";
-- END;

----------------------------------------------  3.24 !
-- Определить пиров, которые выходили вчера из кампуса больше чем на N минут

CREATE OR REPLACE PROCEDURE PD_PEERS_LEAVE_CAMPUS_MIN(RES_ARG INOUT REFCURSOR, IN_MINUTE INTEGER)
AS
$$
BEGIN
    OPEN RES_ARG FOR
        WITH TIME_OUT AS (
            SELECT *
            FROM TIMETRACKING
            WHERE STATE = 2 AND DATE = CURRENT_DATE - 1
        ),
        TIME_IN AS (
            SELECT *
            FROM TIMETRACKING
            WHERE STATE = 1 AND DATE = CURRENT_DATE - 1
        ),
        ALL_TIME AS (
            SELECT TIME_IN.PEER,
                   TIME_OUT.TIME TIME_INNER,
                   MIN(TIME_IN.TIME) TIME_OUTER
            FROM TIME_OUT
            INNER JOIN TIME_IN
            ON TIME_IN.PEER = TIME_OUT.PEER
            AND TIME_IN.TIME > TIME_OUT.TIME
            GROUP BY 1,2
        )
        SELECT PEER
        FROM (SELECT PEER,
                     SUM(TIME_OUTER - TIME_INNER)::TIME LEAVE_CAMPUS_TIME
              FROM ALL_TIME
              GROUP BY 1) T1
        WHERE MAKE_TIME(0, IN_MINUTE, 0.00) < LEAVE_CAMPUS_TIME;
END;
$$ LANGUAGE PLPGSQL;

-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'rollback', CURRENT_DATE - 1, '12:00:00', 1);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'rollback', CURRENT_DATE - 1, '12:15:00', 2);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'rollback', CURRENT_DATE - 1, '12:30:00', 1);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'rollback', CURRENT_DATE - 1, '12:45:00', 2);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'rollback', CURRENT_DATE - 1, '12:50:00', 1);
-- INSERT INTO TIMETRACKING VALUES ((SELECT MAX(ID) FROM TIMETRACKING) + 1, 'rollback', CURRENT_DATE - 1, '12:55:00', 2);

-- BEGIN;
--     CALL PD_PEERS_LEAVE_CAMPUS_MIN(RES_ARG := 'DATA', IN_MINUTE := 20);
--     FETCH ALL "DATA";
-- END;

----------------------------------------------  3.25 !
-- Определить для каждого месяца процент ранних входов

-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц,
-- приходили в кампус за всё время (будем называть это общим числом входов).

-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц,
-- приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов).

-- Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов.


CREATE OR REPLACE FUNCTION STATISTICS()
    RETURNS TABLE
            (
                MONTH INTEGER,
                COUNT INTEGER
            )
AS
$$
DECLARE
    OUT_MONTHS INTEGER ARRAY[0];
    OUT_NAMES  INTEGER ARRAY[0];
    EARLY      INTEGER ARRAY[0];
BEGIN
    FOR I IN 0..11
        LOOP
            OUT_NAMES[I] = I + 1;
            OUT_MONTHS[I] =
                    (SELECT COUNT(*)
                     FROM TIMETRACKING
                              JOIN PEERS ON TIMETRACKING.PEER = PEERS.NICKNAME
                     WHERE OUT_NAMES[I] = DATE_PART('MONTH', PEERS.BIRTHDAY)
                       AND TIMETRACKING.STATE = 1) AS GG;
            EARLY[I] =
                    (SELECT COUNT(*)
                     FROM TIMETRACKING
                              JOIN PEERS ON TIMETRACKING.PEER = PEERS.NICKNAME
                     WHERE OUT_NAMES[I] = DATE_PART('MONTH', PEERS.BIRTHDAY)
                       AND TIMETRACKING.STATE = 1
                       AND TIMETRACKING.TIME < '12:00:00'::TIME) AS GG;
            IF OUT_MONTHS[I] > 0 THEN
                OUT_MONTHS[I] = (EARLY[I] * 100) / OUT_MONTHS[I];
            END IF;
        END LOOP;

    RETURN QUERY
        SELECT UNNEST(OUT_NAMES) AS FIRST, UNNEST(OUT_MONTHS) AS SECOND;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE PROCEDURE PD_STATISTICS(RES_ARG INOUT REFCURSOR)
AS
$$
BEGIN
    OPEN RES_ARG FOR SELECT TO_CHAR(TO_DATE(H.MONTH::TEXT, 'MM'), 'MONTH') AS MOUNTH,
                            H.COUNT                                        AS PROCENT
                     FROM (SELECT GG.MONTH, GG.COUNT FROM STATISTICS() AS GG) AS H;
END;
$$ LANGUAGE PLPGSQL;

-- BEGIN;
--     CALL PD_STATISTICS(RES_ARG := 'DATA');
--     FETCH ALL "DATA";
-- END;
