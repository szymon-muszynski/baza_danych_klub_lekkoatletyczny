-- Specyfikacje/definicje pakietow 


CREATE OR REPLACE NONEDITIONABLE PACKAGE TERMINARZ AS 
    PROCEDURE CZYSZCZENIE_AKTYWNOSCI;

    PROCEDURE DODAJ_MIEJSCE (
        nazwa_miejsca IN VARCHAR2,
        max_osob IN NUMBER
    );
    
    PROCEDURE DODAJ_AKTYWNOSC (
        p_Typ IN VARCHAR2,
        p_TERMIN TERMIN,
        p_Okresowe IN NUMBER,
        p_Lista_Osob IN OSOBY_ID_TAB,
        p_Miejsce_ID IN NUMBER
    );

    FUNCTION ZAJETE_MIEJSCE (
        T1 TERMIN,
        P_MIEJSCE NUMBER,
        DODATKOWA_LICZBA_OSOB NUMBER
    ) RETURN BOOLEAN;

    FUNCTION ZAJETY_ZAWODNIK (
        T1 TERMIN,
        p_Lista_Osob IN OSOBY_ID_TAB
    ) RETURN BOOLEAN;

    PROCEDURE Usun_Miejsce (
        p_Miejsce_ID IN NUMBER
    );
    
    PROCEDURE Usun_Aktywnosc (
        p_Aktywnosc_ID IN NUMBER
    );
END TERMINARZ;
/

CREATE OR REPLACE NONEDITIONABLE PACKAGE TRENER AS 
    PROCEDURE DODAJ_RAPORT(
        p_aktywnosc_id   IN NUMBER,
        p_lista_obecnych   IN OSOBY_ID_TAB,
        UWAGI IN VARCHAR2
    );
    
    PROCEDURE USUN_RAPORT(
        P_RAPORT_ID IN NUMBER
    );

    PROCEDURE WYSWIETL_OBECNOSCI_ZAWODNIKA(
        P_ZAWODNIK_ID NUMBER
    );
END TRENER;
/

CREATE OR REPLACE NONEDITIONABLE PACKAGE WYSWIETLANIE AS 
    PROCEDURE WYSWIETL_AKTYWNOSCI_OSOBY (
        OSOBA_ID NUMBER,
        OKRESOWE NUMBER, 
        ODBYTE NUMBER,
        DZIEN NUMBER 
    );

    PROCEDURE WYSWIETL_DZIEN(DZIEN NUMBER);
    PROCEDURE POKAZ_WSZYTSKIE_AKTYWNOSCI;
    PROCEDURE WYSWIETL_LISTE(LISTA OSOBY_ID_TAB);
    PROCEDURE WYSWIETL_KONDYCJE_ZAWODNIKA(ZAWODNIK_ID NUMBER);
END WYSWIETLANIE;
/

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

    PROCEDURE ZmienStatusZawodnika(
        p_Osoba_id NUMBER,
        p_Status NUMBER
    );

    PROCEDURE DodajWystep(
        p_Osoba_id NUMBER,
        p_Wystep Wystepy_typ
    );

    PROCEDURE AktualizujPB(
        p_Osoba_id   NUMBER,
        p_Dyscyplina VARCHAR2,
        p_Wynik      NUMBER,
        p_Rok        NUMBER
    );

    PROCEDURE DodajDyscypline(
        p_Osoba_id NUMBER,
        p_Dyscyplina Dyscyplina_typ
    );

    PROCEDURE AktualizujUbezpieczenie(
        p_Osoba_id NUMBER,
        p_Koniec_ubezpieczenia DATE
    );
    
    FUNCTION CzyZawodnikIstnieje(p_OsobaId NUMBER) RETURN BOOLEAN;
    FUNCTION LiczbaAktywnychZawodnikow RETURN NUMBER;
    FUNCTION PobierzSzczegolyZawodnika(p_OsobaId NUMBER) RETURN VARCHAR2;
    FUNCTION WyswietlWystepyZawodnika(p_Osoba_id NUMBER) RETURN VARCHAR2;
    FUNCTION ZwrocPrzelozonego(p_Osoba_id NUMBER) RETURN VARCHAR2;
    FUNCTION WyswietlWynikiZawodnika(p_Osoba_id NUMBER) RETURN VARCHAR2;
    FUNCTION WyswietlZawodnikowPodTrenerem(p_Trener_id NUMBER) RETURN VARCHAR2;
END OBSLUGA_ZAWODNIKA;
/