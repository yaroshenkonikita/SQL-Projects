CREATE VIEW V_GENERATED_DATES AS (SELECT GENERATED_DATE::DATE
                                  FROM generate_series('2022-01-01'::DATE,
                                      '2022-01-31'::DATE,
                                      '1 day'::interval)
                                      GENERATED_DATE);
