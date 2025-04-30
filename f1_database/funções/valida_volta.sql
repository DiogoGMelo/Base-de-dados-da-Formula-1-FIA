CREATE OR REPLACE FUNCTION valida_volta(
  p_nome_autodromo   TEXT,
  p_pais_autodromo    TEXT,
  p_ano               INT,
  p_forename          TEXT,
  p_surname           TEXT,
  p_numero_volta      INT
)
RETURNS TABLE(
  driver_id INT,
  race_id   INT,
  status    INT
)
LANGUAGE plpgsql AS
$$
DECLARE
  v_driver    INT;
  v_circuit   INT;
  v_race      INT;
  v_count     INT;
  v_lastlap   INT;
BEGIN
  -- 3: piloto não existe
  SELECT d.driverid
    INTO v_driver
    FROM drivers d
   WHERE d.forename = p_forename
     AND d.surname  = p_surname;
  IF NOT FOUND THEN
    status := 3;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 4: autódromo não existe
  SELECT c.circuitid
    INTO v_circuit
    FROM circuits c
   WHERE c.name    = p_nome_autodromo
     AND c.country = p_pais_autodromo;
  IF NOT FOUND THEN
    driver_id := v_driver;
    status    := 4;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 5: corrida não existe naquele autódromo/ano
  SELECT r.raceid
    INTO v_race
    FROM races r
   WHERE r.circuitid = v_circuit
     AND r.year      = p_ano;
  IF NOT FOUND THEN
    driver_id := v_driver;
    status    := 5;
    RETURN NEXT;
    RETURN;
  END IF;

  -- quantas voltas já registradas para esse piloto/essa corrida?
  SELECT COUNT(*)
    INTO v_count
    FROM laptimes lt
   WHERE lt.raceid   = v_race
     AND lt.driverid = v_driver;

  IF v_count = 0 THEN
    -- 2: nenhuma volta anterior; só pode inserir se for a volta 1
    IF p_numero_volta = 1 THEN
      status := 2;
    ELSE
      status := 6;
    END IF;
    driver_id := v_driver;
    race_id   := v_race;
    RETURN NEXT;
    RETURN;
  END IF;

  -- já existe registro dessa volta?
  IF EXISTS(
    SELECT 1
      FROM laptimes lt
     WHERE lt.raceid   = v_race
       AND lt.driverid = v_driver
       AND lt.lap      = p_numero_volta
  ) THEN
    -- 1: pode substituir
    driver_id := v_driver;
    race_id   := v_race;
    status    := 1;
    RETURN NEXT;
    RETURN;
  END IF;

  -- obtém a última volta registrada
  SELECT MAX(lt.lap)
    INTO v_lastlap
    FROM laptimes lt
   WHERE lt.raceid   = v_race
     AND lt.driverid = v_driver;

  IF v_lastlap = p_numero_volta - 1 THEN
    -- 0: tudo certo, pode inserir
    status := 0;
  ELSE
    -- 6: falta a volta anterior
    status := 6;
  END IF;

  driver_id := v_driver;
  race_id   := v_race;
  RETURN NEXT;
END;
$$;
