-- Le principe de cette fonction est d'ajouter un chéquier à un compte si jamais 
-- celui ci n'en possède pas déjà
CREATE OR REPLACE FUNCTION ajoutChequier(id_client_f INTEGER, id_compte INTEGER) 
RETURNS VOID AS $$
DECLARE
    responsable INTEGER;
    mandataire INTEGER;
    line types_carte%ROWTYPE;
BEGIN
--Vérification des droits du client sur ce compte
    responsable=0;
    mandataire=0;
    SELECT est_responsable, est_mandataire INTO responsable, mandataire
    FROM titulaires
    WHERE client_id=id_client_f
        AND compte_id=id_compte;

    IF (responsable=0 AND mandataire=0) OR (responsable IS NULL AND mandataire IS NULL)
    THEN RAISE EXCEPTION 'Vous n''avez pas les droits sur ce compte';
        RETURN;
    END IF;

-- Vérification de l'existance ou non d'un chéquier sur le compte
    IF (SELECT chequier FROM comptes WHERE id=id_compte)=1
    THEN RAISE EXCEPTION 'Vous avez déjà un chequier sur ce compte';
    END IF;

-- Vérification de l'interdit bancaire
    IF (SELECT id_client FROM interdit_bancaire
        WHERE interdit_bancaire.id_client=id_client_f) IS NOT NULL 
    THEN RAISE EXCEPTION 'Vous êtes interdit bancaire, les chèques ne sont pas autorisés';
        RETURN;
    END IF;

-- Ajout du chequier
    UPDATE comptes set chequier=1 
    WHERE id=id_compte;

END;
$$ LANGUAGE PLPGSQL;
