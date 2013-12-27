CREATE OR REPLACE FUNCTION interditBancaire(id_client INTEGER, raison VARCHAR(256)) 
RETURNS VOID AS $$
DECLARE 
    id_compte_interdit INTEGER;
BEGIN
    UPDATE comptes SET chequier=0
    WHERE id IN (SELECT compte_id 
                    FROM titulaires
                    WHERE client_id = id_client);

    DELETE FROM cartes
    WHERE id IN (SELECT compte_id
                    FROM titulaires
                    WHERE client_id=id_client)
        AND type_carte_id <> (SELECT id
                                FROM types_carte
                                WHERE nom ='carte de retrait'
                                    OR nom = 'carte electron');

    INSERT INTO interdit_bancaire (id_client, motif,date_interdit)
        VALUES (id_client,raison,CURRENT_DATE);

END;
$$ LANGUAGE PLPGSQL;
