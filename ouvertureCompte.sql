CREATE OR REPLACE FUNCTION ouvertureCompte(id_client INTEGER,id_client2 INTEGER, typeCompte VARCHAR(150)) RETURNS VOID AS $$
DECLARE
    type_id INTEGER;
    max_id INTEGER;
BEGIN
    SELECT id INTO type_id
    FROM types_compte
    WHERE typeCompte=type;
    INSERT INTO comptes (type_compte_id,iban,bic) VALUES(type_id,-1,-1);
    SELECT max(id) INTO max_id
    FROM comptes;
    INSERT INTO titulaires (client_id,compte_id) VALUES (id_client,max_id);
    IF id_client2 IS NOT NULL
    THEN INSERT INTO titulaires (client_id,compte_id) VALUES (id_client2,max_id);
    END IF;


END;
$$ LANGUAGE PLPGSQL;

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
