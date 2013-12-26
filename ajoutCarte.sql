CREATE OR REPLACE FUNCTION cartes_generer_numero()
RETURNS cartes.id%TYPE AS $$
DECLARE
	v_numero INTEGER;
	v_id cartes.id%TYPE;

BEGIN

	SELECT id
	INTO v_numero
	FROM (
		SELECT COALESCE(MIN(TO_NUMBER(id, '9999999999999999')), 0) AS id
		FROM cartes
		WHERE date_exp < current_date
		UNION
		SELECT COALESCE(MAX(TO_NUMBER(id, '9999999999999999')) + 1, 0) AS id
		FROM cartes
		WHERE date_exp >= current_date
	) AS s
	GROUP BY id
    ORDER BY id DESC
	LIMIT 1;

	SELECT LPAD((v_numero || ''), 16, '0')
	INTO v_id;

	RETURN v_id;

END;
$$ LANGUAGE PLPGSQL;








CREATE OR REPLACE FUNCTION ajoutCarte(id_client_f INTEGER, id_compte INTEGER, carte VARCHAR(256)) 
RETURNS VOID AS $$
DECLARE
    responsable INTEGER;
    mandataire INTEGER;
    numCarte VARCHAR(16);
    line types_carte%ROWTYPE;
BEGIN
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

    IF (SELECT id FROM types_carte
        WHERE carte=nom) IS NULL
    THEN
        RAISE EXCEPTION 'Le type de carte donné (%) n''existe pas',carte;
    END IF;
    
    IF (SELECT id_client FROM interdit_bancaire
        WHERE interdit_bancaire.id_client=id_client_f) IS NOT NULL 
        AND carte <> 'carte de retrait' 
        AND carte <> 'carte electron'
    THEN RAISE EXCEPTION 'Vous êtes interdit bancaire, les ''%'' ne sont pas autorisées',carte;
        RETURN;
    END IF;

    SELECT * INTO line 
    FROM types_carte
    WHERE nom=carte;
    SELECT cartes_generer_numero() INTO numCarte;
    INSERT INTO cartes (id,type_carte_id,compte_id,date_exp,num_securite,plafond_periodique,plafond_paiement,plafond_periodique_etranger,plafond_paiement_etranger)
        VALUES(numCarte,line.id,id_compte,CURRENT_DATE+interval'3 year',trunc(random() * (899) + 100),line.plafond_periodique,line.plafond_paiement,line.plafond_periodique_etranger,line.plafond_paiement_etranger);

END;
$$ LANGUAGE PLPGSQL;
