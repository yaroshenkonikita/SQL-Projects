CREATE VIEW V_SYMMETRIC_UNION AS (
    WITH
        SECOND AS (SELECT PERSON_ID
        FROM PERSON_VISITS
        WHERE VISIT_DATE = '2022-01-02'),

        SIX AS (SELECT PERSON_ID
        FROM PERSON_VISITS
        WHERE VISIT_DATE = '2022-01-06')

    (SELECT * FROM SECOND
    EXCEPT
    SELECT * FROM SIX)
    UNION ALL
    (SELECT * FROM SIX
    EXCEPT
    SELECT * FROM SECOND)
);

