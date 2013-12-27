CREATE OR REPLACE FUNCTION debitDiff() RETURNS VOID AS $$
BEGIN
    UPDATE comptes
    SET solde=solde - sommes.sum
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
                AND date >= (CURRENT_DATE-interval'1 month')
            GROUP BY source_id) AS sommes
    WHERE comptes.id=sommes.source_id;

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



