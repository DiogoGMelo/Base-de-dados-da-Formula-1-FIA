CREATE OR REPLACE FUNCTION pilotos_nacionalidade(p_nacionalidade TEXT)
  RETURNS SETOF TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  rec RECORD;
  contador INT := 0;
BEGIN
  FOR rec IN
    SELECT forename, surname
      FROM drivers
     WHERE nationality = p_nacionalidade
     ORDER BY surname, forename
  LOOP
    contador := contador + 1;
    RETURN NEXT contador || ' Nome: ' || rec.forename || ' ' || rec.surname;
  END LOOP;

  IF contador = 0 THEN
    RETURN NEXT 'Nenhum piloto encontrado para nacionalidade: ' || p_nacionalidade;
  END IF;
END;
$$;
