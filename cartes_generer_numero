CREATE OR REPLACE FUNCTION cartes_generer_numero()
RETURNS cartes.id%TYPE AS $$
DECLARE
	v_numero INTEGER;
	v_id cartes.id%TYPE;

BEGIN

	SELECT id
	INTO v_numero
	FROM (
		SELECT COALESCE(MIN(TO_NUMBER(id, '9999999999999999')), 0) AS id
		FROM cartes
		WHERE date_exp < current_date
		UNION
		SELECT COALESCE(MAX(TO_NUMBER(id, '9999999999999999')) + 1, 0) AS id
		FROM cartes
		WHERE date_exp >= current_date
	) AS s
	GROUP BY id
	LIMIT 1;

	SELECT LPAD((v_numero || ''), 16, '0')
	INTO v_id;

	RETURN v_id;

END;
$$ LANGUAGE PLPGSQL;
