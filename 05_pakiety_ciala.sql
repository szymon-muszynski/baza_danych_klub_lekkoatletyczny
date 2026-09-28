-- Ciala pakietow, implementacja logiki


CREATE OR REPLACE NONEDITIONABLE PACKAGE BODY TERMINARZ AS

PROCEDURE ZAKONCZ_MINIONE_AKTYWNOSCI AS
    v_dzien_dzisiaj NUMBER;
    v_czas_teraz    NUMBER;
BEGIN
    v_dzien_dzisiaj := TO_NUMBER(TO_CHAR(SYSDATE, 'D')) - 1;
    IF v_dzien_dzisiaj = 0 THEN v_dzien_dzisiaj := 7; END IF;
    
    v_czas_teraz := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) + (TO_NUMBER(TO_CHAR(SYSDATE, 'MI')) / 60);
    
    UPDATE aktywnosci_tab A
    SET A.ODBYTE = 1
    WHERE A.OKRESOWE = 0 
      AND A.ODBYTE = 0
      AND (
          A.TERMIN.DZIEN_TYGODNIA < v_dzien_dzisiaj 
          OR 
          (
              A.TERMIN.DZIEN_TYGODNIA = v_dzien_dzisiaj 
              AND 
              (A.TERMIN.GODZINA + (A.TERMIN.MINUTA + A.TERMIN.CZAS_TRWANIA)/60) <= v_czas_teraz
          )
      );
END ZAKONCZ_MINIONE_AKTYWNOSCI;

PROCEDURE DODAJ_MIEJSCE ( 
    nazwa_miejsca IN VARCHAR2,
    max_osob IN NUMBER
) AS
    v_Miejsce_ID NUMBER;
BEGIN
    IF nazwa_miejsca IS NULL OR TRIM(nazwa_miejsca) = '' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Nazwa miejsca nie moze byc pusta.');
    ELSIF max_osob <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Maksymalna liczba osob musi byc wieksza niz 0.');
    END IF;
    
    INSERT INTO MIEJSCA_TAB VALUES (
        MIEJSCE_TYP(MIEJSCA_TAB_SEQ.NEXTVAL, Nazwa_MIEJSCA, Max_osob)
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Miejsce "' || nazwa_miejsca || '" zostalo dodane.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Blad: ' || SQLERRM);
        RAISE;
END DODAJ_MIEJSCE;


PROCEDURE Usun_Miejsce (
    p_Miejsce_ID IN NUMBER
) AS
BEGIN
    DELETE FROM MIEJSCA_TAB WHERE MIEJSCE_ID = p_Miejsce_ID;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Miejsce o podanym ID nie istnieje.');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Miejsce o ID: ' || p_Miejsce_ID || ' zostalo usuniete.');
    END IF;
END Usun_Miejsce;


PROCEDURE Dodaj_Aktywnosc (
    p_Typ IN VARCHAR2,
    P_TERMIN TERMIN_TYP,
    p_Okresowe IN NUMBER,
    p_Lista_Osob IN OSOBY_REF_TAB,
    p_Miejsce_ID IN NUMBER
) AS
    v_Miejsce REF MIEJSCE_TYP;
BEGIN
    IF (P_OKRESOWE NOT IN (0, 1)) OR p_Lista_Osob IS NULL OR p_Lista_Osob.COUNT < 1 THEN
        RAISE_APPLICATION_ERROR(-20004, 'BLEDNE PARAMETRY WEJSCIOWE: Okresowe musi byc 0/1, a lista osob nie moze byc pusta.');
    END IF;

    -- to powoduje, ze aktywnosci, ktore nie sa okresowe, po odbyciu zostana zakonczone, tak aby
    -- nowe aktywnosci mogly zostac wpisane w plan zajec
    TERMINARZ.ZAKONCZ_MINIONE_AKTYWNOSCI;

    BEGIN
        SELECT REF(m) INTO v_Miejsce FROM MIEJSCA_TAB m WHERE m.MIEJSCE_ID = p_Miejsce_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006, 'PODANE MIEJSCE NIE ISTNIEJE.');
    END;

    IF ZAJETE_MIEJSCE(P_TERMIN, P_MIEJSCE_ID, P_LISTA_OSOB.COUNT) = TRUE THEN
        RAISE_APPLICATION_ERROR(-20003, 'NA OBIEKCIE O TEJ GODZINIE I TYM DNIU BRAKUJE MIEJSC LUB JEST ZAJETY!');
    END IF;
     
    IF ZAJETY_ZAWODNIK(P_TERMIN, P_LISTA_OSOB) = TRUE THEN
        RAISE_APPLICATION_ERROR(-20005, 'JEDEN LUB WIECEJ ZAWODNIKOW MA JUZ W TYM CZASIE INNE ZAJECIA!');
    END IF;

    INSERT INTO AKTYWNOSCI_TAB VALUES (
        AKTYWNOSCI_TYP(
            AKTYWNOSCI_TAB_SEQ.NEXTVAL,
            p_Typ,
            P_TERMIN,
            p_Okresowe,
            p_Lista_Osob,
            v_Miejsce,
            0
        )
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Aktywnosc ' || p_Typ || ' zostala poprawnie dodana do harmonogramu.');
END Dodaj_Aktywnosc;


FUNCTION ZAJETE_MIEJSCE (
    T1 TERMIN_TYP,
    P_MIEJSCE_ID NUMBER,
    DODATKOWA_LICZBA_OSOB NUMBER
) RETURN BOOLEAN AS
    MAX_CAPACITY NUMBER := 0;
    PEOPLE_COUNT NUMBER := 0;
BEGIN
    FOR akt IN (
        SELECT Lista_osob
        FROM AKTYWNOSCI_TAB A
        WHERE A.odbyte = 0 
          AND DEREF(A.MIEJSCE).MIEJSCE_ID = P_MIEJSCE_ID 
          AND T1.CZY_KONFLIKT(A.TERMIN) = 1
    ) LOOP
        IF akt.Lista_osob IS NOT NULL THEN
            PEOPLE_COUNT := PEOPLE_COUNT + akt.Lista_osob.COUNT;
        END IF;
    END LOOP;
      
    SELECT MAX_OSOB INTO MAX_CAPACITY FROM MIEJSCA_TAB WHERE MIEJSCE_ID = P_MIEJSCE_ID;
      
    IF MAX_CAPACITY >= PEOPLE_COUNT + DODATKOWA_LICZBA_OSOB THEN
        RETURN FALSE; 
    END IF;
    RETURN TRUE; 
END ZAJETE_MIEJSCE;


FUNCTION ZAJETY_ZAWODNIK ( 
    T1 TERMIN_TYP,
    p_Lista_Osob IN OSOBY_REF_TAB
) RETURN BOOLEAN AS
BEGIN
    -- Skanujemy tylko te aktywnosci, z ktorymi koliduje nasz nowy czas
    FOR r IN (
        SELECT Lista_osob
        FROM AKTYWNOSCI_TAB A
        WHERE A.odbyte = 0 AND T1.CZY_KONFLIKT(A.TERMIN) = 1
    ) LOOP
        IF r.Lista_osob IS NOT NULL THEN
            -- Jesli chociaz jeden zawodnik z nowej listy jest na liscie istniejacej aktywnosci, to jest konflikt
            FOR i IN 1 .. p_Lista_Osob.COUNT LOOP
                IF p_Lista_Osob(i) MEMBER OF r.Lista_osob THEN
                    -- Znaleziono zawodnika, czyli kolizja
                    RETURN TRUE; 
                END IF;
            END LOOP;
        END IF;
    END LOOP;
    
    RETURN FALSE; -- Wszyscy sa wolni w tym terminie
END ZAJETY_ZAWODNIK;


PROCEDURE Usun_Aktywnosc (
    p_Aktywnosc_ID IN NUMBER
) AS
BEGIN
    DELETE FROM AKTYWNOSCI_TAB WHERE AKTYWNOSC_ID = p_Aktywnosc_ID;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Aktywnosc o podanym ID nie istnieje.');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Aktywnosc o ID: ' || p_Aktywnosc_ID || ' zostala usunieta ze wszystkimi wpisami na listach obecnosci.');
    END IF;
END Usun_Aktywnosc;

END TERMINARZ;
/
---------------------------------------------------------

CREATE OR REPLACE NONEDITIONABLE PACKAGE BODY TRENER AS

PROCEDURE DODAJ_RAPORT(
    p_aktywnosc_id   IN NUMBER,
    p_lista_obecnych IN OSOBY_REF_TAB,
    p_uwagi          IN VARCHAR2
) AS
    v_aktywnosc_ref REF AKTYWNOSCI_TYP;
BEGIN
    BEGIN
        SELECT REF(A) INTO v_aktywnosc_ref 
        FROM AKTYWNOSCI_TAB A
        WHERE A.AKTYWNOSC_ID = p_aktywnosc_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'Aktywnosc o podanym ID nie istnieje.');
    END;

    IF p_lista_obecnych IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Lista obecnych osob nie moze byc NULL.');
    END IF;

    INSERT INTO RAPORTY_TAB VALUES (
        RAPORT_OBECNOSCI(
            RAPORT_TAB_SEQ.NEXTVAL, 
            v_aktywnosc_ref,
            p_lista_obecnych,
            SYSDATE, 
            p_uwagi
        )
    );
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Poprawnie dodano raport dla aktywnosci ID: ' || p_aktywnosc_id);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Blad podczas dodawania raportu: ' || SQLERRM);
        ROLLBACK;
END DODAJ_RAPORT;

PROCEDURE USUN_RAPORT(
    P_RAPORT_ID IN NUMBER
) AS
BEGIN
    -- Od razu próbujemy usun¹æ raport
    DELETE FROM RAPORTY_TAB
    WHERE RAPORT_ID = P_RAPORT_ID;

    -- Sprawdzamy, czy cokolwiek zostalo usuniete
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Raport o podanym ID nie istnieje.');
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Usunieto raport o ID: ' || P_RAPORT_ID);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Blad podczas usuwania raportu: ' || SQLERRM);
        ROLLBACK;
END USUN_RAPORT;

PROCEDURE WYSWIETL_OBECNOSCI_ZAWODNIKA(
    P_ZAWODNIK_ID NUMBER
) AS
    v_zawodnik_ref REF Osoba_typ;
    v_aktywnosc    AKTYWNOSCI_TYP;
    v_obecnosci    NUMBER := 0;
    v_nieobecnosci NUMBER := 0;
    v_czy_obecny   BOOLEAN;
BEGIN
    BEGIN
    -- to REF(o) to jest wziêcie wskaznika tego wiersza
        SELECT REF(o) INTO v_zawodnik_ref FROM Osoba_tab o WHERE o.Osoba_id = P_ZAWODNIK_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Brak zawodnika o ID: ' || P_ZAWODNIK_ID);
            RETURN;
    END;

    DBMS_OUTPUT.PUT_LINE('RAPORT FREKWENCJI ZAWODNIKA ID: ' || P_ZAWODNIK_ID);

    FOR r IN (
        SELECT rt.RAPORT_ID, rt.AKTYWNOSC, rt.LISTA_OBECNYCH, rt.DATA_UTWORZENIA, rt.UWAGI
        FROM RAPORTY_TAB rt
    ) LOOP
        SELECT DEREF(r.AKTYWNOSC) INTO v_aktywnosc FROM DUAL;
        
        IF v_zawodnik_ref MEMBER OF v_aktywnosc.Lista_osob THEN
            v_czy_obecny := FALSE;
            
            IF r.LISTA_OBECNYCH IS NOT NULL THEN
                IF v_zawodnik_ref MEMBER OF r.LISTA_OBECNYCH THEN
                    v_czy_obecny := TRUE;
                END IF;
            END IF;
            
            IF v_czy_obecny THEN
                v_obecnosci := v_obecnosci + 1;
                DBMS_OUTPUT.PUT_LINE('Zajecia: ' || v_aktywnosc.TYP || ' (ID: ' || v_aktywnosc.AKTYWNOSC_ID || ') | STATUS: [ OBECNY ]');
                IF r.UWAGI IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' Uwagi trenera: ' || r.UWAGI); END IF;
            ELSE
                v_nieobecnosci := v_nieobecnosci + 1;
                DBMS_OUTPUT.PUT_LINE('Zajecia: ' || v_aktywnosc.TYP || ' (ID: ' || v_aktywnosc.AKTYWNOSC_ID || ') | STATUS: [ NIEOBECNY ]');
            END IF;
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Lacznie: ' || v_obecnosci || ' obecnosci / ' || v_nieobecnosci || ' nieobecnosci');
END WYSWIETL_OBECNOSCI_ZAWODNIKA;

END TRENER;
/
---------------------------------------------------

CREATE OR REPLACE NONEDITIONABLE PACKAGE BODY WYSWIETLANIE AS

PROCEDURE DRUKUJ_AKTYWNOSC (REC AKTYWNOSCI_TYP) AS
    v_Miejsce MIEJSCE_TYP;
BEGIN
    DBMS_OUTPUT.PUT_LINE('AKTYWNOSC ID: ' || REC.AKTYWNOSC_ID || ' | TYP: ' || REC.TYP);
    DBMS_OUTPUT.PUT_LINE('GODZINA:      ' || REC.TERMIN.CZAS_FORMATOWANY());
    DBMS_OUTPUT.PUT_LINE('CZAS TRWANIA: ' || REC.TERMIN.CZAS_TRWANIA || ' min');
    
    IF REC.MIEJSCE IS NOT NULL THEN
        SELECT DEREF(REC.MIEJSCE) INTO v_Miejsce FROM DUAL;
        DBMS_OUTPUT.PUT_LINE('MIEJSCE:      ' || v_Miejsce.NAZWA); 
    END IF;
    
    IF REC.OKRESOWE = 1 THEN DBMS_OUTPUT.PUT_LINE('CZESTOTLIWOSC: CYKLICZNA');
    ELSE DBMS_OUTPUT.PUT_LINE('CZESTOTLIWOSC: JEDNORAZOWA'); END IF;
    
    IF REC.ODBYTE = 1 THEN DBMS_OUTPUT.PUT_LINE('STATUS:       ZAKONCZONE');
    ELSE DBMS_OUTPUT.PUT_LINE('STATUS:       AKTUALNE'); END IF;
    
    DBMS_OUTPUT.PUT_LINE('-----------------------------------');
END DRUKUJ_AKTYWNOSC;

PROCEDURE WYSWIETL_AKTYWNOSCI_OSOBY (
    OSOBA_ID NUMBER,
    OKRESOWE NUMBER, 
    ODBYTE NUMBER, 
    DZIEN NUMBER
) AS
    v_osoba Osoba_typ;
    v_licznik NUMBER := 0;
BEGIN
    BEGIN
        SELECT VALUE(o) INTO v_osoba FROM Osoba_tab o WHERE o.Osoba_id = OSOBA_ID;
        DBMS_OUTPUT.PUT_LINE('==================================================');
        DBMS_OUTPUT.PUT_LINE('ZAWODNIK:' || v_osoba.PelneImie());
        DBMS_OUTPUT.PUT_LINE('DATA URODZENIA: ' || TO_CHAR(v_osoba.Data_urodzenia, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('==================================================');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Brak zawodnika o ID: ' || OSOBA_ID);
            RETURN;
    END;

    FOR r IN (
        SELECT VALUE(a) AS obiekt_aktywnosci
        FROM AKTYWNOSCI_TAB a,
             TABLE(a.Lista_osob) l
        WHERE DEREF(l.COLUMN_VALUE).Osoba_id = OSOBA_ID 
          AND (a.ODBYTE = ODBYTE OR ODBYTE = 2) 
          AND (a.OKRESOWE = OKRESOWE OR OKRESOWE = 2) 
          AND (a.TERMIN.DZIEN_TYGODNIA = DZIEN OR DZIEN = 0)
    )
    LOOP
        DRUKUJ_AKTYWNOSC(r.obiekt_aktywnosci);
        v_licznik := v_licznik + 1;
    END LOOP;

    IF v_licznik = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Brak zapisanych aktywnosci spelniajacych kryteria.');
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    END IF;
END WYSWIETL_AKTYWNOSCI_OSOBY;

PROCEDURE POKAZ_WSZYSTKIE_AKTYWNOSCI AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('HARMONOGRAM WSZYSTKICH AKTYWNOSCI');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    FOR r IN (
        SELECT VALUE(a) AS obiekt_aktywnosci FROM AKTYWNOSCI_TAB a
    )
    LOOP
        DRUKUJ_AKTYWNOSC(r.obiekt_aktywnosci);
        WYSWIETL_ZAWODNIKOW_DLA_AKTYWNOSCI(r.obiekt_aktywnosci.AKTYWNOSC_ID);
    END LOOP;
END POKAZ_WSZYSTKIE_AKTYWNOSCI;


PROCEDURE WYSWIETL_ZAWODNIKOW_DLA_AKTYWNOSCI(P_AKTYWNOSC_ID NUMBER) AS
    v_aktywnosc AKTYWNOSCI_TYP;
    v_osoba Osoba_typ;
BEGIN
    SELECT VALUE(a) INTO v_aktywnosc 
    FROM AKTYWNOSCI_TAB a 
    WHERE a.AKTYWNOSC_ID = P_AKTYWNOSC_ID;

    DBMS_OUTPUT.PUT_LINE('UCZESTNICY ZAJEC: ' || v_aktywnosc.TYP);
    
    IF v_aktywnosc.LISTA_OSOB IS NOT NULL AND v_aktywnosc.LISTA_OSOB.COUNT > 0 THEN
        FOR i IN 1 .. v_aktywnosc.LISTA_OSOB.COUNT LOOP
            SELECT DEREF(v_aktywnosc.LISTA_OSOB(i)) INTO v_osoba FROM DUAL;
            DBMS_OUTPUT.PUT_LINE(' - ' || v_osoba.PelneImie() || ' (ID: ' || v_osoba.Osoba_id || ')');
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE(' - Brak przypisanych osob.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('-----------------------------------');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Brak aktywnosci o ID: ' || P_AKTYWNOSC_ID);
END WYSWIETL_ZAWODNIKOW_DLA_AKTYWNOSCI;


PROCEDURE WYSWIETL_KONDYCJE_ZAWODNIKA(ZAWODNIK_ID NUMBER) AS
    v_kondycja WYTRENOWANIE_TYP;
BEGIN
    SELECT o.Wytrenowanie
    INTO v_kondycja
    FROM OSOBA_TAB o
    WHERE o.Osoba_id = ZAWODNIK_ID;

    DBMS_OUTPUT.PUT_LINE('Kondycja: ' || v_kondycja.kondycja);
    DBMS_OUTPUT.PUT_LINE('Masa:     ' || v_kondycja.masa || ' kg');
    DBMS_OUTPUT.PUT_LINE('Wzrost:   ' || v_kondycja.wzrost || ' cm');
    DBMS_OUTPUT.PUT_LINE('Data aktualizacji: ' || TO_CHAR(v_kondycja.data_aktualizacji, 'YYYY-MM-DD HH24:MI'));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Brak zawodnika o ID: ' || ZAWODNIK_ID);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Wystapil blad: ' || SQLERRM);
END WYSWIETL_KONDYCJE_ZAWODNIKA;

PROCEDURE WYSWIETL_WSZYSTKICH_ZAWODNIKOW AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('KADRA ZAWODNICZA KLUBU');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    
    -- Wykorzystanie self-join do wyci¹gniêcia nazwiska trenera w jednym zapytaniu
    FOR r IN (
        SELECT z.Imie, 
               z.Nazwisko, 
               z.Osoba_id, 
               t.Nazwisko AS Nazwisko_trenera
        FROM Osoba_tab z
        LEFT JOIN Osoba_tab t ON z.Przelozony_id = t.Osoba_id
        WHERE z.Rola = 'zawodnik'
        ORDER BY z.Nazwisko, z.Imie
    ) 
    LOOP
        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || TO_CHAR(r.Osoba_id, 'FM000') || 
            ' | ' || RPAD(r.Imie || ' ' || r.Nazwisko, 25) || 
            ' | Trener: ' || NVL(r.Nazwisko_trenera, 'Brak (nieprzydzielony)')
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('==================================================');
END WYSWIETL_WSZYSTKICH_ZAWODNIKOW;

END WYSWIETLANIE;
/

-------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY OBSLUGA_ZAWODNIKA AS
    PROCEDURE DodajZawodnika(
        p_Imie VARCHAR2,
        p_Nazwisko VARCHAR2,
        p_Kraj_pochodzenia VARCHAR2,
        p_Data_urodzenia DATE,
        p_Przydzielony_trener NUMBER,
        p_Koniec_ubezpieczenia DATE
    ) IS
    v_liczba NUMBER;
    BEGIN
        IF p_Przydzielony_trener IS NOT NULL THEN
        SELECT COUNT(*) INTO v_liczba FROM Osoba_tab WHERE Przelozony_id = p_Przydzielony_trener;
            IF v_liczba >= 5 THEN
                RAISE_APPLICATION_ERROR(-20001, 'Trener nie moze miec wiecej niz 5 zawodnikow.');
            END IF;
        END IF;
        INSERT INTO Osoba_tab VALUES (
            Osoba_typ(
                seq_zawodnik_id.NEXTVAL, p_Imie, p_Nazwisko, p_Kraj_pochodzenia,
                p_Data_urodzenia, 'zawodnik', p_Przydzielony_trener,
                Wytrenowanie_typ(100, 70, 180, SYSDATE),
                Wystepy_tab(),      -- Puste kolekcje od razu zainicjowane
                Dyscyplina_tab(),
                PB_Wynik_tab(),
                1,
                p_Koniec_ubezpieczenia
            )
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Dodano nowego zawodnika: ' || p_Imie || ' ' || p_Nazwisko);
    END;

    PROCEDURE UsunZawodnika(p_Osoba_id NUMBER) IS
    BEGIN
        DELETE FROM Osoba_tab WHERE Osoba_id = p_Osoba_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Zawodnik o podanym ID nie istnieje.');
        END IF;
        COMMIT;
    END;

    PROCEDURE AktualizujDaneZawodnika(
        p_Osoba_id NUMBER,
        p_Imie VARCHAR2 := NULL,
        p_Nazwisko VARCHAR2 := NULL,
        p_Kraj_pochodzenia VARCHAR2 := NULL,
        p_Data_urodzenia DATE := NULL,
        p_Przydzielony_trener NUMBER := NULL
    ) IS
    v_liczba NUMBER;
    BEGIN
        IF p_Przydzielony_trener IS NOT NULL THEN
        SELECT COUNT(*) INTO v_liczba FROM Osoba_tab WHERE Przelozony_id = p_Przydzielony_trener;
            IF v_liczba >= 5 THEN
                RAISE_APPLICATION_ERROR(-20001, 'Trener nie moze miec wiecej niz 5 zawodnikow.');
            END IF;
        END IF;
        UPDATE Osoba_tab
        SET Imie = NVL(p_Imie, Imie),
            Nazwisko = NVL(p_Nazwisko, Nazwisko),
            Kraj_pochodzenia = NVL(p_Kraj_pochodzenia, Kraj_pochodzenia),
            Data_urodzenia = NVL(p_Data_urodzenia, Data_urodzenia),
            Przelozony_id = NVL(p_Przydzielony_trener, Przelozony_id)
        WHERE Osoba_id = p_Osoba_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Zawodnik o podanym ID nie istnieje.');
        END IF;
        COMMIT;
    END;

    PROCEDURE AktualizujKondycje(
        p_Osoba_id NUMBER,
        p_Kondycja NUMBER := NULL,
        p_Masa NUMBER := NULL,
        p_Wzrost NUMBER := NULL
    ) IS
    BEGIN
        UPDATE Osoba_tab o
        SET o.Wytrenowanie.Kondycja = NVL(p_Kondycja, o.Wytrenowanie.Kondycja),
            o.Wytrenowanie.Masa = NVL(p_Masa, o.Wytrenowanie.Masa),
            o.Wytrenowanie.Wzrost = NVL(p_Wzrost, o.Wytrenowanie.Wzrost),
            o.Wytrenowanie.Data_aktualizacji = SYSDATE
        WHERE Osoba_id = p_Osoba_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Zawodnik o podanym ID nie istnieje.');
        END IF;
        
        COMMIT;
    END AktualizujKondycje;

    PROCEDURE ZmienStatusZawodnika(p_Osoba_id NUMBER, p_Status NUMBER) IS
    BEGIN
        UPDATE Osoba_tab SET Active = p_Status WHERE Osoba_id = p_Osoba_id;
        COMMIT;
    END;
    
    PROCEDURE AktualizujUbezpieczenie(p_Osoba_id NUMBER, p_Koniec_ubezpieczenia DATE) IS
    BEGIN
        UPDATE Osoba_tab SET Koniec_ubezpieczenia = p_Koniec_ubezpieczenia WHERE Osoba_id = p_Osoba_id;
        COMMIT;
    END;

    PROCEDURE DodajWystep(p_Osoba_id NUMBER, p_Wystep Wystepy_typ) IS
    v_duplikaty NUMBER;
    BEGIN
        -- Sprawdzanie w bazie przed dodaniem
        SELECT COUNT(*) INTO v_duplikaty
        FROM Osoba_tab o, TABLE(o.Wystepy) w
        WHERE o.Osoba_id = p_Osoba_id
          AND w.Nazwa = p_Wystep.Nazwa
          AND w.Miejscowosc = p_Wystep.Miejscowosc
          AND w.Konkurencja = p_Wystep.Konkurencja;
    
        IF v_duplikaty > 0 THEN
             RAISE_APPLICATION_ERROR(-20011, 'Taki wystep juz istnieje!');
        END IF;
    
        INSERT INTO TABLE(SELECT Wystepy FROM Osoba_tab WHERE Osoba_id = p_Osoba_id) VALUES (p_Wystep);
        COMMIT;
    END;
    
    PROCEDURE DodajDyscypline(p_Osoba_id NUMBER, p_Dyscyplina Dyscyplina_typ) IS
    v_LiczbaDyscyplin NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_LiczbaDyscyplin 
        FROM TABLE(SELECT Dyscypliny FROM Osoba_tab WHERE Osoba_id = p_Osoba_id);
        
        IF v_LiczbaDyscyplin >= 5 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Zawodnik moze miec maksymalnie 5 dyscyplin.');
        END IF;
        
        INSERT INTO TABLE(
            SELECT Dyscypliny FROM Osoba_tab WHERE Osoba_id = p_Osoba_id
        ) VALUES (p_Dyscyplina);
        COMMIT;
    END;

    PROCEDURE AktualizujPB(
      p_Osoba_id   NUMBER,
      p_Dyscyplina VARCHAR2,
      p_Wynik      NUMBER,
      p_Rok        NUMBER
  ) IS
      v_Wyniki    PB_Wynik_tab;
      v_idx       NUMBER := 0;
      v_found     BOOLEAN := FALSE;
      v_temp      PB_Wynik_typ;
  BEGIN
      SELECT Wyniki_dyscyplin
        INTO v_Wyniki
        FROM Osoba_tab
       WHERE Osoba_id = p_Osoba_id
       FOR UPDATE;
  
      IF v_Wyniki IS NOT NULL THEN
          FOR i IN 1 .. v_Wyniki.COUNT LOOP
              IF v_Wyniki(i).Rok = p_Rok THEN
                  v_idx := i;
                  v_found := TRUE;
                  EXIT;
              END IF;
          END LOOP;
      END IF;
  
      IF v_found THEN
          v_temp := v_Wyniki(v_idx);
          IF UPPER(TRIM(p_Dyscyplina)) = 'BIEG_100M' THEN
              v_temp.Bieg_100m := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'BIEG_110M_PLOTKI' THEN
              v_temp.Bieg_110m_plotki := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'BIEG_400M' THEN
              v_temp.Bieg_400m := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'BIEG_1500M' THEN
              v_temp.Bieg_1500m := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'SKOK_WZWYZ' THEN
              v_temp.Skok_wzwyz := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'SKOK_TYCZKA' THEN
              v_temp.Skok_tyczka := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'SKOK_W_DAL' THEN
              v_temp.Skok_w_dal := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'METRY_KULA' THEN
              v_temp.Metry_kula := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'METRY_OSZCZEP' THEN
              v_temp.Metry_oszczep := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'METRY_DYSK' THEN
              v_temp.Metry_dysk := p_Wynik;
          ELSIF UPPER(TRIM(p_Dyscyplina)) = 'METRY_MLOT' THEN
              v_temp.Metry_mlot := p_Wynik;
          ELSE
              RAISE_APPLICATION_ERROR(-20020, 'Nieznana dyscyplina: ' || p_Dyscyplina);
          END IF;
          v_Wyniki(v_idx) := v_temp;
  
      ELSE
          v_temp := PB_Wynik_typ(
              Bieg_100m       => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'BIEG_100M' THEN p_Wynik ELSE NULL END,
              Bieg_110m_plotki=> CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'BIEG_110M_PLOTKI' THEN p_Wynik ELSE NULL END,
              Bieg_400m       => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'BIEG_400M' THEN p_Wynik ELSE NULL END,
              Bieg_1500m      => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'BIEG_1500M' THEN p_Wynik ELSE NULL END,
              Skok_wzwyz      => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'SKOK_WZWYZ' THEN p_Wynik ELSE NULL END,
              Skok_tyczka     => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'SKOK_TYCZKA' THEN p_Wynik ELSE NULL END,
              Skok_w_dal      => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'SKOK_W_DAL' THEN p_Wynik ELSE NULL END,
              Metry_kula      => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'METRY_KULA' THEN p_Wynik ELSE NULL END,
              Metry_oszczep   => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'METRY_OSZCZEP' THEN p_Wynik ELSE NULL END,
              Metry_dysk      => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'METRY_DYSK' THEN p_Wynik ELSE NULL END,
              Metry_mlot      => CASE WHEN UPPER(TRIM(p_Dyscyplina)) = 'METRY_MLOT' THEN p_Wynik ELSE NULL END,
              Rok             => p_Rok
          );
  
          IF v_Wyniki IS NULL THEN
              v_Wyniki := PB_Wynik_tab();
          END IF;
          v_Wyniki.EXTEND;
          v_Wyniki(v_Wyniki.LAST) := v_temp;
      END IF;
  
      UPDATE Osoba_tab
      SET Wyniki_dyscyplin = v_Wyniki
      WHERE Osoba_id = p_Osoba_id;
  
      COMMIT;
  END AktualizujPB;

    FUNCTION CzyZawodnikIstnieje(p_OsobaId NUMBER) RETURN BOOLEAN IS
        v_Count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_Count FROM Osoba_tab WHERE Osoba_id = p_OsobaId;
        RETURN v_Count > 0;
    END;
    
    FUNCTION LiczbaAktywnychZawodnikow RETURN NUMBER IS
        v_Count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_Count FROM Osoba_tab WHERE Active = 1 AND Rola = 'zawodnik';
        RETURN v_Count;
    END;
    
    FUNCTION ZwrocPrzelozonego(p_Osoba_id NUMBER) RETURN VARCHAR2 IS
        v_Nazwisko VARCHAR2(50);
    BEGIN
        SELECT t.Nazwisko INTO v_Nazwisko
        FROM Osoba_tab z
        JOIN Osoba_tab t ON z.Przelozony_id = t.Osoba_id
        WHERE z.Osoba_id = p_Osoba_id;
        RETURN v_Nazwisko;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 'Brak przelozonego';
    END ZwrocPrzelozonego;
    
    PROCEDURE PobierzSzczegolyZawodnika(p_OsobaId NUMBER) IS
    BEGIN
        FOR r IN (
            SELECT Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Active, Przelozony_id
            FROM Osoba_tab WHERE Osoba_id = p_OsobaId
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                'Imie: ' || r.Imie || ' | Nazwisko: ' || r.Nazwisko || 
                ' | Kraj: ' || r.Kraj_pochodzenia || ' | Data ur: ' || TO_CHAR(r.Data_urodzenia, 'YYYY-MM-DD') || 
                ' | Rola: ' || r.Rola || ' | Aktywny: ' || CASE WHEN r.Active = 1 THEN 'Tak' ELSE 'Nie' END
            );
        END LOOP;
    END PobierzSzczegolyZawodnika;
    
    PROCEDURE WyswietlWystepyZawodnika(p_Osoba_id NUMBER) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('WYSTEPY ZAWODNIKA ID: ' || p_Osoba_id);
        FOR r IN (
            SELECT wt.Nazwa, wt.Miejscowosc, wt.Konkurencja, wt.Wynik_miejsce
            FROM Osoba_tab o, TABLE(o.Wystepy) wt
            WHERE o.Osoba_id = p_Osoba_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(' - Turniej: ' || r.Nazwa || ' | Miejsce: ' || r.Miejscowosc || ' | Konkurencja: ' || r.Konkurencja || ' | Wynik: ' || r.Wynik_miejsce);
        END LOOP;
    END WyswietlWystepyZawodnika;
    
PROCEDURE WyswietlWynikiZawodnika(p_Osoba_id NUMBER) IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('REKORDY OSOBISTE ZAWODNIKA ID: ' || p_Osoba_id);
    
    FOR r IN (
        SELECT wt.*
        FROM Osoba_tab o, TABLE(o.Wyniki_dyscyplin) wt
        WHERE o.Osoba_id = p_Osoba_id
        ORDER BY wt.Rok DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
        DBMS_OUTPUT.PUT_LINE('ROK: ' || r.Rok);
        
        IF r.Bieg_100m IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Sprint 100m: ' || r.Bieg_100m || ' s'); END IF;
        IF r.Bieg_110m_plotki IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - 110m plotki: ' || r.Bieg_110m_plotki || ' s'); END IF;
        IF r.Bieg_400m IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Bieg 400m: ' || r.Bieg_400m || ' s'); END IF;
        IF r.Bieg_1500m IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Bieg 1500m: ' || r.Bieg_1500m || ' s'); END IF;
        IF r.Skok_wzwyz IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Skok wzwyz: ' || r.Skok_wzwyz || ' m'); END IF;
        IF r.Skok_tyczka IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Skok tyczka: ' || r.Skok_tyczka || ' m'); END IF;
        IF r.Skok_w_dal IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Skok w dal: ' || r.Skok_w_dal || ' m'); END IF;
        IF r.Metry_kula IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Pchniecie kula: ' || r.Metry_kula || ' m'); END IF;
        IF r.Metry_oszczep IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Rzut oszczepem: ' || r.Metry_oszczep || ' m'); END IF;
        IF r.Metry_dysk IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Rzut dyskiem: ' || r.Metry_dysk || ' m'); END IF;
        IF r.Metry_mlot IS NOT NULL THEN DBMS_OUTPUT.PUT_LINE(' - Rzut mlotem: ' || r.Metry_mlot || ' m'); END IF;
    END LOOP;
END WyswietlWynikiZawodnika;

    PROCEDURE WyswietlZawodnikowPodTrenerem(p_Trener_id NUMBER) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('ZAWODNICY TRENERA ID: ' || p_Trener_id);
        FOR r IN (
            SELECT Osoba_id, Imie, Nazwisko, Data_urodzenia, Kraj_pochodzenia
            FROM Osoba_tab
            WHERE Przelozony_id = p_Trener_id AND Rola = 'zawodnik'
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(' ID: ' || r.Osoba_id || ' | ' || r.Imie || ' ' || r.Nazwisko || ' | ' || r.Kraj_pochodzenia);
        END LOOP;
    END WyswietlZawodnikowPodTrenerem;

END OBSLUGA_ZAWODNIKA;
/