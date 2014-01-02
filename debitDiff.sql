-- Cette fonction a pour but de calculer le débit différé grâce aux paiments par 
-- cartes à débit différé. Cette fonction est faite pour être exécutée à chaque 
-- début de mois, afin de calculer la somme dépensée sur le mois passé. 
-- Elle ne doit pas être lancée plus d'une fois par mois, sinon certains paiements
-- seront comptabilisés plusieurs fois.
CREATE OR REPLACE FUNCTION debitDiff() RETURNS VOID AS $$
BEGIN
-- mise à jour de la solde des comptes en fonction de ce qui a été payé avec la 
-- carte à débit différé
    UPDATE comptes
    SET solde=solde - sommes.sum
    -- Pour chaque source_id, la somme de ses dépenses en différé
    FROM (SELECT source_id, SUM(montant) as sum 
            FROM operations
            WHERE source_id IN (SELECT compte_id 
                                FROM cartes
                                WHERE type_carte_id=(SELECT type_carte_id 
                                                    FROM types_carte
                                                    WHERE nom='carte débit différé'))
                AND type_operation_id=(SELECT id
                                        FROM types_operation
                                        WHERE type='paiement différé')
                -- On ne récupère que les opérations du mois passé
                AND date >= (CURRENT_DATE-interval'1 month')
            GROUP BY source_id) AS sommes
    WHERE comptes.id=sommes.source_id;

-- On appelle la fonction "interditBancaire(client_id,'raison')" sur les comptes qui ont 
-- dépassé la limite posée par la banque
    SELECT interditBancaire(clause.client_id,'Dépassement du découvert autorisé')
    FROM (SELECT client_id 
            FROM titulaires
            WHERE est_responsable=1
                AND (SELECT solde 
                    FROM comptes
                    WHERE id=titulaires.compte_id) < (SELECT decouvert_auto_banque
                                                        FROM comptes
                                                        WHERE id=titulaires.compte_id) AS clause;

    
END;
$$ LANGUAGE PLPGSQL;



