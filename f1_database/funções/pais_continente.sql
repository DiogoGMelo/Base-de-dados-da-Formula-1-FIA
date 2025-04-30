CREATE OR REPLACE FUNCTION pais_continente()
  RETURNS TABLE(nome TEXT, continente TEXT)
  LANGUAGE plpgsql AS
$$
DECLARE
  cur_paises  CURSOR FOR
    SELECT name, continent
      FROM countries;
  rec         RECORD;
BEGIN
  OPEN cur_paises;
  LOOP
    FETCH cur_paises INTO rec;
    EXIT WHEN NOT FOUND;
    IF LENGTH(rec.name) <= 15 THEN
      nome      := rec.name;
      continente := rec.continent;
      RETURN NEXT;
    END IF;
  END LOOP;
  CLOSE cur_paises;
END;
$$;
