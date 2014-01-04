-- 
-- Routine Quotidienne
--

CREATE OR REPLACE FUNCTION routine_quotidienne()
RETURNS VOID AS $$
DECLARE

	-- Recuperation de tous les virements periodique
	c_virements CURSOR FOR
		SELECT id, source_id, destination_id, montant, jour, periode
		FROM virements_periodique
		WHERE date_suivante = current_date
		AND (
			date_fin IS NULL
			OR date_fin >= current_date
		);

	r_virement RECORD;

	v_solde comptes.solde%TYPE;
	v_decouvert_auto_banque comptes.decouvert_auto_banque%TYPE;
	v_forfait types_compte.forfait_virement_periodique%TYPE;
	v_type_operation_forfait types_operation.id%TYPE;
	v_type_operation_virement types_operation.id%TYPE;

BEGIN

	OPEN c_virements;

	LOOP
		FETCH c_virements INTO r_virement;
		EXIT WHEN NOT FOUND;

		-- Recuperation du montant forfaitaire d'execution du virement
		SELECT forfait_virement_periodique
		INTO v_forfait
		FROM types_compte, comptes
		WHERE types_compte.id = comptes.type_compte_id
		AND comptes.id = r_virement.source_id;
		
		-- Recuperation du solde apres l'execution du virement et applciation des frais
		SELECT solde - (v_forfait + r_virement.montant)
		INTO v_solde
		FROM comptes
		WHERE comptes.id = r_virement.source_id;

		-- Recuperation du decouvert autorisé par la banque  pour tester la 
		-- possibilité d'effectuer le virement
		SELECT decouvert_auto_banque
		INTO v_decouvert_auto_banque
		FROM comptes
		WHERE id = r_virement.source_id;

		-- Recuperation de l'id correspondant à une operation de type 'forfait virement'
		SELECT id
		INTO v_type_operation_forfait
		FROM types_operation
		WHERE type LIKE 'forfait virement';

		-- Recuperation de l'id correspondant à une operation de type 'virement'
		SELECT id
		INTO v_type_operation_virement
		FROM types_operation
		WHERE type LIKE 'virement';

		-- Si on peux faire le virement
		IF (v_solde >= (-v_decouvert_auto_banque)) THEN

			RAISE NOTICE 'viremenet de % vers % pour %e', r_virement.source_id, r_virement.destination_id, r_virement.montant;

			-- Mise a jour du solde source
			UPDATE comptes SET
				solde = v_solde
			WHERE id = r_virement.source_id;

			-- mise a joru du solde destination
			UPDATE comptes SET
				solde = solde + r_virement.montant
			WHERE id = r_virement.destination_id;

			-- enregistrement des l'operation
			INSERT INTO operations (type_operation_id, source_id, destination_id, montant)
			VALUES (v_type_operation_virement, r_virement.source_id, r_virement.destination_id, r_virement.montant);

			INSERT INTO operations (type_operation_id, source_id, destination_id, montant)
			VALUES (v_type_operation_forfait, r_virement.source_id, NULL, v_forfait);

		END IF;

		UPDATE virements_periodique SET
			date_suivante = date_suivante + (r_virement.periode || ' months')::INTERVAL
		WHERE id = r_virement.id;

	END LOOP;

	CLOSE c_virements;


END;
$$ LANGUAGE PLPGSQL;
