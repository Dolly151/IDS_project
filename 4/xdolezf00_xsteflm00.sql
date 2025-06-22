-- pozn. k ER diagramu, vyřadili jsme některé atributy v jednotlivých entitních množinách, protože byly zbytečné
-- jmenovitě
--      Důl:      zásoby_dolu
--      Osoba:    nejbližší_semaforová_věž
--      Firma:    nejbližší_semaforová_věž, typ
--      Přeprava: dodané_množství

-- jinak ER diagram zůstal strukturálně stejný

-- ____________________________________________________________________________________________________
-- GENERALIZACE:
-- Jelikož naše generalizace nepřidává žádné další atributy a jediné v čem se odlišuje od OSOBY je rasa
-- a rasa je již atributem OSOBY, tak generalizaci řešíme kontrolou atributu rasy.

-- Doly může spravovat pouze trpaslík nikoliv člověk, takže se vždy podíváme zda přiřazená OSOBA
-- v tabulce dolu má hodnotu atributu rasa nastavenou jako trpaslík, pokud ne tak to je chyba.

-- Analogicky to funguje i pro prodej kontraktu, které také může prodávat pouze trpaslík a také
-- opačně pro osobu která může zastupovat firmu což může být pouze člověk.

-- Implementováno vždy pod jednotlivými tabulkami pomocí triggerů.
-- _____________________________________________________________________________________________________



-- SEKVENCE PRO PRIMÁRNÍ KLÍČE __________________________________________
CREATE SEQUENCE seq_firma_licence
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE SEQUENCE seq_osoba_id
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE SEQUENCE seq_sklad_id
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE SEQUENCE seq_dul_id
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE SEQUENCE seq_kontrakt_cislo
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE SEQUENCE seq_preprava_id
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- TABULKY: ______________________________________________________________
CREATE TABLE SUROVINA (
    TYP_SUROVINY VARCHAR2(100) NOT NULL,
    CENA_KG      NUMBER NOT NULL CHECK (CENA_KG >= 0),
    POPIS        CLOB,
    CONSTRAINT SUROVINA_pk PRIMARY KEY (TYP_SUROVINY)
);




CREATE TABLE FIRMA (
    ČÍSLO_LICENCE  INTEGER       NOT NULL,
    OBCHODNÍ_JMÉNO VARCHAR2(100) NOT NULL,
    ADRESA_SÍDLA   VARCHAR2(200) NOT NULL,
    CONSTRAINT FIRMA_pk PRIMARY KEY (ČÍSLO_LICENCE)
);

-- VYUŽITÍ SEKVENCE (LICENCE)
CREATE OR REPLACE TRIGGER trg_firma_licence
BEFORE INSERT ON FIRMA
FOR EACH ROW
BEGIN
    :NEW.ČÍSLO_LICENCE := seq_firma_licence.NEXTVAL;
END;




CREATE TABLE SKLAD (
    ID_SKLADU    INTEGER       NOT NULL,
    KAPACITA     NUMBER        NOT NULL CHECK (KAPACITA >= 0),
    ZAPLNĚNÍ     NUMBER        NOT NULL CHECK (ZAPLNĚNÍ >= 0),
    TYP_SUROVINY VARCHAR2(100) NOT NULL,
    CONSTRAINT SKLAD_pk PRIMARY KEY (ID_SKLADU),
    CONSTRAINT SKLAD_SUROVINA_fk FOREIGN KEY (TYP_SUROVINY) REFERENCES SUROVINA(TYP_SUROVINY)
);

-- VYUŽITÍ SEKVENCE (SKLAD)
CREATE OR REPLACE TRIGGER trg_sklad_id
BEFORE INSERT ON SKLAD
FOR EACH ROW
BEGIN
    :NEW.ID_SKLADU := seq_sklad_id.NEXTVAL;
END;

-- TRIGGER PRO KONTROLU ZAPLNĚNÍ (NESMÍ BÝT VYŠŠÍ NEŽ KAPACITA)
CREATE OR REPLACE TRIGGER trg_check_zaplnění
BEFORE INSERT OR UPDATE ON SKLAD
FOR EACH ROW
BEGIN
    IF :NEW.ZAPLNĚNÍ > :NEW.KAPACITA THEN
        RAISE_APPLICATION_ERROR(-20001, 'ZAPLNĚNÍ nesmí být větší než KAPACITA.');
    END IF;
END;

COMMENT ON COLUMN SKLAD.ZAPLNĚNÍ IS 'Mnozstvi suroviny v kilech (nesmi byt vetsi nez KAPACITA)';
COMMENT ON COLUMN SKLAD.TYP_SUROVINY IS 'Skladuje se';




CREATE TABLE OSOBA (
    ID_OSOBY       INTEGER       NOT NULL,
    JMÉNO          VARCHAR2(30)  NOT NULL,
    PŘÍJMENÍ       VARCHAR2(30)  NOT NULL,
    DATUM_NAROZENÍ DATE          NOT NULL,
    RASA           VARCHAR2(10)  NOT NULL,
    ADRESA_POBYTU  VARCHAR2(200) NOT NULL,
    ČÍSLO_LICENCE  INTEGER               ,
    CONSTRAINT OSOBA_pk PRIMARY KEY (ID_OSOBY),
    CONSTRAINT OSOBA_FIRMA_fk FOREIGN KEY (ČÍSLO_LICENCE) REFERENCES FIRMA(ČÍSLO_LICENCE),
    CONSTRAINT chk_rasa CHECK (RASA IN ('Člověk', 'Trpaslík')),
    CONSTRAINT chk_trpaslik_no_licence CHECK (NOT (RASA = 'Trpaslík' AND ČÍSLO_LICENCE IS NOT NULL))
);

-- VYUŽITÍ SEKVENCE (OSOBA)
CREATE OR REPLACE TRIGGER trg_osoba_id
BEFORE INSERT ON OSOBA
FOR EACH ROW
BEGIN
    :NEW.ID_OSOBY := seq_osoba_id.NEXTVAL;
END;

COMMENT ON COLUMN OSOBA.ČÍSLO_LICENCE IS 'Zastupuje';




CREATE TABLE DUL (
    ID_DOLU       INTEGER       NOT NULL,
    VELIKOST_DOLU VARCHAR2(10)  NOT NULL,
    ID_OSOBY      INTEGER       NOT NULL,
    TYP_SUROVINY  VARCHAR2(100) NOT NULL,
    ID_SKLADU     INTEGER       NOT NULL,
    CONSTRAINT DUL_pk PRIMARY KEY (ID_DOLU),
    CONSTRAINT DUL_OSOBA_fk FOREIGN KEY (ID_OSOBY) REFERENCES OSOBA(ID_OSOBY),
    CONSTRAINT DUL_SUROVINA_fk FOREIGN KEY (TYP_SUROVINY) REFERENCES SUROVINA(TYP_SUROVINY),
    CONSTRAINT DUL_SKLAD_fk FOREIGN KEY (ID_SKLADU) REFERENCES SKLAD(ID_SKLADU),
    CONSTRAINT chk_velikost_dolu CHECK (VELIKOST_DOLU IN ('MALÝ', 'STŘEDNÍ', 'VELKÝ'))
);

-- VYUŽITÍ SEKVENCE (DUL)
CREATE OR REPLACE TRIGGER trg_dul_id
BEFORE INSERT ON DUL
FOR EACH ROW
BEGIN
    :NEW.ID_DOLU := seq_dul_id.NEXTVAL;
END;

-- TRIGGER PRO KONTROLU, ŽE POUZE TRPASLICI MOHOU SPRAVOVAT DOLY
CREATE OR REPLACE TRIGGER trg_check_dul_trpaslik
BEFORE INSERT OR UPDATE ON DUL
FOR EACH ROW
DECLARE
    v_rasa VARCHAR2(10);
BEGIN
    -- ZÍSKÁME RASU PODLE ID OSOBY
    SELECT RASA INTO v_rasa
    FROM OSOBA
    WHERE ID_OSOBY = :NEW.ID_OSOBY;

    -- POKUD OSOBA NENÍ TRPASLÍK VYHODÍME CHYBU
    IF v_rasa <> 'Trpaslík' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Pouze trpaslíci mohou spravovat doly.');
    END IF;
END;




CREATE TABLE KONTRAKT (
    CISLO_KONTRAKTU INTEGER NOT NULL,
    DELKA_TRVANI    INTEGER,
    DATUM_UZAVRENI  DATE NOT NULL,
    TYP_SUROVINY    VARCHAR2(100) NOT NULL,
    MNOZSTVI        NUMBER NOT NULL,
    CISLO_LICENCE   INTEGER NOT NULL,
    ID_OSOBY        INTEGER NOT NULL,
    CONSTRAINT KONTRAKT_pk PRIMARY KEY (CISLO_KONTRAKTU),
    CONSTRAINT KONTRAKT_SUROVINA_fk FOREIGN KEY (TYP_SUROVINY) REFERENCES SUROVINA(TYP_SUROVINY),
    CONSTRAINT KONTRAKT_FIRMA_fk FOREIGN KEY (CISLO_LICENCE) REFERENCES FIRMA(ČÍSLO_LICENCE),
    CONSTRAINT KONTRAKT_OSOBA_fk FOREIGN KEY (ID_OSOBY) REFERENCES OSOBA(ID_OSOBY)
);

-- VYUŽITÍ SEKVENCE (KONTRAKT)
CREATE OR REPLACE TRIGGER trg_kontrakt_cislo
BEFORE INSERT ON KONTRAKT
FOR EACH ROW
BEGIN
    :NEW.CISLO_KONTRAKTU := seq_kontrakt_cislo.NEXTVAL;
END;

-- TRIGGER PRO KONTROLU, ŽE POUZE TRPASLICI MOHOU PRODÁVAT KONTRAKTY
CREATE OR REPLACE TRIGGER trg_kontrakt_check_trpaslik
BEFORE INSERT ON KONTRAKT
FOR EACH ROW
DECLARE
    v_rasa VARCHAR2(10);
BEGIN
    -- ZÍSKÁME RASU PODLE ID OSOBY
    SELECT RASA INTO v_rasa
    FROM OSOBA
    WHERE ID_OSOBY = :NEW.ID_OSOBY;

    -- POKUD OSOBA NENÍ TRPASLÍK VYHODÍME CHYBU
    IF v_rasa <> 'Trpaslík' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Pouze trpaslík může prodávat kontrakty.');
    END IF;
END;

COMMENT ON COLUMN KONTRAKT.DELKA_TRVANI IS 'Počet dní';
COMMENT ON COLUMN KONTRAKT.TYP_SUROVINY IS 'Pojednává o';
COMMENT ON COLUMN KONTRAKT.CISLO_LICENCE IS 'Nakupuje';




CREATE TABLE PŘEPRAVA (
    ID_PŘEPRAVY   INTEGER       NOT NULL,
    CENA          NUMBER        NOT NULL,
    DATUM_ZADÁNÍ  DATE          NOT NULL,
    STAV          VARCHAR2(20)  NOT NULL,
    TYP_SUROVINY  VARCHAR2(100) NOT NULL,
    MNOŽSTVÍ      NUMBER        NOT NULL,
    ČÍSLO_LICENCE INTEGER       NOT NULL,
    ID_SKLADU_Z   INTEGER       NOT NULL,
    ID_SKLADU_DO  INTEGER       NOT NULL,
    CONSTRAINT PŘEPRAVA_pk PRIMARY KEY (ID_PŘEPRAVY),
    CONSTRAINT PŘEPRAVA_SUROVINA_fk FOREIGN KEY (TYP_SUROVINY) REFERENCES SUROVINA(TYP_SUROVINY),
    CONSTRAINT PŘEPRAVA_FIRMA_fk FOREIGN KEY (ČÍSLO_LICENCE) REFERENCES FIRMA(ČÍSLO_LICENCE),
    CONSTRAINT PŘEPRAVA_SKLAD_Z_fk FOREIGN KEY (ID_SKLADU_Z) REFERENCES SKLAD(ID_SKLADU),
    CONSTRAINT PŘEPRAVA_SKLAD_DO_fk FOREIGN KEY (ID_SKLADU_DO) REFERENCES SKLAD(ID_SKLADU)
);

-- VYUŽITÍ SEKVENCE (PŘEPRAVA)
CREATE OR REPLACE TRIGGER trg_preprava_id
BEFORE INSERT ON PŘEPRAVA
FOR EACH ROW
BEGIN
    :NEW.ID_PŘEPRAVY := seq_preprava_id.NEXTVAL;
END;




CREATE TABLE VLASTNÍ (
    ID_OSOBY INTEGER NOT NULL,
    ID_DOLU  INTEGER NOT NULL,
    PODÍL    NUMBER NOT NULL CHECK (PODÍL >= 0 AND PODÍL <= 100),
    CONSTRAINT VLASTNÍ_pk PRIMARY KEY (ID_OSOBY, ID_DOLU),
    CONSTRAINT VLASTNÍ_OSOBA_fk FOREIGN KEY (ID_OSOBY) REFERENCES OSOBA(ID_OSOBY),
    CONSTRAINT VLASTNÍ_DUL_fk FOREIGN KEY (ID_DOLU) REFERENCES DUL(ID_DOLU)
);

COMMENT ON COLUMN VLASTNÍ.PODÍL IS 'Podíl vlastníka dolu, vyjádřený jako procento (0-100%)';




CREATE TABLE DISPONUJE (
    ID_OSOBY  INTEGER NOT NULL,
    ID_SKLADU INTEGER NOT NULL,
    CONSTRAINT DISPONUJE_pk PRIMARY KEY (ID_OSOBY, ID_SKLADU),
    CONSTRAINT DISPONUJE_OSOBA_fk FOREIGN KEY (ID_OSOBY) REFERENCES OSOBA(ID_OSOBY),
    CONSTRAINT DISPONUJE_SKLAD_fk FOREIGN KEY (ID_SKLADU) REFERENCES SKLAD(ID_SKLADU)
);




CREATE TABLE JE_SOUČÁSTÍ (
    ID_PŘEPRAVY     INTEGER NOT NULL,
    ČÍSLO_KONTRAKTU INTEGER NOT NULL,
    CONSTRAINT JE_SOUČÁSTÍ_pk PRIMARY KEY (ID_PŘEPRAVY, ČÍSLO_KONTRAKTU),
    CONSTRAINT JE_SOUČÁSTÍ_PŘEPRAVA_fk FOREIGN KEY (ID_PŘEPRAVY) REFERENCES PŘEPRAVA(ID_PŘEPRAVY),
    CONSTRAINT JE_SOUČÁSTÍ_KONTRAKT_fk FOREIGN KEY (ČÍSLO_KONTRAKTU) REFERENCES KONTRAKT(CISLO_KONTRAKTU)
);



-- NAPLNĚNÍ UKÁZOKOVÝMI DATY ______________________________________________________________
INSERT INTO SUROVINA (TYP_SUROVINY, CENA_KG, POPIS)
VALUES ('Měď', '50', 'Je to nejslabší a nejsnáze získatelná surovina.');

INSERT INTO SUROVINA (TYP_SUROVINY, CENA_KG, POPIS)
VALUES ('Železo', '100', 'Specialitou je výroba kbelíků, řetězů a dalších věci mimo zbraně.');

INSERT INTO SUROVINA (TYP_SUROVINY, CENA_KG, POPIS)
VALUES ('Platina', '3000', 'Kov nejen pro výrobu nástrojů. Je to také zdobný kov pro výrobu korun a trůnů');

INSERT INTO SUROVINA (TYP_SUROVINY, CENA_KG, POPIS)
VALUES ('Palladium', '6000', 'Nejčastěji objevující se kov v hlubinách Lordranu. Má léčivé schopnosti pro bytost, která je v něm oděna.');

INSERT INTO SUROVINA (TYP_SUROVINY, CENA_KG, POPIS)
VALUES ('Mytril', '9000', 'Vzácnější kov objevující se v hlubinách Lordranu. Nejsilnější nemagický kov.');

INSERT INTO SUROVINA (TYP_SUROVINY, CENA_KG, POPIS)
VALUES ('Adamantit', '34000', 'Nejvzácnější magický kov z hlubin Lordranu. Bytost v něm oděna je neporazitelná.');




-- Firmy
INSERT INTO FIRMA (ČÍSLO_LICENCE, OBCHODNÍ_JMÉNO, ADRESA_SÍDLA)
VALUES (1, 'Slunce s.r.o', 'Anor Londo');

INSERT INTO FIRMA (ČÍSLO_LICENCE, OBCHODNÍ_JMÉNO, ADRESA_SÍDLA)
VALUES (1, 'Plamen s.r.o', 'Anor Londo');




-- Osoby "Človek"
INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'Solér', 'Astora', TO_DATE('1989-05-23', 'YYYY-MM-DD'), 'Člověk', 'Anor Londo', 1);

INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'André', 'Astora', TO_DATE('1968-02-11', 'YYYY-MM-DD'), 'Člověk', 'Anor Londo', 1);

INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'Gwyn', 'Sinder', TO_DATE('1934-01-01', 'YYYY-MM-DD'), 'Člověk', 'Anor Londo', 2);

-- Osoby "Trpaslík"
INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'Petrus', 'Thorlund', TO_DATE('1998-12-25', 'YYYY-MM-DD'), 'Trpaslík', 'Izalith', NULL);

INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'Grigs', 'Vinhajm', TO_DATE('1988-06-01', 'YYYY-MM-DD'), 'Trpaslík', 'New Londo', NULL);

INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'Kirk', 'Thorns', TO_DATE('1979-09-14', 'YYYY-MM-DD'), 'Trpaslík', 'New Londo', NULL);

INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'Sieglinde', 'Catarina', TO_DATE('1986-07-19', 'YYYY-MM-DD'), 'Trpaslík', 'Izalith', NULL);

INSERT INTO OSOBA (ID_OSOBY, JMÉNO, PŘÍJMENÍ, DATUM_NAROZENÍ, RASA, ADRESA_POBYTU, ČÍSLO_LICENCE)
VALUES (1, 'Siegmeyer', 'Catarina', TO_DATE('1999-04-23', 'YYYY-MM-DD'), 'Trpaslík', 'Valoria', NULL);




-- Sklady
INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 15000, 4234, 'Měď');

INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 15000, 1253, 'Železo');

INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 10000, 3425, 'Platina');

INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 6000, 2346, 'Palladium');

INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 4000, 3211, 'Mytril');

INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 2500, 746, 'Adamantit');

INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 3000, 1238, 'Měď');

INSERT INTO SKLAD (ID_SKLADU, KAPACITA, ZAPLNĚNÍ, TYP_SUROVINY)
VALUES (1, 3000, 998, 'Železo');




-- Doly
INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1, 'VELKÝ', 4 ,'Měď', 1);

INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1,  'VELKÝ', 4 ,'Železo', 2);

INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1,  'STŘEDNÍ', 5 ,'Platina', 3);

INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1, 'STŘEDNÍ', 6 ,'Palladium', 4);

INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1, 'MALÝ', 7 ,'Mytril', 5);

INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1,  'MALÝ', 8 ,'Adamantit', 6);

INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1,  'MALÝ', 7 ,'Měď', 7);

INSERT INTO DUL (ID_DOLU, VELIKOST_DOLU, ID_OSOBY, TYP_SUROVINY, ID_SKLADU)
VALUES (1,  'MALÝ', 8 ,'Železo', 8);




-- VLASTNÍ
INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (1, 1, 100);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (2, 2, 100);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (1, 3, 50);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (2, 3, 50);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (1, 4, 50);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (2, 4, 50);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (3, 5, 100);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (3, 6, 100);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (3, 7, 100);

INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (3, 8, 100);





-- DISPONUJE
INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (1, 1);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (2, 1);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (1, 2);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (2, 2);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (2, 3);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (2, 4);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (3, 5);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (3, 6);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (3, 7);

INSERT INTO DISPONUJE (ID_OSOBY, ID_SKLADU)
VALUES (3, 8);




-- KONTRAKT
INSERT INTO KONTRAKT (CISLO_KONTRAKTU, DELKA_TRVANI, DATUM_UZAVRENI, TYP_SUROVINY, MNOZSTVI, CISLO_LICENCE, ID_OSOBY)
VALUES (1, 20, TO_DATE('2025-03-23', 'YYYY-MM-DD'), 'Měď', 300, 2 , 5);

INSERT INTO KONTRAKT (CISLO_KONTRAKTU, DELKA_TRVANI, DATUM_UZAVRENI, TYP_SUROVINY, MNOZSTVI, CISLO_LICENCE, ID_OSOBY)
VALUES (1, 60, TO_DATE('2025-02-23', 'YYYY-MM-DD'), 'Adamantit', 20, 1 , 7);




-- PŘEPRAVA
INSERT INTO PŘEPRAVA (ID_PŘEPRAVY, CENA, DATUM_ZADÁNÍ, STAV, TYP_SUROVINY, MNOŽSTVÍ, ČÍSLO_LICENCE, ID_SKLADU_Z, ID_SKLADU_DO)
VALUES (1, 9000, TO_DATE('2025-03-24', 'YYYY-MM-DD'), 'Dodáno','Měď' ,150, 1, 1, 7);

INSERT INTO PŘEPRAVA (ID_PŘEPRAVY, CENA, DATUM_ZADÁNÍ, STAV, TYP_SUROVINY, MNOŽSTVÍ, ČÍSLO_LICENCE, ID_SKLADU_Z, ID_SKLADU_DO)
VALUES (1, 9000, TO_DATE('2025-03-26', 'YYYY-MM-DD'), 'Dodáno','Měď' ,150, 1, 1, 7);

INSERT INTO PŘEPRAVA (ID_PŘEPRAVY, CENA, DATUM_ZADÁNÍ, STAV, TYP_SUROVINY, MNOŽSTVÍ, ČÍSLO_LICENCE, ID_SKLADU_Z, ID_SKLADU_DO)
VALUES (seq_preprava_id.NEXTVAL, 100, TO_DATE('2025-04-05','YYYY-MM-DD'), 'Dodáno',    'Měď',    500, 1, 1, 2);

INSERT INTO PŘEPRAVA (ID_PŘEPRAVY, CENA, DATUM_ZADÁNÍ, STAV, TYP_SUROVINY, MNOŽSTVÍ, ČÍSLO_LICENCE, ID_SKLADU_Z, ID_SKLADU_DO)
VALUES (seq_preprava_id.NEXTVAL, 110, TO_DATE('2025-04-10','YYYY-MM-DD'), 'Na cestě', 'Měď',    700, 1, 1, 2);

INSERT INTO PŘEPRAVA (ID_PŘEPRAVY, CENA, DATUM_ZADÁNÍ, STAV, TYP_SUROVINY, MNOŽSTVÍ, ČÍSLO_LICENCE, ID_SKLADU_Z, ID_SKLADU_DO)
VALUES (seq_preprava_id.NEXTVAL, 120, TO_DATE('2025-04-15','YYYY-MM-DD'), 'Dodáno',    'Železo', 300, 2, 2, 3);

INSERT INTO PŘEPRAVA (ID_PŘEPRAVY, CENA, DATUM_ZADÁNÍ, STAV, TYP_SUROVINY, MNOŽSTVÍ, ČÍSLO_LICENCE, ID_SKLADU_Z, ID_SKLADU_DO)
VALUES (seq_preprava_id.NEXTVAL, 150, TO_DATE('2025-04-20','YYYY-MM-DD'), 'Dokončeno', 'Platina', 200, 1, 3, 4);

COMMIT;


-- JE SOUČÁSTÍ
INSERT INTO JE_SOUČÁSTÍ (ID_PŘEPRAVY, ČÍSLO_KONTRAKTU)
VALUES (1, 1);

INSERT INTO JE_SOUČÁSTÍ (ID_PŘEPRAVY, ČÍSLO_KONTRAKTU)
VALUES (2, 1);


COMMIT;


--------------------------------------------------- TRIGGERS ------------------------------------------------------------


-- Kontroluje jestli podil neni vyssi nez 100%
CREATE OR REPLACE TRIGGER trg_check_podil
BEFORE INSERT OR UPDATE ON VLASTNÍ
FOR EACH ROW
DECLARE
    v_total_podil NUMBER;
BEGIN
    -- Zkontrolujeme, zda podíl není mimo povolený rozsah
    IF :NEW.PODÍL > 100 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Podíl nesmí být větší než 100');
    ELSIF :NEW.PODÍL < 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Podíl nesmí být menší než 0');
    END IF;

    -- Sečteme existující podíly pro daný ID_DOLU, bez aktuálního záznamu (pro UPDATE)
    SELECT NVL(SUM(PODÍL), 0)
    INTO v_total_podil
    FROM VLASTNÍ
    WHERE ID_DOLU = :NEW.ID_DOLU
      AND (ID_OSOBY != :NEW.ID_OSOBY OR (:OLD.ID_DOLU != :NEW.ID_DOLU));

    -- Přičteme nový podíl
    v_total_podil := v_total_podil + :NEW.PODÍL;

    -- Ověříme, že součet nepřesahuje 100 %
    IF v_total_podil > 100 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Součet podílů pro daný důl nesmí přesáhnout 100%');
    END IF;
END;

-- Test triggeru
INSERT INTO VLASTNÍ (ID_OSOBY, ID_DOLU, PODÍL)
VALUES (1, 8, 50);



-- Kontroluje, zda zaplneni neprevysi kapacitu skladu
CREATE OR REPLACE TRIGGER trg_update_sklad_zaplnění
AFTER INSERT ON PŘEPRAVA
FOR EACH ROW
BEGIN
    UPDATE SKLAD
    SET ZAPLNĚNÍ = ZAPLNĚNÍ - :NEW.MNOŽSTVÍ
    WHERE ID_SKLADU = :NEW.ID_SKLADU_Z;

    UPDATE SKLAD
    SET ZAPLNĚNÍ = ZAPLNĚNÍ + :NEW.MNOŽSTVÍ
    WHERE ID_SKLADU = :NEW.ID_SKLADU_DO;
END;

-- Priklad predpoklada, ze sklady maji dostatecnou kapacitu a zaplneni
INSERT INTO PŘEPRAVA (ID_PŘEPRAVY, CENA, DATUM_ZADÁNÍ, STAV, TYP_SUROVINY, MNOŽSTVÍ, ČÍSLO_LICENCE, ID_SKLADU_Z, ID_SKLADU_DO)
VALUES (1, 1000, SYSDATE, 'Nová', 'Železo', 99999999999999, 1, 1, 2);

---------------------------------------------------- PROCEDURES --------------------------------------------------------

-- Zvysi kapacitu vsech skladu se zvolenou surovinou o dany pocet procent
    CREATE OR REPLACE PROCEDURE zvys_kapacitu_skladů(p_typ_suroviny SUROVINA.TYP_SUROVINY%TYPE, p_procento NUMBER) IS
    CURSOR c_sklady IS
        SELECT s.ID_SKLADU, s.KAPACITA
        FROM SKLAD s
        WHERE s.TYP_SUROVINY = p_typ_suroviny;

    r_sklad c_sklady%ROWTYPE;
BEGIN
    -- Procházení skladů pro danou surovinu
    OPEN c_sklady;
    LOOP
        FETCH c_sklady INTO r_sklad;
        EXIT WHEN c_sklady%NOTFOUND;

        -- Navýšení kapacity skladu o zadané procento
        UPDATE SKLAD
        SET KAPACITA = r_sklad.KAPACITA * (1 + p_procento / 100)
        WHERE ID_SKLADU = r_sklad.ID_SKLADU;
    END LOOP;
    CLOSE c_sklady;

    COMMIT;  -- Uložení změn do databáze
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;  -- V případě chyby zrušit změny
        DBMS_OUTPUT.PUT_LINE('Chyba při zvyšování kapacity skladů: ' || SQLERRM);
END;

BEGIN
    zvys_kapacitu_skladů('Železo', 10);
END;

COMMIT;


-- Zvysi cenu dane suroviny o zadany pocet procent
CREATE OR REPLACE PROCEDURE zvys_cenu_suroviny(
    p_typ SUROVINA.TYP_SUROVINY%TYPE,
    p_procento NUMBER
) IS
    v_stara_cena SUROVINA.CENA_KG%TYPE;
BEGIN
    SELECT CENA_KG INTO v_stara_cena FROM SUROVINA WHERE TYP_SUROVINY = p_typ;

    UPDATE SUROVINA
    SET CENA_KG = CENA_KG * (1 + p_procento / 100)
    WHERE TYP_SUROVINY = p_typ;

    DBMS_OUTPUT.PUT_LINE('Cena byla zvýšena z ' || v_stara_cena || ' na ' || v_stara_cena * (1 + p_procento / 100));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Surovina nebyla nalezena.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Chyba při zvyšování ceny: ' || SQLERRM);
END;

BEGIN
    zvys_cenu_suroviny('Platina', 10);
END;

COMMIT;

---------------------------------------------------- EXPLAIN PLAN + INDEX ------------------------------------------------------
-- Pro kazdou surovinu vypocita kolik preprav se na ni uskutecnilo v minulem mesici a v jakem celkovem mnoystvi
EXPLAIN PLAN FOR
SELECT
  p.TYP_SUROVINY,
  COUNT(*)            AS POCET_PREPRAV,
  SUM(p.MNOŽSTVÍ)     AS CELKOVE_MNOZSTVI
FROM PŘEPRAVA p
JOIN SUROVINA s
  ON p.TYP_SUROVINY = s.TYP_SUROVINY
WHERE p.DATUM_ZADÁNÍ
      BETWEEN ADD_MONTHS(TRUNC(SYSDATE,'MM'),-1)
          AND TRUNC(SYSDATE,'MM') - 1
GROUP BY p.TYP_SUROVINY
ORDER BY p.TYP_SUROVINY;
-- vypis
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

--vytvoreni indexu
CREATE INDEX idx_preprava_mesic_typ
  ON PŘEPRAVA(TRUNC(DATUM_ZADÁNÍ,'MM'), TYP_SUROVINY);

-- druhe planovani
EXPLAIN PLAN FOR
SELECT
  p.TYP_SUROVINY,
  COUNT(*)        AS POCET_PREPRAV,
  SUM(p.MNOŽSTVÍ) AS CELKOVE_MNOZSTVI
FROM PŘEPRAVA p
JOIN SUROVINA s
  ON p.TYP_SUROVINY = s.TYP_SUROVINY
WHERE p.DATUM_ZADÁNÍ
      BETWEEN ADD_MONTHS(TRUNC(SYSDATE,'MM'),-1)
          AND TRUNC(SYSDATE,'MM') - 1
GROUP BY p.TYP_SUROVINY
ORDER BY p.TYP_SUROVINY;

--vypis
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


------------------------------------------ PRIVILEGES -------------------------------------------------------
-- Udělení všech oprávnění na všechny tabulky schématu USER1 uživateli xsteflm00
GRANT ALL ON SUROVINA      TO xsteflm00;
GRANT ALL ON FIRMA         TO xsteflm00;
GRANT ALL ON SKLAD         TO xsteflm00;
GRANT ALL ON OSOBA         TO xsteflm00;
GRANT ALL ON DUL           TO xsteflm00;
GRANT ALL ON KONTRAKT      TO xsteflm00;
GRANT ALL ON PŘEPRAVA      TO xsteflm00;
GRANT ALL ON VLASTNÍ       TO xsteflm00;
GRANT ALL ON DISPONUJE     TO xsteflm00;
GRANT ALL ON JE_SOUČÁSTÍ   TO xsteflm00;

GRANT EXECUTE ON zvys_kapacitu_skladů TO XSTEFLM00;
GRANT EXECUTE ON zvys_cenu_suroviny TO XSTEFLM00

------------------------------------------- WITH_CASE SELECT ---------------------------------------------------

-- Vypise vsechny sklady s jejich procentualnim zaplnenim a popiskem podle zaplneni
-- Dalo by se upravit na vypis skladu s kapacitou <> nejake procento
WITH zaplneni_skladu AS (
    SELECT
        id_skladu,
        kapacita,
        zaplnění,
        ROUND((zaplnění / kapacita) * 100, 2) AS procento_zaplneni
    FROM
        sklad
)
SELECT
    id_skladu,
    kapacita,
    zaplnění,
    procento_zaplneni,
    CASE
        WHEN procento_zaplneni < 30 THEN 'Nízké zaplnění'
        WHEN procento_zaplneni BETWEEN 30 AND 70 THEN 'Střední zaplnění'
        ELSE 'Vysoké zaplnění'
    END AS stav_skladu
FROM
    zaplneni_skladu
ORDER BY
    procento_zaplneni DESC;

----------------------------------------------------------------------------------------------------------------
DROP TABLE DISPONUJE CASCADE CONSTRAINTS;
DROP TABLE DUL CASCADE CONSTRAINTS;
DROP TABLE FIRMA CASCADE CONSTRAINTS;
DROP TABLE JE_SOUČÁSTÍ CASCADE CONSTRAINTS;
DROP TABLE KONTRAKT CASCADE CONSTRAINTS;
DROP TABLE OSOBA CASCADE CONSTRAINTS;
DROP TABLE PŘEPRAVA CASCADE CONSTRAINTS;
DROP TABLE SKLAD CASCADE CONSTRAINTS;
DROP TABLE SUROVINA CASCADE CONSTRAINTS;
DROP TABLE VLASTNÍ CASCADE CONSTRAINTS;
DROP SEQUENCE SEQ_DUL_ID;
DROP SEQUENCE SEQ_FIRMA_LICENCE;
DROP SEQUENCE SEQ_KONTRAKT_CISLO;
DROP SEQUENCE SEQ_OSOBA_ID;
DROP SEQUENCE SEQ_PREPRAVA_ID;
DROP SEQUENCE SEQ_SKLAD_ID;
DROP PROCEDURE zvys_cenu_suroviny;
DROP PROCEDURE zvys_kapacitu_skladů;