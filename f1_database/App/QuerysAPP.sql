CREATE TABLE USERS (
    UserID SERIAL PRIMARY KEY,
    Login VARCHAR(100) UNIQUE NOT NULL,
    Password TEXT NOT NULL,
    Tipo VARCHAR(20) NOT NULL CHECK (Tipo IN ('Administrador', 'Escuderia', 'Piloto')),
    IdOriginal INT
);
CREATE TABLE Users_Log (
    LogID SERIAL PRIMARY KEY,
    UserID INT NOT NULL,
    DataLogin TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserID) REFERENCES USERS(UserID)
);
CREATE OR REPLACE FUNCTION trg_insere_usuario_escuderia()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM USERS WHERE Login = NEW.ConstructorRef || '_c') THEN
        RAISE EXCEPTION 'Login para esta escuderia já existe.';
    END IF;

    INSERT INTO USERS (Login, Password, Tipo, IdOriginal)
    VALUES (NEW.ConstructorRef || '_c', crypt(NEW.ConstructorRef, gen_salt('bf')), 'Escuderia', NEW.ConstructorID);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apos_inserir_constructor
AFTER INSERT ON Constructors
FOR EACH ROW
EXECUTE FUNCTION trg_insere_usuario_escuderia();
CREATE OR REPLACE FUNCTION trg_insere_usuario_piloto()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM USERS WHERE Login = NEW.DriverRef || '_d') THEN
        RAISE EXCEPTION 'Login para este piloto já existe.';
    END IF;

    INSERT INTO USERS (Login, Password, Tipo, IdOriginal)
    VALUES (NEW.DriverRef || '_d', crypt(NEW.DriverRef, gen_salt('bf')), 'Piloto', NEW.DriverID);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apos_inserir_driver
AFTER INSERT ON Drivers
FOR EACH ROW
EXECUTE FUNCTION trg_insere_usuario_piloto();
CREATE OR REPLACE FUNCTION admin_relatorio_status_resultados()
RETURNS TABLE(Status VARCHAR, Quantidade BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT s.Status, COUNT(r.ResultID)
    FROM Results r
    JOIN Status s ON r.StatusID = s.StatusID
    GROUP BY s.Status
    ORDER BY s.Status;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION calcular_distancia(lat1 FLOAT, lon1 FLOAT, lat2 FLOAT, lon2 FLOAT)
RETURNS FLOAT AS $$
DECLARE
    raio_terra CONSTANT FLOAT := 6371; -- em KM
    dLat FLOAT;
    dLon FLOAT;
    a FLOAT;
    c FLOAT;
BEGIN
    dLat := RADIANS(lat2 - lat1);
    dLon := RADIANS(lon2 - lon1);
    a := SIN(dLat / 2) * SIN(dLat / 2) + COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * SIN(dLon / 2) * SIN(dLon / 2);
    c := 2 * ATAN2(SQRT(a), SQRT(1 - a));
    RETURN raio_terra * c;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION admin_relatorio_aeroportos_proximos(nome_cidade VARCHAR)
RETURNS TABLE(NomeCidade VARCHAR, CodigoIATA VARCHAR, NomeAeroporto VARCHAR, CidadeAeroporto VARCHAR, Distancia FLOAT, TipoAeroporto VARCHAR) AS $$
BEGIN
    CREATE INDEX IF NOT EXISTS idx_geocities_name ON GeoCities15K(Name);
    CREATE INDEX IF NOT EXISTS idx_airports_type ON Airports(Type);

    RETURN QUERY
    SELECT g.Name, a.IATACode, a.Name, a.City, calcular_distancia(g.Lat, g.Long, a.LatDeg, a.LongDeg), a.Type
    FROM GeoCities15K g, Airports a
    WHERE g.Name = nome_cidade AND a.ISOCountry = 'BR' AND a.Type IN ('medium_airport', 'large_airport')
      AND calcular_distancia(g.Lat, g.Long, a.LatDeg, a.LongDeg) <= 100;
END;
$$ LANGUAGE plpgsql;

-- Nível 1: Corridas totais por escuderia
CREATE OR REPLACE FUNCTION admin_relatorio_escuderias_corridas_totais()
RETURNS TABLE(NomeEscuderia VARCHAR, TotalCorridas BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT c.Name, COUNT(DISTINCT r.RaceID)
    FROM Constructors c
    JOIN Results res ON c.ConstructorID = res.ConstructorID
    JOIN Races r ON res.RaceID = r.RaceID
    GROUP BY c.Name;
END;
$$ LANGUAGE plpgsql;

-- Nível 2 e 3: Corridas por circuito e detalhes
CREATE OR REPLACE FUNCTION admin_relatorio_corridas_por_circuito(escuderia_id INT)
RETURNS TABLE(NomeCircuito VARCHAR, MinVoltas INT, MediaVoltas NUMERIC, MaxVoltas INT, TotalVoltas INT, TempoTotal VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT
        circ.Name,
        MIN(res.Laps)::INT,
        AVG(res.Laps),
        MAX(res.Laps)::INT,
        SUM(res.Laps)::INT,
        TO_CHAR(SUM(res.Milliseconds) * interval '1 millisecond', 'HH24:MI:SS')
    FROM Results res
    JOIN Races r ON res.RaceID = r.RaceID
    JOIN Circuits circ ON r.CircuitID = circ.CircuitID
    WHERE res.ConstructorID = escuderia_id
    GROUP BY circ.Name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION escuderia_relatorio_vitorias_pilotos(id_construtor INT)
RETURNS TABLE(NomeCompletoPiloto VARCHAR, QuantidadeVitorias BIGINT) AS $$
BEGIN
    CREATE INDEX IF NOT EXISTS idx_results_pos_driver_constructor ON Results(Position, DriverID, ConstructorID);

    RETURN QUERY
    SELECT d.Forename || ' ' || d.Surname AS NomeCompleto, COUNT(res.ResultID)
    FROM Results res
    JOIN Drivers d ON res.DriverID = d.DriverID
    WHERE res.ConstructorID = id_construtor AND res.Position = 1
    GROUP BY NomeCompleto
    ORDER BY QuantidadeVitorias DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION escuderia_relatorio_status(id_construtor INT)
RETURNS TABLE(Status VARCHAR, Quantidade BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT s.Status, COUNT(res.ResultID)
    FROM Results res
    JOIN Status s ON res.StatusID = s.StatusID
    WHERE res.ConstructorID = id_construtor
    GROUP BY s.Status
    ORDER BY s.Status;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION piloto_relatorio_pontos_por_ano(id_piloto INT)
RETURNS TABLE(Ano INT, NomeCorrida VARCHAR, Pontos FLOAT) AS $$
BEGIN
    CREATE INDEX IF NOT EXISTS idx_results_driver_points ON Results(DriverID, Points);

    RETURN QUERY
    SELECT r.Year, r.Name, res.Points
    FROM Results res
    JOIN Races r ON res.RaceID = r.RaceID
    WHERE res.DriverID = id_piloto AND res.Points > 0
    ORDER BY r.Year, r.Date;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION piloto_relatorio_status(id_piloto INT)
RETURNS TABLE(Status VARCHAR, Quantidade BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT s.Status, COUNT(res.ResultID)
    FROM Results res
    JOIN Status s ON res.StatusID = s.StatusID
    WHERE res.DriverID = id_piloto
    GROUP BY s.Status
    ORDER BY s.Status;
END;
$$ LANGUAGE plpgsql;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
INSERT INTO USERS (Login, Password, Tipo, IdOriginal)
VALUES ('admin', crypt('admin', gen_salt('bf')), 'Administrador', NULL);

INSERT INTO USERS (Login, Password, Tipo, IdOriginal)
SELECT 
    c.ConstructorRef || '_c',                         -- Cria o login, ex: 'mclaren_c'
    crypt(c.ConstructorRef, gen_salt('bf')),          -- Cria a senha criptografada
    'Escuderia',                                      -- Define o tipo de usuário
    c.ConstructorID                                   -- Armazena o ID original
FROM 
    Constructors c
WHERE 
    NOT EXISTS (
        -- Garante que o usuário não seja inserido se já existir um com o mesmo login
        SELECT 1 FROM USERS u WHERE u.Login = c.ConstructorRef || '_c'
    );

INSERT INTO USERS (Login, Password, Tipo, IdOriginal)
SELECT 
    d.DriverRef || '_d',                              -- Cria o login, ex: 'hamilton_d'
    crypt(d.DriverRef, gen_salt('bf')),               -- Cria a senha criptografada
    'Piloto',                                         -- Define o tipo de usuário
    d.DriverID                                        -- Armazena o ID original
FROM 
    Drivers d
WHERE 
    NOT EXISTS (
        -- Garante que o usuário não seja inserido se já existir um com o mesmo login
        SELECT 1 FROM USERS u WHERE u.Login = d.DriverRef || '_d'
    );

DROP FUNCTION escuderia_relatorio_vitorias_pilotos(integer);

CREATE OR REPLACE FUNCTION escuderia_relatorio_vitorias_pilotos(id_construtor INT)
RETURNS TABLE(NomeCompletoPiloto TEXT, QuantidadeVitorias BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.Forename || ' ' || d.Surname,
        COUNT(res.ResultID)
    FROM 
        Results res
    JOIN 
        Drivers d ON res.DriverID = d.DriverID
    WHERE 
        res.ConstructorID = id_construtor AND res.Position = 1
    GROUP BY 
        d.Forename, d.Surname
    ORDER BY 
        COUNT(res.ResultID) DESC;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION piloto_relatorio_pontos_por_ano(integer);

CREATE OR REPLACE FUNCTION piloto_relatorio_pontos_por_ano(id_piloto INT)
-- A coluna de retorno agora é NUMERIC para corresponder ao tipo de dado real
RETURNS TABLE(Ano INT, NomeCorrida VARCHAR, Pontos NUMERIC) AS $$
BEGIN
    -- O índice abaixo ajuda na performance da consulta
    CREATE INDEX IF NOT EXISTS idx_results_driver_points ON Results(DriverID, Points);

    RETURN QUERY
    SELECT 
        r.Year, 
        r.Name, 
        res.Points
    FROM 
        Results res
    JOIN 
        Races r ON res.RaceID = r.RaceID
    WHERE 
        res.DriverID = id_piloto AND res.Points > 0
    ORDER BY 
        r.Year, r.Date;
END;
$$ LANGUAGE plpgsql;

-- Renomeia a coluna para um nome mais genérico
ALTER TABLE Users_Log RENAME COLUMN DataLogin TO EventTimestamp;

-- Adiciona uma coluna para registrar o tipo de evento ('login' ou 'logout')
ALTER TABLE Users_Log ADD COLUMN EventType VARCHAR(7) NOT NULL DEFAULT 'login';
