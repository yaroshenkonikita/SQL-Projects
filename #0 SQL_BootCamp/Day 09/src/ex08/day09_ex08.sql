CREATE OR REPLACE FUNCTION FNC_FIBONACCI(
    PSTOP INTEGER DEFAULT 10
)
    RETURNS TABLE
    (
        NUMBER NUMERIC
    ) AS
$FIBONACCI$
DECLARE
    N1 NUMERIC = 0;
    N2 NUMERIC = 1;
BEGIN
    IF PSTOP > 0
    THEN
        NUMBER := N1;
        RETURN NEXT;

        IF PSTOP > 1
        THEN
            NUMBER := N2;
            RETURN NEXT;

            LOOP
                NUMBER := (NUMBER + N1);
                N1 := N2;
                N2 := NUMBER;
                EXIT WHEN NUMBER >= PSTOP;
                RETURN NEXT;
            END LOOP;
        END IF;
    END IF;
END;
$FIBONACCI$ LANGUAGE PLPGSQL;

SELECT * FROM FNC_FIBONACCI(100);
SELECT * FROM FNC_FIBONACCI();
