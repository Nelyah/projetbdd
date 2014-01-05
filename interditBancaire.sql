-- Cette fonction a pour but d'interdire bancaire un client, pour une certaine raison.
-- (en général un dépassement de la limite)
CREATE OR REPLACE FUNCTION interditBancaire(f_id_client INTEGER, raison VARCHAR(256)) 
RETURNS VOID AS $$
DECLARE 
    id_compte_interdit INTEGER;
BEGIN
-- Tous les chèques du client sont supprimés
    UPDATE comptes SET chequier=0
    WHERE id IN (SELECT compte_id 
                    FROM titulaires
                    WHERE client_id = f_id_client);

-- Toutes les cartes qui ne sont pas des cartes électrons ou des 
-- cartes de retraits sont supprimées.
    DELETE FROM cartes
    WHERE id IN (SELECT compte_id
                    FROM titulaires
                    WHERE client_id=f_id_client)
        AND type_carte_id NOT IN (SELECT id
                                FROM types_carte
                                WHERE nom ='carte de retrait'
                                    OR nom = 'carte electron');

-- On ajoute ce client à la table d'interdit bancaire
IF f_id_client NOT IN (SELECT id_client
                        FROM interdit_bancaire) THEN
        INSERT INTO interdit_bancaire (id_client, motif,date_interdit,date_regularisation)
            VALUES (f_id_client,raison,CURRENT_DATE,CURRENT_DATE+interval'5 year');
     END IF;

END;
$$ LANGUAGE PLPGSQL;
