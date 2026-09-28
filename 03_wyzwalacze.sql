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

CREATE OR REPLACE TRIGGER update_kondycja_after_insert
AFTER INSERT ON raporty_tab
FOR EACH ROW
DECLARE
    v_ref REF Osoba_typ;
    v_wytrenowanie wytrenowanie_typ;
BEGIN
    IF :NEW.lista_obecnych IS NOT NULL THEN
        FOR i IN 1 .. :NEW.lista_obecnych.COUNT LOOP
            v_ref := :NEW.lista_obecnych(i);
    
            SELECT o.wytrenowanie INTO v_wytrenowanie
            FROM osoba_tab o
            WHERE REF(o) = v_ref;

            v_wytrenowanie.update_kondycja();

            UPDATE osoba_tab o
            SET wytrenowanie = v_wytrenowanie
            WHERE REF(o) = v_ref;
        END LOOP;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error updating kondycja: ' || SQLERRM);
END update_kondycja_after_insert;
/