-- (1) Générer une carte bancaire (l. 24 et l. 57)
-- (2) Ajout d'un chéquier (l. 116)
-- (3) Consultation du solde (l. 161)
-- (4) Retrait (l. 185)
-- (5) Trigger test_solde (l. 295)
-- (6) Interdiction bancaire (l. 316)
-- (7) Fermeture du compte (l. 357)
-- (8) Calcul du débit différé. Appartient à la routine mensuelle (l. 402)
-- (9) Interet. Appartient à la routine mensuelle (l. 457)
-- (10) Ouverture du compte (l. 476)
-- (11) Paiement (l. 530)
-- (12) Routine quotidienne (l. 728)
-- (13) Virement Périodique (l. 833)
-- (14) Virement ponctuel (l. 935)


--------------------------------
-- (1) Générer une carte bancaire
--------------------------------

-- Cette fonction a pour but de générer un numéro de carte bancaire
-- Elle choisira le plus petit numéro disponible (un numéro disponible est 
-- un numéro soit périmé, soit non existant).
CREATE OR REPLACE FUNCTION cartes_generer_numero()
RETURNS cartes.id%TYPE AS $$
DECLARE
	v_numero INTEGER;
	v_id cartes.id%TYPE;

BEGIN

	SELECT id
	INTO v_numero
	FROM (
		SELECT MIN(TO_NUMBER(numero, '9999999999999999')) AS numero
		FROM cartes
		WHERE date_exp < current_date
		UNION
		SELECT COALESCE(MAX(TO_NUMBER(numero, '9999999999999999')) + 1, 0) AS numero
		FROM cartes
		WHERE date_exp >= current_date
	) AS s
	GROUP BY numero
    ORDER BY numero ASC
	LIMIT 1;

	SELECT LPAD((v_numero || ''), 16, '0')
	INTO v_id;

	RETURN v_id;

END;
$$ LANGUAGE PLPGSQL;

-- Cette fonction prend en argument l'id du client, l'id du compte où la carte va être ajoutée
-- et le nom de la carte à ajouter.
CREATE OR REPLACE FUNCTION ajoutCarte(id_client_f INTEGER, id_compte INTEGER, carte VARCHAR(256)) 
RETURNS VOID AS $$
DECLARE
    responsable INTEGER;
    mandataire INTEGER;
    numCarte VARCHAR(16);
    line types_carte%ROWTYPE;
BEGIN

-- vérification des droits du client sur le compte
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

-- Vérification du type de carte
    IF (SELECT id FROM types_carte
        WHERE carte=nom) IS NULL
    THEN
        RAISE EXCEPTION 'Le type de carte donné (%) n''existe pas',carte;
    END IF;

-- Vérification si le client n'est pas interdit bancaire
    IF (SELECT id_client FROM interdit_bancaire
        WHERE interdit_bancaire.id_client=id_client_f) IS NOT NULL 
        AND carte <> 'carte de retrait' 
        AND carte <> 'carte electron'
    THEN RAISE EXCEPTION 'Vous êtes interdit bancaire, les ''%'' ne sont pas autorisées',carte;
        RETURN;
    END IF;

-- Ajout de la carte dans le compte
    SELECT * INTO line 
    FROM types_carte
    WHERE nom=carte;
    SELECT cartes_generer_numero() INTO numCarte;
    INSERT INTO cartes (numero,type_carte_id,compte_id,date_exp,num_securite,plafond_periodique,
                        plafond_paiement,plafond_periodique_etranger,plafond_paiement_etranger)
            VALUES(numCarte,line.id,id_compte,CURRENT_DATE+interval'3 year',
                    trunc(random() * (899) + 100),line.plafond_periodique,line.plafond_paiement,
                    line.plafond_periodique_etranger,line.plafond_paiement_etranger);

END;
$$ LANGUAGE PLPGSQL;


-------------------------
-- (2) Ajout d'un chéquier
-------------------------

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




---------------------------
-- (3) Consultation du solde
---------------------------
CREATE OR REPLACE FUNCTION compte_consulter_solde(p_id_compte comptes.id%TYPE)
RETURNS comptes.solde%TYPE AS $$
DECLARE
	v_solde comptes.solde%TYPE;

BEGIN
	SELECT solde 
	INTO v_solde
	FROM comptes
	WHERE id = p_id_compte;

	RETURN v_solde;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Le compte % n''existe pas', p_id_compte;

END;
$$ LANGUAGE PLPGSQL;


-------------
-- (4) Retrait
-------------
CREATE OR REPLACE FUNCTION compte_retrait(p_id_carte cartes.id%TYPE, 
	p_montant comptes.solde%TYPE, p_banque_etranger BOOLEAN)

RETURNS VOID AS $$
DECLARE 
	v_id_compte comptes.id%TYPE;
	v_id_carte cartes.id%TYPE;
	v_depenses REAL;
	v_plafond cartes.plafond_periodique%TYPE;
	v_type_operation types_operation.id%TYPE;
	v_type_carte types_carte.nom%TYPE;
	v_id_client interdit_bancaire.id_client%TYPE;

BEGIN

	-- Recuperation du numero de cartes et du compte lié
	-- Une esceptino sera levée si le numero de carte ne correspond a aucun compte
	SELECT cartes.id, comptes.id
	INTO v_id_carte, v_id_compte
	FROM comptes, cartes
	WHERE cartes.compte_id = comptes.id
	AND comptes.actif = 1
	AND cartes.id = p_id_carte;

	-- Recuperation de l'id client si il est interdit bancaire
	SELECT COALESCE(interdit_bancaire.id_client, NULL)
	INTO v_id_client
	FROM interdit_bancaire, comptes, cartes, titulaires
	WHERE interdit_bancaire.id_client :: INTEGER = titulaires.client_id
	AND titulaires.compte_id = comptes.id
	AND cartes.compte_id = comptes.id
	AND cartes.id = p_id_carte;

	-- si le client est interdit bancaire alors v_id_client ne sera pas NULL
	IF v_id_client IS NOT NULL THEN
		-- Recuperation du nom du type de la carte
		-- les electron et carte de retrati peuvent etre utilisé pendant un interdit bancaire
		SELECT nom
		INTO v_type_carte
		FROM types_carte, cartes
		WHERE types_carte.id = cartes.type_carte_id
		AND cartes.id = p_id_carte;

		IF v_type_carte <> 'carte de retrait' AND v_type_carte <> 'carte electron' THEN
			RAISE EXCEPTION 'Vous ne pouvez retirer avec cette carte car vous etes interdit bancaire';
		END IF;
	END IF;

	IF p_montant < 0 THEN
		RAISE EXCEPTION 'Le montant de retrait ne peux etre negatif';
	END IF;

	-- Recuperation de la somme des oepration effectué pendant les 7 derniers jours
	SELECT SUM(montant)
	INTO v_depenses
	FROM operations
	WHERE type_operation_id = (
		SELECT id
		FROM types_operation
		WHERE type LIKE 'retrait'
	)
	AND source_id = v_id_compte
	AND extra = p_id_carte
	AND date >= (
		SELECT current_date - INTERVAL '7 days'
	);

	IF p_banque_etranger IS TRUE THEN
		SELECT plafond_periodique_etranger
		INTO STRICT v_plafond
		FROM cartes
		WHERE id = p_id_carte;

	ELSE
		SELECT plafond_periodique
		INTO STRICT v_plafond
		FROM cartes
		WHERE id = p_id_carte;
	END IF;

	IF v_depenses + p_montant > v_plafond THEN
		RAISE EXCEPTION 'Le plafond périodique ne peux etre depassé';
	END IF;

	-- Mise a jour du solde 
	UPDATE comptes SET
		solde = solde - p_montant
	WHERE id = v_id_compte;

	SELECT id
	INTO v_type_operation
	FROM types_operation
	WHERE type LIKE 'retrait';

	-- Creation de l'operation 
	INSERT INTO operations (type_operation_id, source_id, destination_id, montant, extra)
	VALUES (v_type_operation, v_id_compte, NULL, p_montant, p_id_carte);

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RAISE EXCEPTION 'La carte % n''existe pas ou n''est associé a aucun compte', p_id_carte;

END;
$$ LANGUAGE PLPGSQL;



------------------------
-- (5) Trigger test_solde
------------------------
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

---------------------------
-- (6) Interdiction bancaire
---------------------------

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



-------------------------
-- (7) Fermeture du compte
-------------------------
-- La fermeture de comptes possède plusieurs arguments : 2 client_id, un id_compte. 
-- Le id_client2 peut être ou non NULL. On rappelle que dans le cas de comptes co-gérés
-- la signature (ie : id_client) des deux responsables doivent être présent.
-- Cela implique que le id_client2 ne pourra pas être NULL pour fermer un compte co-géré.
CREATE OR REPLACE FUNCTION fermetureCompte(id_client INTEGER,id_client2 INTEGER, id_compte INTEGER) RETURNS VOID AS $$
DECLARE 
    responsable INTEGER;
    responsable2 INTEGER;
    nombre INTEGER;
BEGIN
-- Vérification des droits des clients sur le compte
    responsable=0;
    responsable2=0;
    SELECT est_responsable INTO responsable
    FROM titulaires
    WHERE client_id=id_client
        AND compte_id=id_compte;

    SELECT est_responsable INTO responsable2 
    FROM titulaires
    WHERE client_id=id_client2
        AND compte_id=id_compte;

-- On vérifie si le compte est un compte co-géré ou non
    SELECT count(*) INTO nombre
    FROM titulaires
    WHERE compte_id=id_compte
    AND est_responsable=1;

    IF nombre >= 2 -- Compte co-géré
       AND (id_client2 IS NULL OR id_client IS NULL)
    THEN RAISE EXCEPTION 'Les deux responsables du compte co-géré doivent être présents pour la fermeture';
    ELSIF nombre >=2 AND (responsable=0 OR responsable2=0) OR (responsable IS NULL OR responsable2 IS NULL)
    THEN RAISE EXCEPTION 'Un des deux client ne possède pas les droits sur ce compte.';
    END IF;

-- On vérifie toujours le premier signataire
    IF (responsable=0) OR (responsable IS NULL)
    THEN 
        RAISE EXCEPTION 'Vous ne possédez pas les droits sur ce compte.';
    END IF;
-- On modifie le statut du compte, on supprime son chequier et on vide tous l'argent qui y était présent.
    UPDATE comptes SET solde=0,actif=0,chequier=0 
    WHERE comptes.id=id_compte;
-- d'autres info à faire avec ça (terminer les virements, supprimer les cartes, etc.
END;
$$ LANGUAGE PLPGSQL;

-----------------------------
-- (8) Calcul du débit différé
-----------------------------

-- Cette fonction a pour but de calculer le débit différé grâce aux paiments par 
-- cartes à débit différé. Cette fonction est faite pour être exécutée à chaque 
-- début de mois, afin de calculer la somme dépensée sur le mois passé. 
-- Elle ne doit pas être lancée plus d'une fois par mois, sinon certains paiements
-- seront comptabilisés plusieurs fois.
CREATE OR REPLACE FUNCTION debitDiff() RETURNS VOID AS $$
DECLARE 
    f_client_interdit INTEGER;
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
    FOR f_client_interdit IN SELECT titulaires.client_id 
                            FROM titulaires,comptes as C1
                            WHERE titulaires.est_responsable=1
                            AND (SELECT solde 
                                WHERE C1.id=titulaires.compte_id) < 
                                (SELECT 0-decouvert_auto_banque
                                WHERE C1.id=titulaires.compte_id) 
                            GROUP BY client_id
    LOOP
        PERFORM interditBancaire(f_client_interdit,'Dépassement du découvert autorisé');
    END LOOP;
END;
$$ LANGUAGE PLPGSQL;


-------------
-- (9) Interet
-------------

-- Cette fonction doit être effectuée en début de mois, afin de pouvoir
-- calculer les intérêts du compte
CREATE OR REPLACE FUNCTION interet() RETURNS VOID AS $$
DECLARE
BEGIN
    UPDATE comptes 
    SET solde=solde+solde*(SELECT taux_interet
                            FROM types_compte
                            WHERE comptes.type_compte_id=id);

END;
$$ LANGUAGE PLPGSQL;

--------------------------
-- (10) Ouverture du compte
--------------------------

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

---------------
-- (11) Paiement
---------------

-- Cette fonction va permettre à un client de pouvoir payer quelqu'un
-- Dans le cas d'un paiement par chèque, numCarte vaudra 'cheque'
CREATE OR REPLACE FUNCTION paiement(client INTEGER, compte_source INTEGER, compte_dest INTEGER, numCarte VARCHAR(16), montantPaiement INTEGER) 
RETURNS VOID AS $$
DECLARE
    testExists INTEGER;
    typePaiement_id INTEGER;
    compteNumCarte VARCHAR(16);
    responsable INTEGER;
    mandataire INTEGER;
    typeOperation_id INTEGER;
    typePaiement VARCHAR(256);
    montantPerio INTEGER;
    f_id_carte INTEGER;

BEGIN
    IF numCarte='cheque'
    THEN typePaiement=numCarte;
    ELSE
        SELECT id INTO f_id_carte
        FROM cartes
        WHERE numero=numCarte
        AND date_exp>CURRENT_DATE;

-- Vérification si le client possède cette carte sur ce compte
        IF f_id_carte IS NULL THEN
            RAISE EXCEPTION 'Vous ne possédez pas cette carte';
        END IF;
        
        SELECT nom INTO typePaiement
        FROM types_carte
        WHERE id = (SELECT type_carte_id
                    FROM cartes
                    WHERE id=f_id_carte);
    END IF;


-- Vérification que le compte source existe bien
    testExists=1;
    SELECT id INTO testExists
    FROM comptes
    WHERE id=compte_source;
    IF testExists IS NULL 
    THEN RAISE EXCEPTION 'Ce compte source n''existe pas';
    END IF;

-- Vérification des droits du client sur le compte
    responsable=0;
    mandataire=0;
    SELECT est_responsable, est_mandataire INTO responsable, mandataire
    FROM titulaires
    WHERE compte_id=compte_source
        AND client_id=client;
    IF (responsable=0 AND mandataire=0) OR (responsable IS NULL AND mandataire IS NULL)
    THEN RAISE EXCEPTION 'Vous n''avez pas les droits de prélever sur ce compte';
    END IF;

-- Vérification de l'existance du compte destinataire
    testExists=1;
    SELECT id INTO testExists
    FROM comptes
    WHERE id=compte_dest;
    IF testExists IS NULL 
    THEN RAISE EXCEPTION 'Ce compte destinataire n''existe pas';
        RETURN;
    END IF;

-- Dans le cas où c'est un paiement par chèque
    IF typePaiement='cheque'
    THEN 
        IF (SELECT chequier
            FROM comptes
            WHERE id=compte_source) = 0
        THEN RAISE EXCEPTION 'Vous n''avez pas de chequier sur ce compte';
            RETURN;
        ELSE 
            SELECT id INTO typeOperation_id
            FROM types_operation
            WHERE type='cheque';
            INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id,extra)
                    VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, NULL);
            UPDATE comptes SET solde = solde - montantPaiement WHERE id = compte_source;
            UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
            RETURN;
        END IF;
    END IF;     

-- Vérification si le type de carte est connu
    SELECT id INTO typePaiement_id
    FROM types_carte
    WHERE nom=typePaiement;
    IF typePaiement_id IS NULL
    THEN RAISE EXCEPTION 'Cette carte n''existe pas';
        RETURN;
    END IF;


-- Dans le cas d'un paiement par carte à début différé
    IF typePaiement='carte débit différé'
    THEN
        SELECT id INTO typeOperation_id
        FROM types_operation
        WHERE type='paiement différé';
        INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id,extra)
                VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, f_id_carte);
        UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
        RETURN;

-- Dans le cas d'un paiement par carte de paiement
    ELSIF typePaiement='carte de paiement'
    THEN 
        SELECT SUM(montant) INTO montantPerio
        FROM operations
        WHERE type_operation_id = (
            SELECT id
            FROM types_operation
            WHERE types_operation.type='paiement'
        )
        AND operations.extra = f_id_carte
        AND date > CURRENT_DATE-interval '1 week';
    -- Vérification du non-dépassement du plafond de paiement
        IF montantPaiement > (SELECT plafond_paiement
                                            FROM cartes
                                            WHERE id = f_id_carte)
        THEN RAISE EXCEPTION 'Paiement refusé (votre paiement est trop élevé)';
            RETURN;
        END IF;
    -- Vérification du non-dépassement du montant périodique
        IF montantPerio + montantPaiement > (SELECT plafond_periodique
                                            FROM cartes
                                            WHERE id = f_id_carte)
        THEN RAISE EXCEPTION 'Paiement refusé (plafond periodique dépassé)';
            RETURN;
        END IF;

        SELECT id INTO typeOperation_id
        FROM types_operation
        WHERE type='paiement';
        INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id,extra)
                VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, f_id_carte);
        UPDATE comptes SET solde = solde - montantPaiement WHERE id = compte_source;
        UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
-- Dans le cas d'un paiement par carte électron
    ELSIF typePaiement='carte electron'
    THEN 
        SELECT SUM(montant) INTO montantPerio
        FROM operations
        WHERE type_operation_id = (SELECT id
                                    FROM types_operation
                                    WHERE type= 'paiement')
            AND extra = f_id_carte
            AND date > CURRENT_DATE-interval '1 week';

    -- Vérification du non-dépassement du plafond de paiement
        IF montantPaiement > (SELECT plafond_paiement
                                            FROM cartes
                                            WHERE id = f_id_carte)
        THEN RAISE EXCEPTION 'Paiement refusé (votre paiement est trop élevé)';
            RETURN;
        END IF;

    -- Vérification du non-dépassement du montant périodique
        IF montantPerio + montantPaiement > (SELECT plafond_periodique
                                            FROM cartes
                                            WHERE id = f_id_carte)
        THEN RAISE EXCEPTION 'Paiement refusé (plafond periodique dépassé)';
            RETURN;
        END IF;

    -- On vérifie que la solde ne passe pas dans un nombre négatif
        IF montantPaiement > (SELECT solde
                                FROM comptes
                                WHERE id=compte_source)
        THEN RAISE EXCEPTION 'Paiement refusé';
            RETURN;
        ELSE -- Paiement
            SELECT id INTO typeOperation_id
            FROM types_operation
            WHERE type='paiement';
            INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id, extra)
                                VALUES (typeOperation_id, CURRENT_DATE, montantPaiement, compte_source, compte_dest, f_id_carte);
            UPDATE comptes SET solde = solde - montantPaiement WHERE id = compte_source;
            UPDATE comptes SET solde = solde + montantPaiement WHERE id = compte_dest;
        END IF;
-- Dans le cas d'un paiement par carte de retrait
    ELSIF typePaiement='carte de retrait'
    THEN RAISE EXCEPTION 'Cette carte ne peut pas effectuer de paiement';
        RETURN;
    END IF;

END;
$$ LANGUAGE PLPGSQL;





--------------------------
-- (12) Routine quotidienne
--------------------------
CREATE OR REPLACE FUNCTION routine_quotidienne()
RETURNS VOID AS $$
DECLARE

	-- Recuperation de tous les virements periodique
	c_virements CURSOR FOR
		SELECT id, source_id, destination_id, montant, jour, periode
		FROM virements_periodique
		WHERE date_suivante = current_date
		AND (
			date_fin IS NULL
			OR date_fin >= current_date
		);

	r_virement RECORD;

	v_solde comptes.solde%TYPE;
	v_decouvert_auto_banque comptes.decouvert_auto_banque%TYPE;
	v_forfait types_compte.forfait_virement_periodique%TYPE;
	v_type_operation_forfait types_operation.id%TYPE;
	v_type_operation_virement types_operation.id%TYPE;

BEGIN

	OPEN c_virements;

	LOOP
		FETCH c_virements INTO r_virement;
		EXIT WHEN NOT FOUND;

		-- Recuperation du montant forfaitaire d'execution du virement
		SELECT forfait_virement_periodique
		INTO v_forfait
		FROM types_compte, comptes
		WHERE types_compte.id = comptes.type_compte_id
		AND comptes.id = r_virement.source_id;
		
		-- Recuperation du solde apres l'execution du virement et applciation des frais
		SELECT solde - (v_forfait + r_virement.montant)
		INTO v_solde
		FROM comptes
		WHERE comptes.id = r_virement.source_id;

		-- Recuperation du decouvert autorisé par la banque  pour tester la 
		-- possibilité d'effectuer le virement
		SELECT decouvert_auto_banque
		INTO v_decouvert_auto_banque
		FROM comptes
		WHERE id = r_virement.source_id;

		-- Recuperation de l'id correspondant à une operation de type 'forfait virement'
		SELECT id
		INTO v_type_operation_forfait
		FROM types_operation
		WHERE type LIKE 'forfait virement';

		-- Recuperation de l'id correspondant à une operation de type 'virement'
		SELECT id
		INTO v_type_operation_virement
		FROM types_operation
		WHERE type LIKE 'virement';

		-- Si on peux faire le virement
		IF (v_solde >= (-v_decouvert_auto_banque)) THEN

			RAISE NOTICE 'viremenet de % vers % pour %e', r_virement.source_id, r_virement.destination_id, r_virement.montant;

			-- Mise a jour du solde source
			UPDATE comptes SET
				solde = v_solde
			WHERE id = r_virement.source_id;

			-- mise a joru du solde destination
			UPDATE comptes SET
				solde = solde + r_virement.montant
			WHERE id = r_virement.destination_id;

			-- enregistrement des l'operation
			INSERT INTO operations (type_operation_id, source_id, destination_id, montant)
			VALUES (v_type_operation_virement, r_virement.source_id, r_virement.destination_id, r_virement.montant);

			INSERT INTO operations (type_operation_id, source_id, destination_id, montant)
			VALUES (v_type_operation_forfait, r_virement.source_id, NULL, v_forfait);

		END IF;

		UPDATE virements_periodique SET
			date_suivante = date_suivante + (r_virement.periode || ' months')::INTERVAL
		WHERE id = r_virement.id;

	END LOOP;

	CLOSE c_virements;


END;
$$ LANGUAGE PLPGSQL;



--------------------------
-- (13) Virement Périodique
--------------------------

CREATE OR REPLACE FUNCTION virement_periodique_creer(p_id_source comptes.id%TYPE, 
	p_id_destination comptes.id%TYPE, p_montant comptes.solde%TYPE, 
	p_jour virements_periodique.jour%TYPE, p_periode virements_periodique.periode%TYPE, 
	p_date_fin virements_periodique.date_fin%TYPE)

RETURNS VOID AS $$

DECLARE
	v_compte_courant comptes.id%TYPE;
	v_compte_id comptes.id%TYPE;
	v_type_operation types_operation.id%TYPE;
	v_montant operations.montant%TYPE;

	v_date_suivante virements_periodique.date_suivante%TYPE;
	v_interval_jours INTEGER;
	v_jour INTEGER;
	v_mois INTEGER;

BEGIN 
	
	v_compte_courant = p_id_source;
	
	SELECT id
	INTO v_compte_id
	FROM comptes
	WHERE id = v_compte_courant;
	
	v_compte_courant = p_id_destination;
	
	SELECT id
	INTO v_compte_id
	FROM comptes
	WHERE id = v_compte_courant;

	IF p_montant < 0 THEN
		RAISE EXCEPTION 'Le montant de retrait ne peux etre negatif';
	END IF;

	IF p_periode < 1 OR p_periode > 12 THEN
		RAISE EXCEPTION 'La periode de retrait doit etre comprise entre 1 et 12';
	END IF;

	IF p_jour < 1 OR p_jour > 31 THEN
		RAISE EXCEPTION 'Le jour doit etre compris entre 1 et 31';
	END IF;

	SELECT current_date
	INTO v_date_suivante;

	SELECT date_part('day', current_timestamp)
	INTO v_jour;

	SELECT date_part('month', current_timestamp)
	INTO v_mois;

	SELECT forfait_virement_ajout
	INTO v_montant
	FROM comptes, types_compte
	WHERE comptes.type_compte_id = types_compte.id
	AND comptes.id = p_id_source;

	UPDATE comptes SET
		solde = solde - v_montant
	WHERE id = p_id_source;

	-- Si le jour est depassé
	IF v_jour > p_jour THEN
		-- Ajout d'un mois
		SELECT v_date_suivante + INTERVAL '1 month'
		INTO v_date_suivante;
	END IF;

	-- on retire l'interval de jour
	v_interval_jours = v_jour - p_jour;

	SELECT v_date_suivante - (v_interval_jours || ' days')::INTERVAL
	INTO v_date_suivante;

	SELECT id
	INTO v_type_operation
	FROM types_operation
	WHERE type LIKE 'forfait virement ajout';

	-- Creation de l'operation 
	INSERT INTO operations (type_operation_id, source_id, destination_id, montant)
	VALUES (v_type_operation, p_id_source, NULL, v_montant);

	INSERT INTO virements_periodique (periode, jour, date_suivante, date_fin, montant, source_id, destination_id)
	VALUES (p_periode, p_jour, v_date_suivante, p_date_fin, p_montant, p_id_source, p_id_destination);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Le compte % n''existe pas', v_compte_courant;

END;
$$ LANGUAGE PLPGSQL;

------------------------
-- (14) Virement ponctuel
------------------------

-- Le but de cette fonction est d'effectuer un virement ponctuel d'un compte vers un autre
-- Le compte de destination est spécifié par son iban_et son bic. 
CREATE OR REPLACE FUNCTION virementPonctuel(dest_iban INTEGER,dest_bic INTEGER,id_compte INTEGER, id_client INTEGER, montant_vir INTEGER) RETURNS VOID AS $$
DECLARE
    dest_id_compte INTEGER;
    responsable INTEGER;
    responsable2 INTEGER;
    mandataire INTEGER;
    type_id_operation INTEGER;
    cur_date DATE;
BEGIN
    cur_date=CURRENT_DATE;
    responsable=0;
    mandataire=0;
    SELECT id INTO dest_id_compte
    FROM comptes
    WHERE iban=dest_iban
        AND bic=dest_bic;
    -- Test si le compte de destination existe ou non
    IF dest_id_compte IS NULL
    THEN RAISE EXCEPTION 'Ce compte n''existe pas';
    END IF;

    -- Vérifie les droits de la source du virement
    SELECT est_responsable, est_mandataire INTO responsable, mandataire
    FROM titulaires
    WHERE compte_id=id_compte
        AND client_id=id_client;
    IF (responsable=0 AND mandataire=0) OR (responsable IS NULL AND mandataire IS NULL)
    THEN RAISE EXCEPTION 'Vous n''avez pas les droits de prélever sur ce compte';
    END IF;

    -- On modifie la sole des comptes.
    -- Si le virement est impossible, le trigger en charge de vérifier
    -- annulera la transaction
    UPDATE comptes SET solde=solde-montant_vir WHERE id=id_compte;
    UPDATE comptes SET solde=solde+montant_vir WHERE id=dest_id_compte;

    -- Sélection du type de l'opération
    SELECT id INTO type_id_operation
    FROM types_operation
    WHERE type='virement';

    INSERT INTO operations (type_operation_id,date,montant,source_id,destination_id)
        VALUES(type_id_operation,cur_date,montant_vir,id_compte,dest_id_compte);

    -- On regarde si la personne fait un virement sur un de ses comptes
    -- Cela permettra de déterminer le forfait de virement
    responsable2=0;
    SELECT est_responsable INTO responsable2
    FROM titulaires
    WHERE dest_id_compte=compte_id;

    IF responsable2=0 OR responsable=0
    THEN 
        SELECT id INTO type_id_operation
        FROM types_operations
        WHERE type='forfait virement';
        INSERT INTO operation(type_operation_id,date,montant,source_id,destination_id)
            VALUES(type_id_operation,cur_date,1,id_compte,NULL);
    END IF;

END;
$$ LANGUAGE PLPGSQL;

