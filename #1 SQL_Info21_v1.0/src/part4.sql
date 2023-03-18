-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных,
-- уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.

CREATE TABLE RETURNS_TABLE
(
    PEER     VARCHAR,
    TASK     VARCHAR,
    XPAMOUNT INTEGER
);

DROP PROCEDURE IF EXISTS PR_REMOVE_TABLE(TABLENAME VARCHAR);

CREATE OR REPLACE PROCEDURE PR_REMOVE_TABLE(IN TABLENAME TEXT)
AS
$$
BEGIN
    FOR TABLENAME IN
        SELECT QUOTE_IDENT(TABLE_NAME)
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME LIKE TABLENAME || '%'
          AND TABLE_SCHEMA LIKE 'PUBLIC'
        LOOP
            EXECUTE 'DROP TABLE ' || TABLENAME;
        END LOOP;
END
$$ LANGUAGE PLPGSQL;

BEGIN;
CALL PR_REMOVE_TABLE('RETURNS');
END;

-- 2) Создать хранимую процедуру с выходным параметром,
-- которая выводит список имен и параметров всех скалярных SQL функций
-- пользователя в текущей базе данных. Имена функций без параметров не выводить.
-- Имена и список параметров должны выводиться в одну строку.
-- Выходной параметр возвращает количество найденных функций.

DROP PROCEDURE IF EXISTS PRINT_FUNCTION_WITH_PARAMETRS CASCADE;

CREATE OR REPLACE PROCEDURE PRINT_FUNCTION_WITH_PARAMETRS(OUT COUNTOFTABLES INT)
    LANGUAGE PLPGSQL AS
$$
DECLARE
    I RECORD;
BEGIN

    CREATE VIEW LIST_FUNTIONS AS
    (
    SELECT FUNCTION || '(' || STRING_AGG(PARAMETRS, ', ') || ')' AS FUNCTION_WITH_PARAM
    FROM (SELECT ROUTINES.ROUTINE_NAME AS FUNCTION,
                 PARAMETERS.PARAMETER_MODE || ' ' ||
                 PARAMETERS.PARAMETER_NAME || ' ' ||
                 PARAMETERS.DATA_TYPE
                                       AS PARAMETRS

          FROM INFORMATION_SCHEMA.ROUTINES
                   JOIN INFORMATION_SCHEMA.PARAMETERS
                        ON ROUTINES.SPECIFIC_NAME = PARAMETERS.SPECIFIC_NAME
          WHERE ROUTINES.ROUTINE_TYPE = 'FUNCTION'
            AND PARAMETERS.SPECIFIC_SCHEMA = 'PUBLIC'
            AND PARAMETERS.SPECIFIC_SCHEMA = 'PUBLIC'
            AND PARAMETERS.PARAMETER_NAME IS NOT NULL) AS T1
    GROUP BY FUNCTION
        );

    FOR I IN (SELECT FUNCTION_WITH_PARAM FROM LIST_FUNTIONS)
        LOOP
            RAISE NOTICE '%', I.FUNCTION_WITH_PARAM;
        END LOOP;

    SELECT COUNT(*) INTO COUNTOFTABLES FROM LIST_FUNTIONS;

    DROP VIEW LIST_FUNTIONS;
END;
$$;

CALL PRINT_FUNCTION_WITH_PARAMETRS(NULL);


-- 3) Создать хранимую процедуру с выходным параметром,
-- которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.

DROP PROCEDURE IF EXISTS PR_DELETE_DML_TRIGGERS (IN REF REFCURSOR, INOUT RESULT INT);

CREATE OR REPLACE PROCEDURE PR_DELETE_DML_TRIGGERS(IN REF REFCURSOR, INOUT RESULT INT)
AS
$$
BEGIN
    FOR REF IN
        SELECT TRIGGER_NAME || ' ON ' || EVENT_OBJECT_TABLE
        FROM INFORMATION_SCHEMA.TRIGGERS
        WHERE TRIGGER_SCHEMA = 'PUBLIC'
        LOOP
            EXECUTE 'DROP TRIGGER ' || REF;
            RESULT := RESULT + 1;
        END LOOP;
END
$$ LANGUAGE PLPGSQL;

BEGIN;
CALL PR_DELETE_DML_TRIGGERS('CURSOR_NAME', 0);
END;

SELECT TRIGGER_NAME
FROM INFORMATION_SCHEMA.TRIGGERS;

-- 4) Создать хранимую процедуру с входным параметром,
-- которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.

DROP PROCEDURE IF EXISTS PR_SHOW_INFO (IN REF REFCURSOR, IN NAME TEXT);

CREATE OR REPLACE PROCEDURE PR_SHOW_INFO(IN REF REFCURSOR, IN NAME TEXT)
AS
$$
BEGIN
    OPEN REF FOR
        SELECT ROUTINE_NAME,
               ROUTINE_TYPE,
               ROUTINE_DEFINITION
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE SPECIFIC_SCHEMA = 'PUBLIC'
          AND ROUTINE_DEFINITION LIKE '%' || NAME || '%';
END
$$ LANGUAGE PLPGSQL;

BEGIN;
CALL PR_SHOW_INFO('REF', 'P2P');
FETCH ALL IN "REF";
END;
