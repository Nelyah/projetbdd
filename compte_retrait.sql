--
-- Retrait
--

CREATE OR REPLACE FUNCTION compte_retrait(p_id_carte cartes.id%TYPE, 
	p_montant comptes.solde%TYPE, p_banque_etranger BOOLEAN)

RETURNS VOID AS $$
DECLARE 
	v_id_compte comptes.id%TYPE;
	v_id_carte cartes.id%TYPE;
	v_depenses REAL;
	v_plafond cartes.plafond_periodique%TYPE;
	v_type_operation types_operation.id%TYPE;

BEGIN
	SELECT cartes.id, comptes.id
	INTO v_id_carte, v_id_compte
	FROM comptes, cartes
	WHERE cartes.compte_id = comptes.id
	AND cartes.id = p_id_carte;

	IF p_montant < 0 THEN
		RAISE EXCEPTION 'Le montant de retrait ne peux etre negatif';
	END IF;

	SELECT SUM(montant)
	INTO v_depenses
	FROM operations
	WHERE type_operation_id = (
		SELECT id
		FROM types_operation
		WHERE type LIKE 'retrait'
	)
	AND source_id = v_id_compte
	AND extra = p_id_carte
	AND date >= (
		SELECT current_date - INTERVAL '7 days'
	);

	IF p_banque_etranger IS TRUE THEN
		SELECT plafond_periodique_etranger
		INTO STRICT v_plafond
		FROM cartes
		WHERE id = p_id_carte;

	ELSE
		SELECT plafond_periodique
		INTO STRICT v_plafond
		FROM cartes
		WHERE id = p_id_carte;
	END IF;

	IF v_depenses + p_montant > v_plafond THEN
		RAISE EXCEPTION 'Le plafond périodique ne peux etre depassé';
	END IF;

	-- Mise a jour du solde 
	UPDATE comptes SET
		solde = solde - p_montant
	WHERE id = v_id_compte;

	SELECT id
	INTO v_type_operation
	FROM types_operation
	WHERE type LIKE 'retrait';

	-- Creation de l'operation 
	INSERT INTO operations (type_operation_id, source_id, destination_id, montant, extra)
	VALUES (v_type_operation, v_id_compte, NULL, p_montant, p_id_carte);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'La carte % n''existe pas ou n''est associé a aucun compte', p_id_carte;

END;
$$ LANGUAGE PLPGSQL;
