--
-- Consultation de solde 
--

CREATE OR REPLACE FUNCTION compte_consulter_solde(p_id_compte comptes.id%TYPE)
RETURNS comptes.solde%TYPE AS $$
DECLARE
	v_solde comptes.solde%TYPE;

BEGIN
	SELECT solde 
	INTO v_solde
	FROM comptes
	WHERE id = p_id_compte;

	RETURN v_solde;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Le compte % n''existe pas', p_id_compte;

END;
$$ LANGUAGE PLPGSQL;
