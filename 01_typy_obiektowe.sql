-- Deklaracje typow podstawowych i z³o¿onych

CREATE OR REPLACE TYPE OSOBY_ID_TAB AS TABLE OF NUMBER(4,0);
/

CREATE OR REPLACE TYPE MIEJSCE_TYP AS OBJECT (
    MIEJSCE_ID NUMBER,
    Nazwa VARCHAR2(50),
    Max_osob NUMBER
);
/

CREATE OR REPLACE TYPE TERMIN AS OBJECT (
    GODZINA NUMBER(10, 0),
    MINUTA NUMBER(10, 0),
    DZIEN_TYGODNIA NUMBER(10, 0),
    CZAS_TRWANIA NUMBER(10, 0),
    CONSTRUCTOR FUNCTION TERMIN(
        GODZINA IN NUMBER,
        MINUTA IN NUMBER,
        DZIEN_TYGODNIA IN NUMBER,
        CZAS_TRWANIA IN NUMBER
    ) RETURN SELF AS RESULT,
    MEMBER FUNCTION czas_formatowany RETURN VARCHAR2,
    MEMBER FUNCTION nazwa_dnia_tyg RETURN VARCHAR2,
    MEMBER FUNCTION CZY_KONFLIKT(T TERMIN) RETURN NUMBER
);
/

CREATE OR REPLACE TYPE BODY TERMIN AS
    CONSTRUCTOR FUNCTION TERMIN(
        GODZINA IN NUMBER,
        MINUTA IN NUMBER,
        DZIEN_TYGODNIA IN NUMBER,
        CZAS_TRWANIA IN NUMBER
    ) RETURN SELF AS RESULT IS
    BEGIN
        IF GODZINA < 0 OR GODZINA >= 24 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Godzina musi byc w przedziale 0-23.');
        END IF;

        IF MINUTA < 0 OR MINUTA >= 60 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Minuta musi byc w przedziale 0-59.');
        END IF;

        IF DZIEN_TYGODNIA < 1 OR DZIEN_TYGODNIA > 7 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Dzien tygodnia musi byc w przedziale 1-7.');
        END IF;

        IF CZAS_TRWANIA <= 0 OR GODZINA + CEIL(CZAS_TRWANIA / 60) >= 24 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Czas trwania jest niepoprawny lub przekracza dobe.');
        END IF;

        SELF.GODZINA := GODZINA;
        SELF.MINUTA := MINUTA;
        SELF.DZIEN_TYGODNIA := DZIEN_TYGODNIA;
        SELF.CZAS_TRWANIA := CZAS_TRWANIA;

        RETURN;
    END TERMIN;

    MEMBER FUNCTION nazwa_dnia_tyg RETURN VARCHAR2 IS
        NAZWA_DNIA VARCHAR2(20);
    BEGIN
        CASE DZIEN_TYGODNIA
            WHEN 1 THEN NAZWA_DNIA := 'Poniedzialek';
            WHEN 2 THEN NAZWA_DNIA := 'Wtorek';
            WHEN 3 THEN NAZWA_DNIA := 'Sroda';
            WHEN 4 THEN NAZWA_DNIA := 'Czwartek';
            WHEN 5 THEN NAZWA_DNIA := 'Piatek';
            WHEN 6 THEN NAZWA_DNIA := 'Sobota';
            WHEN 7 THEN NAZWA_DNIA := 'Niedziela';
            ELSE
                RAISE_APPLICATION_ERROR(-20001, 'Nieprawidlowy numer dnia tygodnia: ' || DZIEN_TYGODNIA);
        END CASE;

        RETURN NAZWA_DNIA;
    END;

    MEMBER FUNCTION czas_formatowany RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(GODZINA, 'FM00') || ':' || TO_CHAR(MINUTA, 'FM00') || ', ' || nazwa_dnia_tyg();
    END;
    
    MEMBER FUNCTION CZY_KONFLIKT(T TERMIN) RETURN NUMBER IS
    CZAS1 NUMBER;
    CZAS2 NUMBER;
    BEGIN
    IF DZIEN_TYGODNIA != T.DZIEN_TYGODNIA THEN
        RETURN 0;
    END IF;
    CZAS1 := GODZINA + MINUTA/60;
    CZAS2 := T.GODZINA + T.MINUTA/60;
    IF CZAS1 <= CZAS2 AND CZAS2<= CZAS1+CZAS_TRWANIA THEN
        RETURN 1;
    END IF;
    IF CZAS2 <= CZAS1 AND CZAS1<= CZAS2+T.CZAS_TRWANIA THEN
        RETURN 1;
    END IF;
    RETURN 0;
    END;
END;
/

CREATE OR REPLACE TYPE Dyscyplina_typ AS OBJECT (
    Dyscyp_id NUMBER,
    Dysc_name VARCHAR2(100)
);
/

CREATE OR REPLACE TYPE DYSCYPLINA_TAB AS TABLE OF Dyscyplina_typ;
/

CREATE OR REPLACE TYPE PB_Wynik_typ AS OBJECT (
    Bieg_100m NUMBER(5,3),
    Bieg_110m_plotki NUMBER(5,3),
    Bieg_400m NUMBER(5,3),
    Bieg_1500m NUMBER(7,3),
    Skok_wzwyz NUMBER(5,3),
    Skok_tyczka NUMBER(5,3),
    Skok_w_dal NUMBER(5,3),
    Metry_kula NUMBER(5,3),
    Metry_oszczep NUMBER(5,3),
    Metry_dysk NUMBER(5,3),
    Metry_mlot NUMBER(5,3),
    Rok NUMBER
);
/

CREATE OR REPLACE TYPE PB_Wynik_tab AS TABLE OF PB_Wynik_typ;
/

CREATE OR REPLACE TYPE Wystepy_typ AS OBJECT (
    ID_Wystepu NUMBER,
    Nazwa VARCHAR2(50),
    Miejscowosc VARCHAR2(50),
    Konkurencja VARCHAR(50),
    Wynik_miejsce NUMBER,
    Data DATE,
    Odbyte NUMBER(1),
    Rok NUMBER
);
/

CREATE OR REPLACE TYPE Wystepy_tab AS TABLE OF Wystepy_typ;
/

CREATE OR REPLACE TYPE wytrenowanie_typ AS OBJECT(
    kondycja NUMBER,
    masa NUMBER,
    wzrost NUMBER,
    data_aktualizacji DATE,
    CONSTRUCTOR FUNCTION wytrenowanie_typ(
        kondycja NUMBER,
        masa NUMBER,
        wzrost NUMBER,
        data_aktualizacji DATE
    ) RETURN SELF AS RESULT,
    MEMBER PROCEDURE update_kondycja
);
/

CREATE OR REPLACE TYPE BODY wytrenowanie_typ AS
    CONSTRUCTOR FUNCTION wytrenowanie_typ(
        kondycja IN NUMBER,
        masa IN NUMBER,
        wzrost IN NUMBER,
        data_aktualizacji IN DATE
    ) RETURN SELF AS RESULT IS
    BEGIN
        SELF.kondycja := kondycja;
        SELF.masa := masa;
        SELF.wzrost := wzrost;
        SELF.data_aktualizacji := data_aktualizacji;
        RETURN;
    END wytrenowanie_typ;
    
    MEMBER PROCEDURE update_kondycja IS
    BEGIN
        IF SELF.data_aktualizacji >= SYSDATE - 5 THEN
            SELF.kondycja := SELF.kondycja + 10;
        ELSE
            SELF.kondycja := (SELF.kondycja / 2) + 1;
        END IF;
        SELF.data_aktualizacji := SYSDATE;
    END update_kondycja;
END;
/

CREATE OR REPLACE TYPE Osoba_typ FORCE AS OBJECT (
    Osoba_id NUMBER,
    Imie VARCHAR2(50),
    Nazwisko VARCHAR2(50),
    Kraj_pochodzenia VARCHAR2(50),
    Data_urodzenia DATE,
    Rola VARCHAR2(50),
    Przelozony NUMBER,
    wytrenowanie wytrenowanie_typ,
    Wystepy Wystepy_tab,
    Dyscypliny DYSCYPLINA_TAB,
    Wyniki_dyscyplin PB_Wynik_tab, 
    Active NUMBER(1),
    Koniec_ubezpieczenia DATE,
    MEMBER FUNCTION PelneImie RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY Osoba_typ AS
    MEMBER FUNCTION PelneImie RETURN VARCHAR2 IS
    BEGIN
        RETURN Imie || ' ' || Nazwisko;
    END;
END;
/

CREATE OR REPLACE TYPE AKTYWNOSCI_TYP AS OBJECT (
    AKTYWNOSC_ID NUMBER,
    TYP varchar2(50), 
    T TERMIN,
    OKRESOWE NUMBER(1,0),
    Lista_osob OSOBY_ID_tab, 
    MIEJSCE REF MIEJSCE_TYP, 
    odbyte number(1,0)
);
/

CREATE OR REPLACE TYPE RAPORT_OBECNOSCI AS OBJECT (
    RAPORT_ID NUMBER,
    AKTYWNOSC_ID NUMBER,
    TYP VARCHAR2(100),
    LISTA_ZAPISANYCH OSOBY_ID_tab,
    LISTA_OBECNYCH OSOBY_ID_tab,
    DATA_UTWORZENIA DATE,
    UWAGI VARCHAR2(200)
);
/