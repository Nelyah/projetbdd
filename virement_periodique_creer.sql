-- 
-- Virement Periodique
--

CREATE OR REPLACE FUNCTION virement_periodique_creer(p_id_source comptes.id%TYPE, 
	p_id_destination comptes.id%TYPE, p_montant comptes.solde%TYPE, 
	p_jour virements_periodique.jour%TYPE, p_periode virements_periodique.periode%TYPE, 
	p_date_fin virements_periodique.date_fin%TYPE)

RETURNS VOID AS $$

DECLARE
	v_compte_courrant comptes.id%TYPE;
	v_compte_id comptes.id%TYPE;
	v_type_operation types_operation.id%TYPE;
	v_montant operations.montant%TYPE;

	v_date_suivante virements_periodique.date_suivante%TYPE;
	v_interval_jours INTEGER;
	v_jour INTEGER;
	v_mois INTEGER;

BEGIN 
	
	v_compte_courrant = p_id_source;
	
	SELECT id
	INTO v_compte_id
	FROM comptes
	WHERE id = v_compte_courrant;
	
	v_compte_courrant = p_id_destination;
	
	SELECT id
	INTO v_compte_id
	FROM comptes
	WHERE id = v_compte_courrant;

	IF p_montant < 0 THEN
		RAISE EXCEPTION 'Le montant de retrait ne peux etre negatif';
	END IF;

	IF p_periode < 1 OR p_periode > 12 THEN
		RAISE EXCEPTION 'La periode de retrait doit etre comprise entre 1 et 12';
	END IF;

	IF p_jour < 1 OR p_jour > 31 THEN
		RAISE EXCEPTION 'Le jour doit etre compris entre 1 et 31';
	END IF;

	SELECT current_date
	INTO v_date_suivante;

	SELECT date_part('day', current_timestamp)
	INTO v_jour;

	SELECT date_part('month', current_timestamp)
	INTO v_mois;

	SELECT forfait_virement_ajout
	INTO v_montant
	FROM comptes, types_compte
	WHERE comptes.type_compte_id = types_compte.id
	AND comptes.id = p_id_source;

	UPDATE comptes SET
		solde = solde - v_montant
	WHERE id = p_id_source;

	-- Si le jour est depassé
	IF v_jour > p_jour THEN
		-- Ajout d'un mois
		SELECT v_date_suivante + INTERVAL '1 month'
		INTO v_date_suivante;
	END IF;

	-- on retire l'interval de jour
	v_interval_jours = v_jour - p_jour;

	SELECT v_date_suivante - (v_interval_jours || ' days')::INTERVAL
	INTO v_date_suivante;

	SELECT id
	INTO v_type_operation
	FROM types_operation
	WHERE type LIKE 'forfait virement ajout';

	-- Creation de l'operation 
	INSERT INTO operations (type_operation_id, source_id, destination_id, montant)
	VALUES (v_type_operation, p_id_source, NULL, v_montant);

	INSERT INTO virements_periodique (periode, jour, date_suivante, date_fin, montant, source_id, destination_id)
	VALUES (p_periode, p_jour, v_date_suivante, p_date_fin, p_montant, p_id_source, p_id_destination);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Le compte % n''existe pas', v_compte_courrant;

END;
$$ LANGUAGE PLPGSQL;
