CREATE OR REPLACE FUNCTION virementPonctuel(dest_iban INTEGER,dest_bic INTEGER,id_compte INTEGER, id_client INTEGER, montant_vir INTEGER) RETURNS VOID AS $$
DECLARE
    dest_id_compte INTEGER;
    responsable INTEGER;
    responsable2 INTEGER;
    mandataire INTEGER;
    type_id_operation INTEGER;
    cur_date DATE;
BEGIN
    cur_date=CURRENT_DATE;
    responsable=0;
    mandataire=0;
    SELECT id INTO dest_id_compte
    FROM comptes
    WHERE iban=dest_iban
        AND bic=dest_bic;
    -- Test si le compte de destination existe ou non
    IF dest_id_compte IS NULL
    THEN RAISE EXCEPTION 'Ce compte n''existe pas';
    END IF;

    -- Vérifie les droits de la source du virement
    SELECT est_responsable, est_mandataire INTO responsable, mandataire
    FROM titulaires
    WHERE compte_id=id_compte
        AND client_id=id_client;
    IF (responsable=0 AND mandataire=0) OR (responsable IS NULL AND mandataire IS NULL)
    THEN RAISE EXCEPTION 'Vous n''avez pas les droits de prélever sur ce compte';
    END IF;

    -- On modifie la sole des comptes.
    -- Si le virement est impossible, le trigger en charge de vérifier
    -- annulera la transaction
    UPDATE comptes SET solde=solde-montant_vir WHERE id=id_compte;
    UPDATE comptes SET solde=solde+montant_vir WHERE id=dest_id_compte;

    -- Sélection du type de l'opération
    SELECT id INTO type_id_operation
    FROM types_operation
    WHERE type='virement';

    INSERT INTO operations (type_operation_id,date,montant,source,destination)
        VALUES(type_id_operation,cur_date,montant_vir,id_compte,dest_id_compte);
    INSERT INTO operations (type_operation_id,date,montant,source,destination)
        VALUES(type_id_operation,cur_date,montant_vir,dest_id_compte,id_compte);

    -- On regarde si la personne fait un virement sur un de ses comptes
    -- Cela permettra de déterminer le forfait de virement
    responsable2=0;
    SELECT est_responsable INTO responsable2
    FROM titulaires
    WHERE dest_id_compte=compte_id;

    IF responsable2=0 OR responsable=0
    THEN 
        SELECT id INTO type_id_operation
        FROM types_operations
        WHERE type='forfait virement';
        INSERT INTO operation(type_operation_id,date,montant,source,destination)
            VALUES(type_id_operation,cur_date,1,id_compte,NULL);
    END IF;

END;
$$ LANGUAGE PLPGSQL;

