--DROP TABLE clients CASCADE;
DROP TABLE types_compte CASCADE;
DROP TABLE comptes CASCADE;
DROP TABLE types_carte CASCADE;
DROP TABLE cartes CASCADE;
DROP TABLE titulaires CASCADE;
DROP TABLE types_operation CASCADE;
DROP TABLE operations CASCADE;
DROP TABLE virements_periodique CASCADE;
DROP TABLE interdit_bancaire CASCADE;


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
  date DATE NOT NULL,
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
  date_debut DATE NOT NULL,
  date_suivante DATE NOT NULL,
  date_fin DATE NULL,
  montant REAL NOT NULL,
  source INTEGER NOT NULL,
  destination INTEGER NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT chk_periode CHECK (periode >= 1),
  CONSTRAINT chk_jour CHECK (jour >= 1),
  CONSTRAINT chk_montant CHECK (montant >= 1),
  CONSTRAINT fk_virement_periodique_compte1
    FOREIGN KEY (source)
    REFERENCES comptes (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_virement_periodique_compte2
    FOREIGN KEY (destination)
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



INSERT INTO types_compte (type) VALUES('compte courant');
INSERT INTO types_compte (type) VALUES('livret jeune');
INSERT INTO types_operation (type) VALUES ('virement');
INSERT INTO types_operation (type) VALUES ('paiement différé');
INSERT INTO types_operation (type) VALUES ('forfait virement');
INSERT INTO types_operation (type) VALUES ('forfait virement set');
INSERT INTO types_operation (type) VALUES ('paiement carte');
INSERT INTO types_operation (type) VALUES ('retrait');
INSERT INTO types_operation (type) VALUES ('cheque');
INSERT INTO types_operation (type) VALUES ('interet');
INSERT INTO types_operation (type) VALUES ('agios');
INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
        VALUES ('carte de retrait',15,300,50,200,40);
INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
        VALUES ('carte débit différé',70,0,0,0,0);
INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
        VALUES ('carte electron',30,1000,500,800,300);
INSERT INTO types_carte (nom, cotisations, plafond_periodique,plafond_paiement,plafond_periodique_etranger, plafond_paiement_etranger)
        VALUES ('carte de paiement',30,6000,700,4000,500);
