CREATE OR REPLACE FUNCTION interet() RETURNS VOID AS $$
DECLARE
BEGIN
    UPDATE comptes 
    SET solde=solde+solde*(SELECT taux_interet
                            FROM types_compte
                            WHERE comptes.type_compte_id=id);

END;
$$ LANGUAGE PLPGSQL;
