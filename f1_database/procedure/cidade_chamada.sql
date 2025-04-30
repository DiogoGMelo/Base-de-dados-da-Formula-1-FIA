CREATE OR REPLACE PROCEDURE cidade_chamada(p_nome_cidade TEXT)
LANGUAGE plpgsql AS
$$
DECLARE
    v_count   INT;
    rec       RECORD;
BEGIN
    -- conta quantas cidades têm exatamente o nome informado
    SELECT COUNT(*) 
      INTO v_count
      FROM GeoCities15K
     WHERE Name = p_nome_cidade;
    
    -- imprime a contagem, com pipe no final
    RAISE NOTICE 'Contagem: %|', v_count;

    -- para cada cidade encontrada, imprime nome, população e país
    FOR rec IN
      SELECT 
        g.Name,
        g.Population,
        COALESCE(c.Name, g.Country) AS Pais
      FROM GeoCities15K g
      LEFT JOIN Countries c
        ON g.Country = c.Code
     WHERE g.Name = p_nome_cidade
    LOOP
      RAISE NOTICE 'Nome: %, População: %, País: %',
                   rec.Name,
                   rec.Population,
                   rec.Pais;
    END LOOP;
END;
$$;
