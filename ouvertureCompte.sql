-- Le but de cette fonction est d'ouvrir un compte, au nom d'un ou deux clients.
-- Le paramètre "id_client2" peut être NULL, si le compte qui est ouvert n'est pas 
-- un compte co-géré. 

CREATE OR REPLACE FUNCTION ouvertureCompte(id_client INTEGER,id_client2 INTEGER, typeCompte VARCHAR(150)) RETURNS VOID AS $$
DECLARE
    type_id INTEGER;
    max_id INTEGER;
BEGIN
    SELECT id INTO type_id
    FROM types_compte
    WHERE typeCompte=type;

    INSERT INTO comptes (type_compte_id,iban,bic) VALUES(type_id,-1,-1);

-- Utile dans le cas d'un deuxième client pour un compte co-géré.
    IF id_client2 IS NOT NULL THEN
        SELECT max(id) INTO max_id
        FROM comptes;
    END IF;

    INSERT INTO titulaires (client_id,compte_id) VALUES (id_client,max_id);

    IF id_client2 IS NOT NULL THEN
        INSERT INTO titulaires (client_id,compte_id) VALUES (id_client2,max_id);
    END IF;


END;
$$ LANGUAGE PLPGSQL;

-- N'ayant pas de numéro de génération d'iban ou de bic, chacun seront égaux
-- à l'id du compte auquel ils sont associés.
-- Un trigger est lancé pour pouvoir leur permettre d'être updaté, l'id étant un serial
CREATE OR REPLACE FUNCTION modif_iban_bic() RETURNS TRIGGER AS $$
BEGIN
    new.iban=new.id;
    new.bic=new.id;
    RETURN new;

END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER ajoutCompte
    BEFORE INSERT ON comptes
    FOR EACH ROW
    EXECUTE PROCEDURE modif_iban_bic();
