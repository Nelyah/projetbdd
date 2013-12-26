CREATE OR REPLACE FUNCTION paiement(client INTEGER, compte_source INTEGER, compte_dest INTEGER, numCarte VARCHAR(16), montantPaiement INTEGER) 
RETURNS VOID AS $$
DECLARE
    testExists INTEGER;
    typePaiement_id INTEGER;
    compteNumCarte VARCHAR(16);
    responsable INTEGER;
    mandataire INTEGER;
    typeOperation_id INTEGER;
    typePaiement VARCHAR(256);
    montantPerio INTEGER;

BEGIN
    IF numCarte='cheque'
    THEN typePaiement=numCarte;
    ELSE
        SELECT nom INTO typePaiement
        FROM types_carte
        WHERE id = (SELECT type_carte_id
                    FROM cartes
                    WHERE id=numCarte);
    END IF;
    RAISE NOTICE '%',typePaiement;

    testExists=1;
    SELECT id INTO testExists
    FROM comptes
    WHERE id=compte_source;
    IF testExists IS NULL 
    THEN RAISE EXCEPTION 'Ce compte source n''existe pas';
    END IF;

    responsable=0;
    mandataire=0;
    SELECT est_responsable, est_mandataire INTO responsable, mandataire
    FROM titulaires
    WHERE compte_id=compte_source
        AND client_id=client;
    IF (responsable=0 AND mandataire=0) OR (responsable IS NULL AND mandataire IS NULL)
    THEN RAISE EXCEPTION 'Vous n''avez pas les droits de prélever sur ce compte';
    END IF;

    testExists=1;
    SELECT id INTO testExists
    FROM comptes
    WHERE id=compte_dest;
    IF testExists IS NULL 
    THEN RAISE EXCEPTION 'Ce compte destinataire n''existe pas';
        RETURN;
    END IF;

    IF typePaiement='cheque'
    THEN 
        IF (SELECT chequier
            FROM comptes
            WHERE id=compte_source) = 0
        THEN RAISE EXCEPTION 'Vous n''avez pas de chequier sur ce compte';
            RETURN;
        ELSE 
            SELECT id INTO typeOperation_id
            FROM types_operation
            WHERE type='cheque';
            INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id,extra)
                                VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, NULL);
            UPDATE comptes SET solde = solde - montantPaiement WHERE id = compte_source;
            UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
            RETURN;
        END IF;
    END IF;     

    SELECT id INTO typePaiement_id
    FROM types_carte
    WHERE nom=typePaiement;
    IF typePaiement_id IS NULL
    THEN RAISE EXCEPTION 'Cette carte n''existe pas';
        RETURN;
    END IF;

    SELECT id INTO compteNumCarte
    FROM cartes
    WHERE compte_id = compte_source;
    IF compteNumCarte IS NULL
    THEN RAISE EXCEPTION 'Vous ne possédez pas cette carte';
        RETURN;
    END IF;

    IF typePaiement='carte débit différé'
    THEN
        SELECT id INTO typeOperation_id
        FROM types_operation
        WHERE type='paiement différé';
        INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id,extra)
                            VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, numCarte);
        UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
        RETURN;
    ELSIF typePaiement='carte de paiement'
    THEN 
        SELECT SUM(montant) INTO montantPerio
        FROM operations
        WHERE type_operation_id = (
            SELECT id
            FROM type_operation
            WHERE type= 'paiement';
        )
            AND extra = numCarte
            AND date > CURRENT_DATE-interval '1 week';
        IF montantPaiement > (SELECT plafond_paiement
                                            FROM cartes
                                            WHERE id = numCarte)
        THEN RAISE EXCEPTION 'Paiement refusé (votre paiement est trop élevé)';
            RETURN;
        END IF;
        IF montantPerio + montantPaiement > (SELECT plafond_periodique
                                            FROM cartes
                                            WHERE id = numCarte)
        THEN RAISE EXCEPTION 'Paiement refusé (plafond periodique dépassé)';
            RETURN;
        END IF;

        SELECT id INTO typeOperation_id
        FROM types_operation
        WHERE type='paiement carte';
        INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id,extra)
                            VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, numCarte);
        UPDATE comptes SET solde = solde - montantPaiement WHERE id = compte_source;
        UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
    ELSIF typePaiement='carte electron'
    THEN 
        SELECT SUM(montant) INTO montantPerio
        FROM operations
        WHERE type_operation_id = (SELECT id
                                    FROM type_operation
                                    WHERE type= 'paiement');
            AND extra = numCarte
            AND date > CURRENT_DATE-interval '1 week';

        IF montantPaiement > (SELECT plafond_paiement
                                            FROM cartes
                                            WHERE id = numCarte)
        THEN RAISE EXCEPTION 'Paiement refusé (votre paiement est trop élevé)';
            RETURN;
        END IF;

        IF montantPerio + montantPaiement > (SELECT plafond_periodique
                                            FROM cartes
                                            WHERE id = numCarte)
        THEN RAISE EXCEPTION 'Paiement refusé (plafond periodique dépassé)';
            RETURN;
        END IF;

        IF montantPaiement > (SELECT solde
                                FROM comptes
                                WHERE id=compte_source)
        THEN RAISE EXCEPTION 'Paiement refusé';
            RETURN;
        ELSE
            SELECT id INTO typeOperation_id
            FROM types_operation
            WHERE type='paiement carte';
            INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id, extra)
                                VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, numCarte);
            UPDATE comptes SET solde = solde - montantPaiement WHERE id = compte_source;
            UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
        END IF;
    ELSIF typePaiement='carte de retrait'
    THEN RAISE EXCEPTION 'Cette carte ne peut pas effectuer de paiement';
        RETURN;
    END IF;

END;
$$ LANGUAGE PLPGSQL;



