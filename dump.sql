DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS types_compte CASCADE;
DROP TABLE IF EXISTS comptes CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS types_carte CASCADE;
DROP TABLE IF EXISTS cartes CASCADE;
DROP TABLE IF EXISTS titulaires CASCADE;
DROP TABLE IF EXISTS types_operation CASCADE;
DROP TABLE IF EXISTS operations CASCADE;
DROP TABLE IF EXISTS virements_periodique CASCADE;
DROP TABLE IF EXISTS interdit_bancaire;
DROP TYPE IF EXISTS genre CASCADE;

CREATE TYPE genre AS ENUM('F', 'M');

CREATE TABLE clients (
  id SERIAL NOT NULL,
  nom VARCHAR(45) NOT NULL,
  prenom VARCHAR(45) NOT NULL,
  genre genre NOT NULL,
  adresse VARCHAR(45) NOT NULL,
  mail VARCHAR(150) NULL,
  PRIMARY KEY (id));


-- -----------------------------------------------------
-- Table types_compte
-- -----------------------------------------------------
CREATE TABLE types_compte (
  id SERIAL NOT NULL,
  type VARCHAR(150) NOT NULL,
  taux_interet FLOAT NOT NULL DEFAULT 0,
  forfait_virement_ajout FLOAT NOT NULL DEFAULT 0,
  forfait_virement FLOAT NOT NULL DEFAULT 0,
  forfait_virement_periodique FLOAT NOT NULL DEFAULT 0,
  CONSTRAINT chk_taux_interet CHECK (taux_interet >= 0),
  PRIMARY KEY (id));


-- -----------------------------------------------------
-- Table comptes
-- -----------------------------------------------------
CREATE TABLE comptes (
  id SERIAL NOT NULL,
  type_compte_id INTEGER NOT NULL,
  actif SMALLINT NOT NULL DEFAULT 1,
  solde REAL NOT NULL DEFAULT 0,
  decouvert_auto REAL NOT NULL DEFAULT 0,
  decouvert_auto_banque REAL NOT NULL DEFAULT 0,
  chequier SMALLINT NOT NULL DEFAULT 0,
  iban INTEGER NOT NULL,
  bic INTEGER NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT chk_decouvert_auto CHECK (decouvert_auto >= 0),
  CONSTRAINT chk_decouvert_auto_banque CHECK (decouvert_auto_banque >= decouvert_auto),
  CONSTRAINT fk_compte_type_compte
    FOREIGN KEY (type_compte_id)
    REFERENCES types_compte (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table types_carte
-- -----------------------------------------------------
CREATE TABLE types_carte (
  id SERIAL NOT NULL,
  nom VARCHAR(256) NOT NULL,
  cotisations REAL NOT NULL DEFAULT 0,
  plafond_periodique REAL NOT NULL DEFAULT 0,
  plafond_paiement REAL NOT NULL DEFAULT 0,
  plafond_periodique_etranger REAL NOT NULL DEFAULT 0,
  plafond_paiement_etranger REAL NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  CONSTRAINT unique_nom UNIQUE(nom),
  CONSTRAINT chk_plafond_pe CHECK (plafond_periodique >= 0),
  CONSTRAINT chk_plafond_pa CHECK (plafond_paiement >= 0),
  CONSTRAINT chk_plafond_pee CHECK (plafond_periodique_etranger >= 0),
  CONSTRAINT chk_plafond_pae CHECK (plafond_paiement_etranger >= 0));


-- -----------------------------------------------------
-- Table cartes
-- -----------------------------------------------------
CREATE TABLE cartes (
  id SERIAL NOT NULL,
  type_carte_id INTEGER NOT NULL,
  numero VARCHAR(16) NOT NULL,
  compte_id INTEGER NOT NULL,
  date_exp DATE NOT NULL,
  num_securite INTEGER NOT NULL,
  plafond_periodique REAL NOT NULL DEFAULT 0,
  plafond_paiement REAL NOT NULL DEFAULT 0,
  plafond_periodique_etranger REAL NOT NULL DEFAULT 0,
  plafond_paiement_etranger REAL NOT NULL DEFAULT 0,
  PRIMARY KEY (id, date_exp),
  CONSTRAINT chk_plafond_pe CHECK (plafond_periodique >= 0),
  CONSTRAINT chk_plafond_pa CHECK (plafond_paiement >= 0),
  CONSTRAINT chk_plafond_pee CHECK (plafond_periodique_etranger >= 0),
  CONSTRAINT chk_plafond_pae CHECK (plafond_paiement_etranger >= 0),
  CONSTRAINT num_unique UNIQUE(id),
  CONSTRAINT fk_type_carte_has_compte_type_carte1
    FOREIGN KEY (type_carte_id)
    REFERENCES types_carte (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_type_carte_has_compte_compte1
    FOREIGN KEY (compte_id)
    REFERENCES comptes (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table titulaires
-- -----------------------------------------------------
CREATE TABLE titulaires (
  client_id INTEGER NOT NULL,
  compte_id INTEGER NOT NULL,
  est_responsable SMALLINT NOT NULL DEFAULT 1,
  est_mandataire SMALLINT NOT NULL DEFAULT 0,
  PRIMARY KEY (client_id, compte_id),
  CONSTRAINT fk_client_has_compte_client1
    FOREIGN KEY (client_id)
    REFERENCES clients (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_client_has_compte_compte1
    FOREIGN KEY (compte_id)
    REFERENCES comptes (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table types_operation
-- -----------------------------------------------------
CREATE TABLE types_operation (
  id SERIAL NOT NULL,
  type VARCHAR(45) NOT NULL,
  PRIMARY KEY (id));


-- -----------------------------------------------------
-- Table operations
-- -----------------------------------------------------
CREATE TABLE operations (
  id SERIAL NOT NULL,
  type_operation_id INTEGER NOT NULL,
  date DATE NOT NULL DEFAULT current_date,
  montant REAL NOT NULL,
  source_id INTEGER NULL,
  destination_id INTEGER NULL,
  extra INTEGER NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_operations_type_operation1
    FOREIGN KEY (type_operation_id)
    REFERENCES types_operation (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_operations_compte1
    FOREIGN KEY (source_id)
    REFERENCES comptes (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_operations_compte2
    FOREIGN KEY (destination_id)
    REFERENCES comptes (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);


-- -----------------------------------------------------
-- Table virements_periodique
-- -----------------------------------------------------
CREATE TABLE virements_periodique (
  id SERIAL NOT NULL,
  periode INTEGER NOT NULL DEFAULT 1,
  jour INTEGER NOT NULL DEFAULT 1,
  date_debut DATE NOT NULL DEFAULT current_date,
  date_suivante DATE NOT NULL,
  date_fin DATE NULL,
  montant REAL NOT NULL,
  source_id INTEGER NOT NULL,
  destination_id INTEGER NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT chk_periode CHECK (periode >= 1),
  CONSTRAINT chk_jour CHECK (jour >= 1),
  CONSTRAINT chk_montant CHECK (montant >= 1),
  CONSTRAINT fk_virement_periodique_compte1
    FOREIGN KEY (source_id)
    REFERENCES comptes (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_virement_periodique_compte2
    FOREIGN KEY (destination_id)
    REFERENCES comptes (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);

CREATE TABLE interdit_bancaire(
    banque VARCHAR DEFAULT CURRENT_USER,
    id_client INTEGER PRIMARY KEY,
    motif varchar,
    date_interdit DATE,
    date_regularisation DATE DEFAULT NULL
);

INSERT INTO types_compte (id, type) 
VALUES (1, 'compte courant');

INSERT INTO types_compte (id, type) 
VALUES (2, 'livret jeune');

INSERT INTO types_compte (id, type) 
VALUES (3, 'compte joint');

INSERT INTO types_operation (id, type) 
VALUES (1, 'virement');

INSERT INTO types_operation (id, type) 
VALUES (2, 'forfait virement');

INSERT INTO types_operation (id, type) 
VALUES (3, 'forfait virement ajout');

INSERT INTO types_operation (id, type) 
VALUES (4, 'paiement');

INSERT INTO types_operation (id, type) 
VALUES (5, 'retrait');

INSERT INTO types_operation (id, type) 
VALUES (6, 'cheque');

INSERT INTO types_operation (id, type) 
VALUES (7, 'interet');

INSERT INTO types_operation (id, type) 
VALUES (9, 'agios');

INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
VALUES ('carte de retrait', 15, 300, 50, 200, 40);

INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
VALUES ('carte electron', 20, 300, 50, 200, 40);

INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
VALUES ('carte débit différé', 50, 0, 0, 0, 0);

INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
VALUES ('carte de paiement', 30, 6000, 700, 4000, 500);

INSERT INTO clients (id, nom, prenom, genre, adresse, mail)
VALUES (1, 'Desravines', 'Jean', 'M', '101 rue de Paris', 'jean.desravines@paris7.fr');

INSERT INTO clients (id, nom, prenom, genre, adresse, mail)
VALUES (2, 'Dequeker', 'Chloé', 'F', '12 rue de Paris', 'chloe.dequeker@paris7.fr');

INSERT INTO clients (id, nom, prenom, genre, adresse, mail)
VALUES (3, 'Foo', 'Bar', 'M', '12 avenue de Lyon', 'bar.foo@paris7.fr');

INSERT INTO comptes (id, type_compte_id, actif, solde, decouvert_auto, decouvert_auto_banque, chequier, iban, bic)
VALUES (1, 1, 1, 5040, 300, 350, 1, '1', '1');

INSERT INTO comptes (id, type_compte_id, actif, solde, decouvert_auto, decouvert_auto_banque, chequier, iban, bic)
VALUES (2, 2, 1, 20, 0, 0, 1, '2', '2');

INSERT INTO comptes (id, type_compte_id, actif, solde, decouvert_auto, decouvert_auto_banque, chequier, iban, bic)
VALUES (3, 1, 1, 2000, 300, 350, 0, '3', '3');

INSERT INTO titulaires (client_id, compte_id, est_responsable, est_mandataire)
VALUES (1, 1, 1, 0);

INSERT INTO titulaires (client_id, compte_id, est_responsable, est_mandataire)
VALUES (2, 2, 1, 0);

INSERT INTO titulaires (client_id, compte_id, est_responsable, est_mandataire)
VALUES (3, 1, 0, 1);

INSERT INTO titulaires (client_id, compte_id, est_responsable, est_mandataire)
VALUES (1, 3, 1, 0);

INSERT INTO titulaires (client_id, compte_id, est_responsable, est_mandataire)
VALUES (2, 3, 1, 0);

INSERT INTO cartes (id, type_carte_id, compte_id, numero, date_exp, num_securite, plafond_periodique, plafond_paiement, plafond_periodique_etranger, plafond_paiement_etranger)
VALUES (1, 2, 1, '0000000000000000', '2015-06-14', '123', 2000, 1000, 1000, 500);

INSERT INTO cartes (id, type_carte_id, compte_id, numero, date_exp, num_securite, plafond_periodique, plafond_paiement, plafond_periodique_etranger, plafond_paiement_etranger)
VALUES (2, 1, 1, '0000000000000001', '2015-07-15', '123', 2000, 1000, 1000, 500);

INSERT INTO cartes (id, type_carte_id, compte_id, numero, date_exp, num_securite, plafond_periodique, plafond_paiement, plafond_periodique_etranger, plafond_paiement_etranger)
VALUES (3, 1, 2, '0000000000000002', '2014-01-14', '234', 2500, 1500, 900, 300);

INSERT INTO cartes (id, type_carte_id, compte_id, numero, date_exp, num_securite, plafond_periodique, plafond_paiement, plafond_periodique_etranger, plafond_paiement_etranger)
VALUES (4, 2, 2, '0000000000000003', '2014-07-15', '567', 2500, 1500, 900, 300);

INSERT INTO cartes (id, type_carte_id, compte_id, numero, date_exp, num_securite, plafond_periodique, plafond_paiement, plafond_periodique_etranger, plafond_paiement_etranger)
VALUES (5, 2, 3, '0000000000000004', '2016-07-15', '367', 6000, 4500, 100, 200);

