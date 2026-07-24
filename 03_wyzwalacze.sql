-- Triggery


CREATE OR REPLACE TRIGGER Check_Data_Urodzenia
BEFORE INSERT OR UPDATE ON Osoba_tab
FOR EACH ROW
BEGIN
    IF :NEW.Data_urodzenia > ADD_MONTHS(SYSDATE, -12 * 7) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Data urodzenia musi wskazywac na wiek co najmniej 7 lat.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TR_MaxZawodnicyNaTrenera
BEFORE INSERT OR UPDATE OF Przelozony ON Osoba_tab
FOR EACH ROW
WHEN (NEW.Rola = 'zawodnik')
DECLARE
    liczba_zawodnikow NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO liczba_zawodnikow
    FROM Osoba_tab
    WHERE Przelozony = :NEW.Przelozony;

    IF liczba_zawodnikow >= 5 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Trener nie moze miec wiecej niz 5 zawodnikow.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TR_DyscyplinyZawodnika
BEFORE INSERT OR UPDATE ON Osoba_tab
FOR EACH ROW
WHEN (NEW.Rola = 'zawodnik')
DECLARE
    liczba_dyscyplin NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO liczba_dyscyplin
    FROM TABLE(CAST(:NEW.Dyscypliny AS DYSCYPLINA_TAB));

    IF liczba_dyscyplin > 5 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Zawodnik moze miec maksymalnie 5 dyscyplin.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TR_AktywneUbezpieczenie
BEFORE INSERT OR UPDATE ON Osoba_tab
FOR EACH ROW
WHEN (NEW.Rola = 'zawodnik')
BEGIN
    IF :NEW.Koniec_ubezpieczenia <= SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20006, 'Zawodnik musi posiadac aktywne ubezpieczenie.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TR_UniqueOsoba
BEFORE INSERT ON Osoba_tab
FOR EACH ROW
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_count
  FROM Osoba_tab
  WHERE Imie = :NEW.Imie
    AND Nazwisko = :NEW.Nazwisko
    AND Data_urodzenia = :NEW.Data_urodzenia;
    
  IF v_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20010, 'Osoba o tym samym imieniu, nazwisku i dacie urodzenia juz istnieje.');
  END IF;
END;
/

CREATE OR REPLACE TRIGGER TR_UniqueWystep
BEFORE INSERT OR UPDATE ON Osoba_tab
FOR EACH ROW
DECLARE
   v_duplikaty NUMBER;
BEGIN
   IF :NEW.Wystepy IS NOT NULL THEN
      SELECT COUNT(*)
        INTO v_duplikaty
      FROM (
         SELECT t.Nazwa, t.Miejscowosc, t.Konkurencja
         FROM TABLE(CAST(:NEW.Wystepy AS Wystepy_tab)) t
         GROUP BY t.Nazwa, t.Miejscowosc, t.Konkurencja
         HAVING COUNT(*) > 1
      );
   
      IF v_duplikaty > 0 THEN
         RAISE_APPLICATION_ERROR(-20011, 'Wystep z ta sama nazwa, miejscowoscia i konkurencja juz istnieje wsrod wystepow danej osoby.');
      END IF;
   END IF;
END;
/

CREATE OR REPLACE TRIGGER update_kondycja_after_insert
AFTER INSERT ON raporty_tab
FOR EACH ROW
DECLARE
    v_osoba_id NUMBER;
    v_wytrenowanie wytrenowanie_typ;
BEGIN
    IF :NEW.lista_obecnych IS NOT NULL THEN
        FOR i IN 1 .. :NEW.lista_obecnych.COUNT LOOP
            v_osoba_id := :NEW.lista_obecnych(i);

            SELECT wytrenowanie INTO v_wytrenowanie
            FROM osoba_tab
            WHERE osoba_id = v_osoba_id;

            v_wytrenowanie.update_kondycja();

            UPDATE osoba_tab
            SET wytrenowanie = v_wytrenowanie
            WHERE osoba_id = v_osoba_id;
        END LOOP;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error updating kondycja: ' || SQLERRM);
END update_kondycja_after_insert;
/