--
-- TRIGGER test solde
--

CREATE OR REPLACE FUNCTION compte_tester_solde() 
RETURNS trigger AS $$
BEGIN
    IF NEW.solde < NEW.decouvert_auto_banque THEN
        RAISE EXCEPTION 'solde inférieur au decouvert autorisé par la banque';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER compte_tester_solde 
BEFORE INSERT OR UPDATE ON comptes
FOR EACH ROW EXECUTE PROCEDURE compte_tester_solde();
