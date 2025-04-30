CREATE OR REPLACE FUNCTION nome_nacionalidade(p_escuderia TEXT)
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  v_nacionalidade TEXT;
BEGIN
  SELECT nationality
    INTO v_nacionalidade
    FROM constructors
   WHERE name = p_escuderia;

  IF NOT FOUND THEN
    RETURN 'Escuderia não encontrada';
  ELSE
    RETURN v_nacionalidade;
  END IF;
END;
$$;

