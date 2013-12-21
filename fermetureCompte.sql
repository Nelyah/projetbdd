CREATE OR REPLACE FUNCTION fermetureCompte(id_client INTEGER,id_compte INTEGER) RETURNS VOID AS $$
DECLARE 
    responsable INTEGER;
    mandataire INTEGER;
BEGIN
    responsable=0;
    mandataire=0;
    SELECT est_responsable, est_mandataire INTO responsable,mandataire
    FROM titulaires
    WHERE client_id=id_client
        AND compte_id=id_compte;
    IF (responsable=0 AND mandataire=0) OR (responsable IS NULL AND mandataire IS NULL)
    THEN 
        RAISE EXCEPTION 'Vous ne possédez pas les droits sur ce compte.';
        RETURN;
    END IF;
    UPDATE comptes SET solde=0,actif=0,chequier=0 
    WHERE comptes.id=id_compte;
-- d'autres info à faire avec ça (terminer les virements, supprimer les cartes, etc.
END;
$$ LANGUAGE PLPGSQL;
