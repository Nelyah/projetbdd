CREATE OR REPLACE FUNCTION debitDiff() RETURNS VOID AS $$
DECLARE 
BEGIN
    UPDATE comptes
    SET solde=solde - sommes.sum
    FROM (SELECT source_id, SUM(montant)
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


    
END;
$$ LANGUAGE PLPGSQL;
