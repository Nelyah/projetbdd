CREATE OR REPLACE FUNCTION fermetureCompte(id_client INTEGER,id_client2 INTEGER, id_compte INTEGER) RETURNS VOID AS $$
DECLARE 
    responsable INTEGER;
    responsable2 INTEGER;
    nombre INTEGER;
BEGIN
    responsable=0;
    responsable2=0;
    
    SELECT est_responsable INTO responsable
    FROM titulaires
    WHERE client_id=id_client
        AND compte_id=id_compte;

    SELECT est_responsable INTO responsable2 
    FROM titulaires
    WHERE client_id=id_client2
        AND compte_id=id_compte;
    
    SELECT count(*) INTO nombre
    FROM titulaires
    WHERE compte_id=id_compte
    AND est_responsable=1;

    IF nombre >= 2 
       AND (id_client2 IS NULL OR id_client IS NULL)
    THEN RAISE EXCEPTION 'Les deux responsables du compte co-géré doivent être présents pour la fermeture';
    ELSIF nombre >=2 AND (responsable=0 OR responsable2=0) OR (responsable IS NULL OR responsable2 IS NULL)
    THEN RAISE EXCEPTION 'Un des deux client ne possède pas les droits sur ce compte.';
    END IF;

    IF (responsable=0) OR (responsable IS NULL)
    THEN 
        RAISE EXCEPTION 'Vous ne possédez pas les droits sur ce compte.';
        RETURN;
    END IF;
    UPDATE comptes SET solde=0,actif=0,chequier=0 
    WHERE comptes.id=id_compte;
-- d'autres info à faire avec ça (terminer les virements, supprimer les cartes, etc.
END;
$$ LANGUAGE PLPGSQL;
