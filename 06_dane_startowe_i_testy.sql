-- Skrypty wprowadzajace dane poczatkowe oraz testowe wywolania


INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Dominik', 'Kowalczyk', 'Polska', TO_DATE('1980-05-15', 'YYYY-MM-DD'), 'Boss', NULL, NULL, NULL, NULL, NULL, 1, NULL);

INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Dominik', 'Kowalczyk', 'Polska', TO_DATE('1979-09-25', 'YYYY-MM-DD'), 'Trener', 3, NULL, NULL, NULL, NULL, 1, NULL);

INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Piotr', 'Nowak', 'Polska', TO_DATE('1975-08-20', 'YYYY-MM-DD'), 'Trener', 3, NULL, NULL, NULL, NULL, 1, NULL);

INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Anna', 'Zielinska', 'Polska', TO_DATE('1982-02-10', 'YYYY-MM-DD'), 'Trener', 3, NULL, NULL, NULL, NULL, 1, NULL);

BEGIN
    OBSLUGA_ZAWODNIKA.DodajZawodnika(
        p_Imie => 'Jan',
        p_Nazwisko => 'Kowalski',
        p_Kraj_pochodzenia => 'Polska',
        p_Data_urodzenia => TO_DATE('1990-02-15', 'YYYY-MM-DD'),
        p_Przydzielony_trener => 4,
        p_Koniec_ubezpieczenia => TO_DATE('2025-12-31', 'YYYY-MM-DD')
    );
END;
/

BEGIN
    OBSLUGA_ZAWODNIKA.DodajZawodnika(
        p_Imie => 'Anna',
        p_Nazwisko => 'Nowak',
        p_Kraj_pochodzenia => 'Polska',
        p_Data_urodzenia => TO_DATE('1995-03-20', 'YYYY-MM-DD'),
        p_Przydzielony_trener => 5,
        p_Koniec_ubezpieczenia => TO_DATE('2025-12-31', 'YYYY-MM-DD')
    );

    OBSLUGA_ZAWODNIKA.DodajZawodnika(
        p_Imie => 'Piotr',
        p_Nazwisko => 'Wisniewski',
        p_Kraj_pochodzenia => 'Polska',
        p_Data_urodzenia => TO_DATE('1992-07-10', 'YYYY-MM-DD'),
        p_Przydzielony_trener => 6,
        p_Koniec_ubezpieczenia => TO_DATE('2025-12-31', 'YYYY-MM-DD')
    );
    
    COMMIT;
END;
/

SET SERVEROUTPUT ON;

DECLARE
    v_Output VARCHAR2(4000);
BEGIN
    v_Output := OBSLUGA_ZAWODNIKA.WyswietlWystepyZawodnika(p_Osoba_id => 8);
END;
/

BEGIN
    OBSLUGA_ZAWODNIKA.DodajWystep(
        p_Osoba_id => 8,
        p_Wystep => Wystepy_typ(seq_wystep_id.NEXTVAL,'Mistrzostwa swiata', 'Warszawa','Sprint 100m', 1, TO_DATE('2025-01-01', 'YYYY-MM-DD'), 1, 2025)
    );
    
    OBSLUGA_ZAWODNIKA.DodajWystep(
        p_Osoba_id => 8,
        p_Wystep => Wystepy_typ(seq_wystep_id.NEXTVAL,'Puchar Europy', 'Krakow','Rzut oszczepem', 2, TO_DATE('2025-02-01', 'YYYY-MM-DD'), 1, 2025)
    );

    OBSLUGA_ZAWODNIKA.DodajWystep(
        p_Osoba_id => 8,
        p_Wystep => Wystepy_typ(seq_wystep_id.NEXTVAL,'Mistrzostwa Polski', 'Gdansk','Rzut mlotem', 3, TO_DATE('2025-03-01', 'YYYY-MM-DD'), 1, 2025)
    );
    
    COMMIT;
END;
/

BEGIN
    OBSLUGA_ZAWODNIKA.AktualizujPB(p_Osoba_id => 8, p_Dyscyplina => 'Bieg_100m', p_Wynik => 10.25, p_Rok => 2023);
    OBSLUGA_ZAWODNIKA.AktualizujPB(p_Osoba_id => 8, p_Dyscyplina => 'Bieg_110m_plotki', p_Wynik => 11.10, p_Rok => 2022);
    OBSLUGA_ZAWODNIKA.AktualizujPB(p_Osoba_id => 8, p_Dyscyplina => 'Bieg_100m', p_Wynik => 9.80, p_Rok => 2021);
    OBSLUGA_ZAWODNIKA.AktualizujPB(p_Osoba_id => 8, p_Dyscyplina => 'Bieg_100m', p_Wynik => 9.80, p_Rok => 2021);
    OBSLUGA_ZAWODNIKA.AktualizujPB(p_Osoba_id => 8, p_Dyscyplina => 'Bieg_400m', p_Wynik => 47.80, p_Rok => 2021);
    OBSLUGA_ZAWODNIKA.AktualizujPB(p_Osoba_id => 8, p_Dyscyplina => 'Metry_oszczep', p_Wynik => 95.80, p_Rok => 2021);
    OBSLUGA_ZAWODNIKA.AktualizujPB(p_Osoba_id => 8, p_Dyscyplina => 'Metry_mlot', p_Wynik => 25.80, p_Rok => 2021);
    COMMIT;
END;
/

DECLARE
    v_Output VARCHAR2(4000);
BEGIN
    v_Output := OBSLUGA_ZAWODNIKA.WyswietlWynikiZawodnika(p_Osoba_id => 8);
END;
/

BEGIN
    OBSLUGA_ZAWODNIKA.ZmienStatusZawodnika(p_Osoba_id => 1, p_Status => 1);
    OBSLUGA_ZAWODNIKA.ZmienStatusZawodnika(p_Osoba_id => 2, p_Status => 1);
    OBSLUGA_ZAWODNIKA.ZmienStatusZawodnika(p_Osoba_id => 3, p_Status => 0);
    COMMIT;
END;
/

DECLARE
    v_Dyscyplina Dyscyplina_typ := Dyscyplina_typ(seq_dyscyplina_id.NEXTVAL, 'Bieg 100m');
BEGIN
    OBSLUGA_ZAWODNIKA.DodajDyscypline(p_Osoba_id => 1, p_Dyscyplina => v_Dyscyplina);
    COMMIT;
END;
/

BEGIN
    OBSLUGA_ZAWODNIKA.AktualizujUbezpieczenie(
        p_Osoba_id => 1,
        p_Koniec_ubezpieczenia => TO_DATE('2026-12-31', 'YYYY-MM-DD')
    );
    COMMIT;
END;
/

DECLARE
    v_Exists BOOLEAN;
BEGIN
    v_Exists := OBSLUGA_ZAWODNIKA.CzyZawodnikIstnieje(p_OsobaId => 80);
    DBMS_OUTPUT.PUT_LINE('Czy zawodnik istnieje: ' || CASE WHEN v_Exists THEN 'Tak' ELSE 'Nie' END);
END;
/

DECLARE
    v_Count NUMBER;
BEGIN
    v_Count := OBSLUGA_ZAWODNIKA.LiczbaAktywnychZawodnikow;
    DBMS_OUTPUT.PUT_LINE('Liczba aktywnych zawodnikow: ' || v_Count);
END;
/

DECLARE
    v_Details VARCHAR2(4000);
BEGIN
    v_Details := OBSLUGA_ZAWODNIKA.PobierzSzczegolyZawodnika(p_OsobaId => 8);
END;
/

DECLARE
    v_Przydzielony_trener VARCHAR2(50);
BEGIN
    v_Przydzielony_trener := OBSLUGA_ZAWODNIKA.ZwrocPrzelozonego(p_Osoba_id => 8);
    DBMS_OUTPUT.PUT_LINE('Przelozony zawodnika: ' || v_Przydzielony_trener);
END;
/

DECLARE
    v_Output VARCHAR2(4000);
BEGIN
    v_Output := OBSLUGA_ZAWODNIKA.WyswietlZawodnikowPodTrenerem(p_Trener_id => 101);
    DBMS_OUTPUT.PUT_LINE(v_Output);
END;
/

BEGIN
    TERMINARZ.dodaj_miejsce('BOISKO_2', 25);
    TERMINARZ.dodaj_miejsce('BOISKO_1', 25);
    TERMINARZ.dodaj_miejsce('BASEN', 10);
    TERMINARZ.dodaj_miejsce('BIEZNIA NA POWIETRZU', 5);
    TERMINARZ.dodaj_miejsce('SALA MASAZYSTY', 2);
END;
/

BEGIN
    TERMINARZ.DODAJ_AKTYWNOSC('MASAZ REGENERACYJNY', TERMIN(10,15,5,2),1,OSOBY_ID_TAB(1,3),5);
END;
/

BEGIN
    TERMINARZ.DODAJ_AKTYWNOSC('TRENING OGOLNY', TERMIN(21,15,3,2),1,OSOBY_ID_TAB(1,2,3,4,5),3);
    TERMINARZ.DODAJ_AKTYWNOSC('TRENING OGOLNY', TERMIN(21,15,1,5),0,OSOBY_ID_TAB(1,2),1);
    TERMINARZ.DODAJ_AKTYWNOSC('TRENING NA BOISKU', TERMIN(8,15,3,2),1,OSOBY_ID_TAB(1,2,3,4,5),2);
END;
/

BEGIN
    TERMINARZ.DODAJ_AKTYWNOSC('TRENING SILOWY', TERMIN(14,15,3,1),0,OSOBY_ID_TAB(2),4);
END;
/

BEGIN
    WYSWIETLANIE.POKAZ_WSZYTSKIE_AKTYWNOSCI;
END;
/

BEGIN
    trener.wyswietl_obecnosci_zawodnika(2);
END;
/

BEGIN
    WYSWIETLANIE.WYSWIETL_KONDYCJE_ZAWODNIKA(3);
END;
/