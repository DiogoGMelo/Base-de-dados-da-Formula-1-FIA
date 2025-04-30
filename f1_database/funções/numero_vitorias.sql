CREATE OR REPLACE FUNCTION numero_vitorias(
  p_forename TEXT,
  p_surname  TEXT,
  p_ano      INT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql AS
$$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) 
    INTO v_count
    FROM Results r
    JOIN Drivers d    ON r.DriverID      = d.DriverID
    JOIN Races   rc   ON r.RaceID        = rc.RaceID
   WHERE d.Forename    = p_forename
     AND d.Surname     = p_surname
     AND r.Position    = 1
     AND (p_ano IS NULL OR rc."Year" = p_ano);

  RETURN v_count;
END;
$$;