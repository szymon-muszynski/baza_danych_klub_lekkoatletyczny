-- Specyfikacje/definicje pakietow 


CREATE OR REPLACE NONEDITIONABLE PACKAGE TERMINARZ AS 
    PROCEDURE ZAKONCZ_MINIONE_AKTYWNOSCI;

    PROCEDURE DODAJ_MIEJSCE (
        nazwa_miejsca IN VARCHAR2,
        max_osob IN NUMBER
    );
    
    PROCEDURE DODAJ_AKTYWNOSC (
        p_Typ IN VARCHAR2,
        p_TERMIN TERMIN_TYP,
        p_Okresowe IN NUMBER,
        p_Lista_Osob IN OSOBY_REF_TAB, 
        p_Miejsce_ID IN NUMBER
    );

    FUNCTION ZAJETE_MIEJSCE (
        T1 TERMIN_TYP,
        p_Miejsce_ID NUMBER,
        DODATKOWA_LICZBA_OSOB NUMBER
    ) RETURN BOOLEAN;

    FUNCTION ZAJETY_ZAWODNIK (
        T1 TERMIN_TYP,
        p_Lista_Osob IN OSOBY_REF_TAB
    ) RETURN BOOLEAN;

    PROCEDURE Usun_Miejsce (
        p_Miejsce_ID IN NUMBER
    );
    
    PROCEDURE Usun_Aktywnosc (
        p_Aktywnosc_ID IN NUMBER
    );
END TERMINARZ;
/
---------------------------------------------------
CREATE OR REPLACE NONEDITIONABLE PACKAGE TRENER AS 
    PROCEDURE DODAJ_RAPORT(
        p_aktywnosc_id   IN NUMBER,
        p_lista_obecnych IN OSOBY_REF_TAB,
        p_uwagi          IN VARCHAR2
    );

    PROCEDURE USUN_RAPORT(
        P_RAPORT_ID IN NUMBER
    );

    PROCEDURE WYSWIETL_OBECNOSCI_ZAWODNIKA(
        P_ZAWODNIK_ID NUMBER
    );
    
END TRENER;
/
-----------------------------------------------------
CREATE OR REPLACE NONEDITIONABLE PACKAGE WYSWIETLANIE AS 
    PROCEDURE WYSWIETL_AKTYWNOSCI_OSOBY (
        OSOBA_ID NUMBER,
        OKRESOWE NUMBER, 
        ODBYTE NUMBER,
        DZIEN NUMBER 
    );

    PROCEDURE POKAZ_WSZYSTKIE_AKTYWNOSCI;
    
    PROCEDURE WYSWIETL_ZAWODNIKOW_DLA_AKTYWNOSCI(P_AKTYWNOSC_ID NUMBER);
    
    PROCEDURE WYSWIETL_KONDYCJE_ZAWODNIKA(ZAWODNIK_ID NUMBER);
    
    PROCEDURE WYSWIETL_WSZYSTKICH_ZAWODNIKOW;
END WYSWIETLANIE;
/
-------------------------------------------------------
CREATE OR REPLACE PACKAGE OBSLUGA_ZAWODNIKA AS
    PROCEDURE DodajZawodnika(
        p_Imie VARCHAR2,
        p_Nazwisko VARCHAR2,
        p_Kraj_pochodzenia VARCHAR2,
        p_Data_urodzenia DATE,
        p_Przydzielony_trener NUMBER,
        p_Koniec_ubezpieczenia DATE
    );

    PROCEDURE UsunZawodnika(p_Osoba_id NUMBER);

    PROCEDURE AktualizujDaneZawodnika(
        p_Osoba_id NUMBER,
        p_Imie VARCHAR2 := NULL,
        p_Nazwisko VARCHAR2 := NULL,
        p_Kraj_pochodzenia VARCHAR2 := NULL,
        p_Data_urodzenia DATE := NULL,
        p_Przydzielony_trener NUMBER := NULL
    );

    PROCEDURE AktualizujKondycje(
        p_Osoba_id NUMBER,
        p_Kondycja NUMBER := NULL,
        p_Masa NUMBER := NULL,
        p_Wzrost NUMBER := NULL
    );

    PROCEDURE ZmienStatusZawodnika(p_Osoba_id NUMBER, p_Status NUMBER);
    PROCEDURE AktualizujUbezpieczenie(p_Osoba_id NUMBER, p_Koniec_ubezpieczenia DATE);

    PROCEDURE DodajWystep(p_Osoba_id NUMBER, p_Wystep Wystepy_typ);
    PROCEDURE DodajDyscypline(p_Osoba_id NUMBER,p_Dyscyplina Dyscyplina_typ);
    PROCEDURE AktualizujPB(p_Osoba_id NUMBER, p_Dyscyplina VARCHAR2,p_Wynik NUMBER, p_Rok NUMBER);

    FUNCTION CzyZawodnikIstnieje(p_OsobaId NUMBER) RETURN BOOLEAN;
    FUNCTION LiczbaAktywnychZawodnikow RETURN NUMBER;
    FUNCTION ZwrocPrzelozonego(p_Osoba_id NUMBER) RETURN VARCHAR2;
    
    PROCEDURE PobierzSzczegolyZawodnika(p_OsobaId NUMBER);
    PROCEDURE WyswietlWystepyZawodnika(p_Osoba_id NUMBER);
    PROCEDURE WyswietlWynikiZawodnika(p_Osoba_id NUMBER);
    PROCEDURE WyswietlZawodnikowPodTrenerem(p_Trener_id NUMBER);
END OBSLUGA_ZAWODNIKA;
/