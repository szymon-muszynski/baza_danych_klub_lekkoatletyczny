SET SERVEROUTPUT ON FORMAT WRAPPED;
EXEC DBMS_OUTPUT.ENABLE(1000000);

BEGIN
    DBMS_OUTPUT.PUT_LINE('START TESTOW');

END;
/

-- 1. DANE POCZATKOWE (Baza startowa)

INSERT INTO Osoba_tab VALUES (
    Osoba_typ(1, 'Dominik', 'Kowalczyk', 'Polska', TO_DATE('1979-09-25', 'YYYY-MM-DD'), 'trener', NULL,
    Wytrenowanie_typ(100, 70, 180, SYSDATE), Wystepy_tab(), Dyscyplina_tab(), PB_Wynik_tab(), 1, NULL)
);

INSERT INTO Osoba_tab VALUES (
    Osoba_typ(2, 'Piotr', 'Nowak', 'Polska', TO_DATE('1975-08-20', 'YYYY-MM-DD'), 'trener', 1,
    Wytrenowanie_typ(100, 70, 180, SYSDATE), Wystepy_tab(), Dyscyplina_tab(), PB_Wynik_tab(), 1, NULL)
);

BEGIN
    OBSLUGA_ZAWODNIKA.DodajZawodnika('Jan', 'Kowalski', 'Polska', TO_DATE('1990-02-15', 'YYYY-MM-DD'), 2, TO_DATE('2030-12-31', 'YYYY-MM-DD'));
    OBSLUGA_ZAWODNIKA.DodajZawodnika('Anna', 'Nowak', 'Polska', TO_DATE('1995-03-20', 'YYYY-MM-DD'), 2, TO_DATE('2030-12-31', 'YYYY-MM-DD'));
    OBSLUGA_ZAWODNIKA.DodajZawodnika('Piotr', 'Wisniewski', 'Polska', TO_DATE('1992-07-10', 'YYYY-MM-DD'), 2, TO_DATE('2030-12-31', 'YYYY-MM-DD'));
    COMMIT;
END;
/


-- 2. TESTY NEGATYWNE - TRIGGERY I ZABEZPIECZENIA

BEGIN
    DBMS_OUTPUT.PUT_LINE('TEST TRIGGERA: Zbyt mlody zawodnik (< 7 lat)');
    BEGIN
        OBSLUGA_ZAWODNIKA.DodajZawodnika('Bob', 'Budowniczy', 'Polska', SYSDATE - (5*365), 2, TO_DATE('2026-12-31', 'YYYY-MM-DD'));
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SUKCES (Zlapano blad): ' || SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('TEST TRIGGERA: Ubezpieczenie w przeszlosci');
    BEGIN
        OBSLUGA_ZAWODNIKA.AktualizujUbezpieczenie(3, SYSDATE - 10);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SUKCES (Zlapano blad): ' || SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('TEST LIMITU: Trener > 5 zawodnikow');
    BEGIN
        -- Dodajemy mu jeszcze 3 (ma juz 3, wiec przekroczy limit 5)
        OBSLUGA_ZAWODNIKA.DodajZawodnika('Test1', 'Test1', 'Polska', TO_DATE('2000-01-01', 'YYYY-MM-DD'), 2, TO_DATE('2026-12-31', 'YYYY-MM-DD'));
        OBSLUGA_ZAWODNIKA.DodajZawodnika('Test2', 'Test2', 'Polska', TO_DATE('2000-01-01', 'YYYY-MM-DD'), 2, TO_DATE('2026-12-31', 'YYYY-MM-DD'));
        OBSLUGA_ZAWODNIKA.DodajZawodnika('Test3', 'Test3', 'Polska', TO_DATE('2000-01-01', 'YYYY-MM-DD'), 2, TO_DATE('2026-12-31', 'YYYY-MM-DD'));
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SUKCES (Zlapano blad pakietu): ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('TEST TRIGGERA: Ponad 5 dyscyplin zawodnika');
    BEGIN
        FOR i IN 1..6 LOOP
            OBSLUGA_ZAWODNIKA.DodajDyscypline(3, Dyscyplina_typ(seq_dyscyplina_id.NEXTVAL, 'Dyscyplina ' || i));
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SUKCES (Zlapano blad): ' || SQLERRM);
    END;
END;
/


-- 3. KOLEKCJE, HISTORIA WYNIKOW I UPSERT

BEGIN
    DBMS_OUTPUT.PUT_LINE('TEST: Wystepy i Rekordy Osobiste ');
    
    -- Wystepy
    OBSLUGA_ZAWODNIKA.DodajWystep(3, Wystepy_typ(seq_wystep_id.NEXTVAL,'Mistrzostwa swiata', 'Warszawa','Sprint 100m', 1, TO_DATE('2025-01-01', 'YYYY-MM-DD'), 2025));
    OBSLUGA_ZAWODNIKA.DodajWystep(3, Wystepy_typ(seq_wystep_id.NEXTVAL,'Puchar Europy', 'Krakow','Rzut oszczepem', 2, TO_DATE('2025-02-01', 'YYYY-MM-DD'), 2025));
    
    -- Rekordy z roznych lat
    OBSLUGA_ZAWODNIKA.AktualizujPB(3, 'BIEG_100M', 11, 2021); 
    OBSLUGA_ZAWODNIKA.AktualizujPB(3, 'BIEG_100M', 10, 2022); 
    OBSLUGA_ZAWODNIKA.AktualizujPB(3, 'SKOK_W_DAL', 8, 2022); 
    OBSLUGA_ZAWODNIKA.AktualizujPB(3, 'BIEG_100M', 9, 2023);  
    OBSLUGA_ZAWODNIKA.AktualizujPB(3, 'METRY_KULA', 18, 2023);
    
    OBSLUGA_ZAWODNIKA.WyswietlWystepyZawodnika(3);
    OBSLUGA_ZAWODNIKA.WyswietlWynikiZawodnika(3);
END;
/


-- 4. TESTY SILNIKA HARMONOGRAMU (rozwiazanie konfliktow uczestnictwa i pojemnosci)

BEGIN
    TERMINARZ.dodaj_miejsce('BOISKO_1', 25);
    TERMINARZ.dodaj_miejsce('BASEN', 10);
    TERMINARZ.dodaj_miejsce('SALA MASAZYSTY', 2);
END;
/

DECLARE
    v_lista_wszyscy OSOBY_REF_TAB;
    v_lista_mala    OSOBY_REF_TAB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('TEST HARMONOGRAMU: Przepelnienie sali i konflikty');
    SELECT REF(o) BULK COLLECT INTO v_lista_wszyscy FROM Osoba_tab o WHERE Rola = 'zawodnik'; -- 3 osoby
    SELECT REF(o) BULK COLLECT INTO v_lista_mala FROM Osoba_tab o WHERE Osoba_id IN (3, 4); -- 2 osoby

    -- 1. Dodajemy masaz w sali dla 2 osob o 10:00 (Wtorek) - przechodzi
    TERMINARZ.DODAJ_AKTYWNOSC('MASAZ', TERMIN_TYP(10, 0, 2, 60), 0, v_lista_mala, 3);
    DBMS_OUTPUT.PUT_LINE('Dodano masaz (ID: 3) na godz 10:00. Sala zajeta: 2/2');

    -- 2. Proba przepelnienia sali masazysty
    BEGIN
        TERMINARZ.DODAJ_AKTYWNOSC('MASAZ_EKSTRA', TERMIN_TYP(10, 30, 2, 60), 0, v_lista_mala, 3);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SUKCES (Blokada przepelnienia): ' || SQLERRM);
    END;

    -- 3. Proba przypisania zajetego zawodnika (Zawodnik 3 jest na masazu 10:00-11:00)
    BEGIN
        -- Probujemy wyslac wszystkich (w tym zajetego ID 3) na basen o 10:30 (Wtorek)
        TERMINARZ.DODAJ_AKTYWNOSC('BASEN', TERMIN_TYP(10, 30, 2, 60), 0, v_lista_wszyscy, 2);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SUKCES (Blokada zajetego gracza): ' || SQLERRM);
    END;

    -- 4. Dodanie ogolnego treningu bez konfliktow (15:00 Sroda)
    TERMINARZ.DODAJ_AKTYWNOSC('TRENING OGOLNY', TERMIN_TYP(15, 0, 3, 120), 1, v_lista_wszyscy, 1);
END;
/


-- 5. TEST KORONNY: OBECNOSCI I MAGICZNY TRIGGER "WYTRENOWANIA"

DECLARE
    v_obecni OSOBY_REF_TAB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('TEST SYSTEMU RAPORTOW I TRIGGERA KONDYCJI');
    
    DBMS_OUTPUT.PUT_LINE('Kondycja przed raportem obecnosci:');
    WYSWIETLANIE.WYSWIETL_KONDYCJE_ZAWODNIKA(3);

    -- Reczna zmiana wagi przez trenera
    OBSLUGA_ZAWODNIKA.AktualizujKondycje(3, p_Masa => 73); 

    -- Tworzymy raport obecnosci. Zawodnik ID 3 uczestniczyl w treningu ogolnym (Aktywnosc 2)
    SELECT REF(o) BULK COLLECT INTO v_obecni FROM Osoba_tab o WHERE Osoba_id IN (3);

    TRENER.DODAJ_RAPORT(
        p_aktywnosc_id => 2, -- Trening ogolny
        p_lista_obecnych => v_obecni,
        p_uwagi => 'Jan Kowalski dal z siebie wszystko.'
    );

    DBMS_OUTPUT.PUT_LINE('Kondycja po raporcie obecnosci (trigger podniosl kondycje):');
    WYSWIETLANIE.WYSWIETL_KONDYCJE_ZAWODNIKA(3);
END;
/

-- 6. FINALNY RAPORT (WIDOK DLA UZYTKOWNIKA)

BEGIN
    DBMS_OUTPUT.PUT_LINE('PODSUMOWANIE DANYCH W SYSTEMIE');

    WYSWIETLANIE.POKAZ_WSZYSTKIE_AKTYWNOSCI;
    DBMS_OUTPUT.PUT_LINE(CHR(10));
    TRENER.WYSWIETL_OBECNOSCI_ZAWODNIKA(3);
    DBMS_OUTPUT.PUT_LINE(CHR(10));
    OBSLUGA_ZAWODNIKA.PobierzSzczegolyZawodnika(3);
    
    DBMS_OUTPUT.PUT_LINE('Aktualna liczba zawodnikow: ' || OBSLUGA_ZAWODNIKA.LiczbaAktywnychZawodnikow);
END;
/