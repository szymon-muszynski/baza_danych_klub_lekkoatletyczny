CREATE OR REPLACE TYPE MIEJSCE_TYP FORCE AS OBJECT (
    MIEJSCE_ID NUMBER,
    Nazwa VARCHAR2(50),
    Max_osob NUMBER
);
CREATE SEQUENCE MIEJSCA_TAB_SEQ START WITH 1 INCREMENT BY 1;

CREATE TABLE MIEJSCA_TAB OF MIEJSCE_TYP (
    PRIMARY KEY (MIEJSCE_ID)
);

CREATE TYPE OSOBY_ID_TAB AS TABLE OF NUMBER(4,0);

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

        -- Przypisanie wartosci
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

--###############AKTYWNOSC
CREATE OR REPLACE TYPE AKTYWNOSCI_TYP AS OBJECT (
    AKTYWNOSC_ID NUMBER,
    TYP varchar2(50), --slownie, zeby bylo jasniej
    T TERMIN,
    OKRESOWE NUMBER(1,0),
    Lista_osob OSOBY_ID_tab, --relacja jeden do jeden z tablica osoby
    MIEJSCE REF MIEJSCE_TYP, --relacja jeden do jeden z miejsca_tab
    odbyte number(1,0)
);

CREATE TABLE AKTYWNOSCI_TAB OF AKTYWNOSCI_TYP (
    PRIMARY KEY (AKTYWNOSC_ID)
)
NESTED TABLE Lista_osob STORE AS Lista_osob_s;
CREATE SEQUENCE AKTYWNOSCI_TAB_SEQ START WITH 1 INCREMENT BY 1;

--##################### raport
CREATE OR REPLACE TYPE RAPORT_OBECNOSCI AS OBJECT (
    RAPORT_ID NUMBER,
    AKTYWNOSC_ID NUMBER,
    TYP VARCHAR2(100),
    LISTA_ZAPISANYCH OSOBY_ID_tab,
    LISTA_OBECNYCH OSOBY_ID_tab,
    DATA_UTWORZENIA DATE,
    UWAGI VARCHAR2(200)
);
CREATE SEQUENCE RAPORT_TAB_SEQ START WITH 1 INCREMENT BY 1;

CREATE TABLE RAPORTY_TAB OF RAPORT_OBECNOSCI (
    PRIMARY KEY (RAPORT_ID)
)
NESTED TABLE LISTA_ZAPISANYCH STORE AS LISTA_ZAP
NESTED TABLE LISTA_OBECNYCH STORE AS LISTA_OB;

--###################################

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

            -- Pobranie obiektu wytrenowanie
            SELECT wytrenowanie INTO v_wytrenowanie
            FROM osoba_tab
            WHERE osoba_id = v_osoba_id;

            -- Wywolanie metody czlonkowskiej
            v_wytrenowanie.update_kondycja();

            -- Aktualizacja tabeli osoba_tab
            UPDATE osoba_tab
            SET wytrenowanie = v_wytrenowanie
            WHERE osoba_id = v_osoba_id;
        END LOOP;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error updating kondycja: ' || SQLERRM);
END update_kondycja_after_insert;

create or replace NONEDITIONABLE PACKAGE TERMINARZ AS 

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
    p_Miejsce_ID IN NUMBER -- ID miejsca
);

FUNCTION ZAJETE_MIEJSCE (
T1 TERMIN,
P_MIEJSCE NUMBER,
DODATKOWA_LICZBA_OSOB NUMBER
)RETURN BOOLEAN;

FUNCTION ZAJETY_ZAWODNIK (
    T1 TERMIN,
    p_Lista_Osob IN OSOBY_ID_TAB
)RETURN BOOLEAN;

PROCEDURE Usun_Miejsce (
    p_Miejsce_ID IN NUMBER
);
 PROCEDURE Usun_Aktywnosc (
    p_Aktywnosc_ID IN NUMBER
) ;


END TERMINARZ;

create or replace NONEDITIONABLE PACKAGE BODY TERMINARZ AS

PROCEDURE CZYSZCZENIE_AKTYWNOSCI AS
    GODZINA   NUMBER; 
    MINUTA    NUMBER; 
    DZIEN_TYG NUMBER; -- Zmienna na dzien tygodnia (poniedzialek=1, niedziela=7)
    CZAS1 NUMBER;
BEGIN
    GODZINA := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24'));
    MINUTA  := TO_NUMBER(TO_CHAR(SYSDATE, 'MI')); 
    CZAS1 := GODZINA + MINUTA / 60;
   DZIEN_TYG := TO_NUMBER(TO_CHAR(SYSDATE, 'D')) - 1;
    IF DZIEN_TYG = 0 THEN
     DZIEN_TYG := 7; 
    END IF;
    UPDATE aktywnosci_tab A
    SET A.ODBYTE = 1
    WHERE A.T.DZIEN_TYGODNIA = DZIEN_TYG AND A.T.GODZINA+A.T.MINUTA/60 > CZAS1 AND A.OKRESOWE = 0 AND A.ODBYTE = 0;
END CZYSZCZENIE_AKTYWNOSCI;


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
    
    SELECT MIEJSCA_TAB_SEQ.NEXTVAL INTO v_Miejsce_ID FROM DUAL;
    
    INSERT INTO MIEJSCA_TAB VALUES (
        MIEJSCE_TYP(
            v_Miejsce_ID, 
            Nazwa_MIEJSCA,
            Max_osob
        )
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
    v_Count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_Count
    FROM MIEJSCA_TAB
    WHERE MIEJSCE_ID = p_Miejsce_ID;

    IF v_Count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Miejsce o podanym ID nie istnieje.');
    ELSE

        DELETE FROM MIEJSCA_TAB
        WHERE MIEJSCE_ID = p_Miejsce_ID;

        COMMIT;
    END IF;
END Usun_Miejsce;


PROCEDURE Dodaj_Aktywnosc (
    p_Typ IN VARCHAR2,
    P_TERMIN TERMIN,
    p_Okresowe IN NUMBER,
    p_Lista_Osob IN OSOBY_ID_TAB,
    p_Miejsce_ID IN NUMBER
) AS
    v_Miejsce REF MIEJSCE_TYP;
    v_AKTYWNOSC_ID NUMBER;
BEGIN
    SELECT REF(m)
    INTO v_Miejsce
    FROM MIEJSCA_TAB m
    WHERE m.MIEJSCE_ID = p_Miejsce_ID;

     IF ZAJETE_MIEJSCE(P_TERMIN, P_MIEJSCE_ID,P_LISTA_OSOB.COUNT)=TRUE THEN
       RAISE_APPLICATION_ERROR(-20003, 'NA OBIEKCIE O TEJ GODZINIE I TYM DNIU BRAKUJE MIEJSC!');

     END IF;
     
     IF ZAJETY_ZAWODNIK(P_TERMIN, P_LISTA_OSOB) = TRUE THEN
        RAISE_APPLICATION_ERROR(-20005, 'ZAWODNICY MAJA JUZ W TYM CZASIE INNE ZAJECIA');
     END IF;
    IF (P_OKRESOWE!=0 AND P_OKRESOWE!=1) OR p_Lista_Osob.COUNT <1  THEN
        RAISE_APPLICATION_ERROR(-20004, 'BLEDNE PARAMETRY WEJSCIOWE');
    END IF;
    TERMINARZ.CZYSZCZENIE_AKTYWNOSCI;
    SELECT AKTYWNOSCI_TAB_SEQ.NEXTVAL INTO v_AKTYWNOSC_ID FROM DUAL;
    INSERT INTO AKTYWNOSCI_TAB VALUES (
        AKTYWNOSCI_TYP(
            V_AKTYWNOSC_ID,
            p_Typ,
            P_TERMIN,
            p_Okresowe,
            p_Lista_Osob,
            v_Miejsce,
            0
        )
    );


    COMMIT;
END Dodaj_Aktywnosc;


FUNCTION ZAJETE_MIEJSCE (
    T1 TERMIN,
    P_MIEJSCE number,
    DODATKOWA_LICZBA_OSOB NUMBER
) RETURN BOOLEAN AS
    CAPA NUMBER :=0;
    PEOPLE NUMBER :=0;
    T NUMBER;
BEGIN
    FOR akt IN (
        SELECT Lista_osob
        FROM AKTYWNOSCI_TAB A
        WHERE A.odbyte = 0 AND DEREF(A.MIEJSCE).MIEJSCE_ID = P_MIEJSCE AND T1.CZY_KONFLIKT(A.T) = 1
    ) LOOP
        IF akt.Lista_osob IS NOT NULL THEN
    
            SELECT COUNT(*) INTO PEOPLE
            FROM TABLE(akt.Lista_osob);
            T := T + PEOPLE;
        END IF;
    END LOOP;
      
    SELECT MAX_OSOB INTO CAPA FROM MIEJSCA_TAB WHERE MIEJSCE_ID = P_MIEJSCE;
      
      IF CAPA >= PEOPLE+DODATKOWA_LICZBA_OSOB THEN
        RETURN FALSE;
      END IF;
      RETURN TRUE;
END ZAJETE_MIEJSCE;

FUNCTION ZAJETY_ZAWODNIK ( 
    T1 TERMIN,
    p_Lista_Osob IN OSOBY_ID_TAB
) RETURN BOOLEAN AS
    TEMP_LISTA OSOBY_ID_TAB;
BEGIN

    FOR r IN (
        SELECT Lista_osob
        FROM AKTYWNOSCI_TAB A
        WHERE T1.CZY_KONFLIKT(A.T)=1
    ) LOOP
        TEMP_LISTA := r.Lista_osob;


        FOR i IN 1 .. p_Lista_Osob.COUNT LOOP
            IF p_Lista_Osob(i) MEMBER OF TEMP_LISTA THEN
                DBMS_OUTPUT.PUT_LINE('Zawodnik KTORY JEST ZAJETY MA ID: ' || p_Lista_Osob(i));
                RETURN TRUE; 
            END IF;
        END LOOP;
    END LOOP;

    RETURN FALSE; 
END ZAJETY_ZAWODNIK;

PROCEDURE Usun_Aktywnosc (
    p_Aktywnosc_ID IN NUMBER
) AS
    v_Count NUMBER; 
BEGIN
    SELECT COUNT(*)
    INTO v_Count
    FROM AKTYWNOSCI_TAB
    WHERE AKTYWNOSC_ID = p_Aktywnosc_ID;

    IF v_Count = 0 THEN
 
        RAISE_APPLICATION_ERROR(-20002, 'Aktywnosc o podanym ID nie istnieje.');
    ELSE
 
        DELETE FROM AKTYWNOSCI_TAB
        WHERE AKTYWNOSC_ID = p_Aktywnosc_ID;

        COMMIT;
    END IF;
END Usun_Aktywnosc;
END TERMINARZ;

create or replace NONEDITIONABLE PACKAGE TRENER AS 

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


create or replace NONEDITIONABLE PACKAGE BODY TRENER AS

  PROCEDURE DODAJ_RAPORT(
    p_aktywnosc_id   IN NUMBER,
    p_lista_obecnych   IN OSOBY_ID_TAB,
    UWAGI IN VARCHAR2
) AS
    NEW_RAPORT RAPORT_OBECNOSCI;
    RAPORT_COUNT NUMBER;
    AKT_TYP VARCHAR2(200);
    AKT_LISTA OSOBY_ID_TAB;
    RAP_ID NUMBER;
    RAP_DATA DATE;
    
BEGIN

    SELECT COUNT(*) INTO RAPORT_COUNT
    FROM AKTYWNOSCI_TAB
    WHERE AKTYWNOSC_ID = P_AKTYWNOSC_ID;
    
    IF RAPORT_COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Aktywnosc o podanym ID nie istnieje.');
    END IF;

   
    IF  P_LISTA_OBECNYCH IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Lista zapisanych i obecnych osob nie moze byc NULL.');
    END IF;

    SELECT A.LISTA_OSOB,A.TYP INTO AKT_LISTA, AKT_TYP FROM AKTYWNOSCI_TAB A
    WHERE A.AKTYWNOSC_ID = P_AKTYWNOSC_ID;

    NEW_RAPORT := RAPORT_OBECNOSCI(
        RAPORT_TAB_SEQ.NEXTVAL, 
        P_AKTYWNOSC_ID,
        AKT_TYP,
        AKT_LISTA,
        P_LISTA_OBECNYCH,
        SYSDATE, 
        uwagi
    );

 
    INSERT INTO RAPORTY_TAB VALUES NEW_RAPORT;
    
    DBMS_OUTPUT.PUT_LINE('Dodano nowy raport z ID: ' || NEW_RAPORT.RAPORT_ID);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Blad podczas dodawania raportu: ' || SQLERRM);
        ROLLBACK;
END DODAJ_RAPORT;



  PROCEDURE USUN_RAPORT(
    P_RAPORT_ID IN NUMBER
) AS
    RAPORT_COUNT NUMBER;
BEGIN

    SELECT COUNT(*) INTO RAPORT_COUNT
    FROM RAPORTY_TAB
    WHERE RAPORT_ID = P_RAPORT_ID;

    IF RAPORT_COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Raport o podanym ID nie istnieje.');
    END IF;

    DELETE FROM RAPORTY_TAB
    WHERE RAPORT_ID = P_RAPORT_ID;

    DBMS_OUTPUT.PUT_LINE('Usunieto raport o ID: ' || P_RAPORT_ID);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Blad podczas usuwania raportu: ' || SQLERRM);
        ROLLBACK;
END USUN_RAPORT;

PROCEDURE WYSWIETL_OBECNOSCI_ZAWODNIKA(
    P_ZAWODNIK_ID NUMBER
) AS
obecnosci number :=0;
nieobecnosci number :=0;
BEGIN
FOR r IN (
        SELECT  r.aktywnosc_id, r.typ, r.data_utworzenia,r.uwagi
        FROM RAPORTY_TAB r
        WHERE P_ZAWODNIK_ID MEMBER OF r.lista_obecnych AND P_ZAWODNIK_ID MEMBER OF r.lista_zapisanych
    ) LOOP
    obecnosci := obecnosci +1;
        DBMS_OUTPUT.PUT_LINE(
                             'AKTYWNOSC ID: ' || r.aktywnosc_id || 
                             ', TYP: ' || r.typ || 
                             ', DATA UTWORZENIA: ' || TO_CHAR(r.data_utworzenia, 'YYYY-MM-DD HH24:MI:SS') || ' zawodnik obecny');
         DBMS_OUTPUT.PUT_LINE(r.uwagi);                    
    END LOOP;
FOR r IN (
        SELECT  r.aktywnosc_id, r.typ, r.data_utworzenia
        FROM RAPORTY_TAB r
        WHERE P_ZAWODNIK_ID not MEMBER OF r.lista_obecnych AND P_ZAWODNIK_ID MEMBER OF r.lista_zapisanych
    ) LOOP
    nieobecnosci := nieobecnosci +1;
        DBMS_OUTPUT.PUT_LINE(
                             'AKTYWNOSC ID: ' || r.aktywnosc_id || 
                             ', TYP: ' || r.typ || 
                             ', DATA UTWORZENIA: ' || TO_CHAR(r.data_utworzenia, 'YYYY-MM-DD HH24:MI:SS') || ' zawodnik nieobecny');
                             
    END LOOP;
     DBMS_OUTPUT.PUT_LINE('obecnosci / nieobecnosci = ' || obecnosci || ' / ' || nieobecnosci);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Blad podczas wyswietlania raportow: ' || SQLERRM);
END WYSWIETL_OBECNOSCI_ZAWODNIKA;

END TRENER;


create or replace NONEDITIONABLE PACKAGE WYSWIETLANIE AS 

PROCEDURE WYSWIETL_AKTYWNOSCI_OSOBY (
OSOBA_ID NUMBER,
OKRESOWE NUMBER, --2 = OKRESOWE I NIEOKRESOWE
ODBYTE NUMBER,
DZIEN NUMBER -- 1-7, 0 -- BEZ
);


PROCEDURE WYSWIETL_DZIEN(DZIEN NUMBER);

PROCEDURE POKAZ_WSZYTSKIE_AKTYWNOSCI;

PROCEDURE WYSWIETL_LISTE(LISTA OSOBY_ID_TAB);


PROCEDURE WYSWIETL_KONDYCJE_ZAWODNIKA(ZAWODNIK_ID NUMBER);
END WYSWIETLANIE;

create or replace NONEDITIONABLE PACKAGE BODY WYSWIETLANIE AS

  PROCEDURE WYSWIETL_AKTYWNOSCI_OSOBY (
OSOBA_ID NUMBER,
OKRESOWE NUMBER, --2 = OKRESOWE I NIEOKRESOWE
ODBYTE NUMBER, --2 == TAKIE I TAKIE
DZIEN NUMBER
) AS
  BEGIN
  
   FOR REC IN (
        SELECT a.AKTYWNOSC_ID,
               a.TYP,
               A.T,
               A.OKRESOWE,
               A.ODBYTE,
               A.LISTA_OSOB,
               DEREF(a.MIEJSCE) AS MIEJSCE
        FROM AKTYWNOSCI_TAB a,
             TABLE(a.Lista_osob) l
        WHERE l.COLUMN_VALUE = OSOBA_ID AND (A.ODBYTE = ODBYTE OR ODBYTE = 2) AND (A.OKRESOWE = OKRESOWE OR OKRESOWE = 2) AND (A.T.DZIEN_TYGODNIA = DZIEN OR DZIEN = 8)
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('AKTYWNOSC_ID: ' || REC.AKTYWNOSC_ID);
        DBMS_OUTPUT.PUT_LINE('TYP: ' || REC.TYP);
        DBMS_OUTPUT.PUT_LINE('GODZINA:' || REC.T.CZAS_FORMATOWANY());
        DBMS_OUTPUT.PUT_LINE('CZAS_TRWANIA: ' || REC.T.CZAS_TRWANIA);
        DBMS_OUTPUT.PUT_LINE('ZAWODNICY ZAPISANI: ' );
        wyswietlanie.wyswietl_liste(REC.LISTA_OSOB);
        IF REC.MIEJSCE IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('MIEJSCE: ' || REC.MIEJSCE.NAZWA); 
        END IF;
        IF REC.OKRESOWE = 1 THEN
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC CYKLICZNA');
        ELSE
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC JEDNORAZOWA');
        END IF;
        IF REC.LISTA_OSOB.COUNT = 1 THEN
            DBMS_OUTPUT.PUT_LINE('ZAJECIA INDYWIDUALNE');
        ELSE
            DBMS_OUTPUT.PUT_LINE('ZAJECIA GRUPOWE');
        END IF;
        IF REC.ODBYTE = 1 THEN
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC MINELA');
        ELSE
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC AKTUALNA');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    END LOOP;
  END WYSWIETL_AKTYWNOSCI_OSOBY;


PROCEDURE WYSWIETL_DZIEN(DZIEN NUMBER) AS 
BEGIN
NULL;
END WYSWIETL_DZIEN;

PROCEDURE POKAZ_WSZYTSKIE_AKTYWNOSCI AS
BEGIN
    FOR REC IN (
        SELECT a.AKTYWNOSC_ID,
               a.TYP,
               A.T,
               A.OKRESOWE,
               A.ODBYTE,
               A.LISTA_OSOB,
               DEREF(a.MIEJSCE) AS MIEJSCE
        FROM AKTYWNOSCI_TAB a,
             TABLE(a.Lista_osob) l

    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('AKTYWNOSC_ID: ' || REC.AKTYWNOSC_ID);
        DBMS_OUTPUT.PUT_LINE('TYP: ' || REC.TYP);
        DBMS_OUTPUT.PUT_LINE('GODZINA:' || REC.T.CZAS_FORMATOWANY());
        DBMS_OUTPUT.PUT_LINE('CZAS_TRWANIA: ' || REC.T.CZAS_TRWANIA);
        DBMS_OUTPUT.PUT_LINE('ZAWODNICY ZAPISANI: ' );
        wyswietlanie.wyswietl_liste(REC.LISTA_OSOB);
        IF REC.MIEJSCE IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('MIEJSCE: ' || REC.MIEJSCE.NAZWA); 
        END IF;
        IF REC.OKRESOWE = 1 THEN
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC CYKLICZNA');
        ELSE
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC JEDNORAZOWA');
        END IF;
        IF REC.LISTA_OSOB.COUNT = 1 THEN
            DBMS_OUTPUT.PUT_LINE('ZAJECIA INDYWIDUALNE');
        ELSE
            DBMS_OUTPUT.PUT_LINE('ZAJECIA GRUPOWE');
        END IF;
        IF REC.ODBYTE = 1 THEN
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC MINELA');
        ELSE
            DBMS_OUTPUT.PUT_LINE('AKTYWNOSC AKTUALNA');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    END LOOP;
END POKAZ_WSZYTSKIE_AKTYWNOSCI;

PROCEDURE WYSWIETL_LISTE(LISTA OSOBY_ID_TAB) AS
    people_line VARCHAR2(4000); 
BEGIN
    
    IF LISTA IS NOT NULL AND LISTA.COUNT > 0 THEN
      
        SELECT LISTAGG(COLUMN_VALUE, ', ') WITHIN GROUP (ORDER BY COLUMN_VALUE)
          INTO people_line
          FROM TABLE(LISTA);

        DBMS_OUTPUT.PUT_LINE('Osoby ID: ' || people_line);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Podana lista jest pusta.');
    END IF;
END WYSWIETL_LISTE;

PROCEDURE WYSWIETL_KONDYCJE_ZAWODNIKA(ZAWODNIK_ID NUMBER) AS
    v_kondycja WYTRENOWANIE_TYP;
BEGIN

    SELECT o.Wytrenowanie
    INTO v_kondycja
    FROM OSOBA_TAB o
    WHERE o.Osoba_id = ZAWODNIK_ID;

    DBMS_OUTPUT.PUT_LINE('Kondycja: ' || v_kondycja.kondycja);
    DBMS_OUTPUT.PUT_LINE('Masa: ' || v_kondycja.masa);
    DBMS_OUTPUT.PUT_LINE('Wzrost: ' || v_kondycja.wzrost);
    DBMS_OUTPUT.PUT_LINE('Data aktualizacji: ' || TO_CHAR(v_kondycja.data_aktualizacji, 'YYYY-MM-DD HH24:MI:SS'));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Brak zawodnika o ID: ' || ZAWODNIK_ID);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Wystapil blad: ' || SQLERRM);
END WYSWIETL_KONDYCJE_ZAWODNIKA;

END WYSWIETLANIE;

CREATE OR REPLACE TYPE Dyscyplina_typ AS OBJECT (
    Dyscyp_id NUMBER,
    Dysc_name VARCHAR2(100)
);

CREATE TYPE DYSCYPLINA_TAB AS TABLE OF DYSCYPLINA_TYP;

CREATE SEQUENCE seq_dyscyplina_id START WITH 1 INCREMENT BY 1 NOCACHE;

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

CREATE OR REPLACE TYPE PB_Wynik_tab AS TABLE OF PB_Wynik_typ;

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

CREATE OR REPLACE TYPE Wystepy_tab AS TABLE OF Wystepy_typ;

CREATE SEQUENCE seq_wystep_id START WITH 1 INCREMENT BY 1 NOCACHE;


CREATE OR REPLACE TYPE wytrenowanie_typ AS OBJECT(
    kondycja NUMBER,
    masa NUMBER,
    wzrost NUMBER,
    data_aktualizacji DATE,
    CONSTRUCTOR FUNCTION wytrenowanie_typ(
        masa NUMBER,
        wzrost NUMBER
    ) RETURN SELF AS RESULT,
    MEMBER PROCEDURE update_kondycja
);
/
CREATE OR REPLACE TYPE BODY wytrenowanie_typ AS
    CONSTRUCTOR FUNCTION wytrenowanie_typ(
        masa IN NUMBER,
        wzrost IN NUMBER
    ) RETURN SELF AS RESULT IS
    BEGIN
        SELF.kondycja := 0;
        SELF.masa := masa;
        SELF.wzrost := wzrost;
        SELF.data_aktualizacji := SYSDATE;
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

CREATE SEQUENCE seq_zawodnik_id START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE Osoba_tab OF Osoba_typ (
    CONSTRAINT CK_Active CHECK (Active IN (0, 1))
)
NESTED TABLE Wystepy STORE AS Wystepy_Table
NESTED TABLE Dyscypliny STORE AS Dyscyplina_Table
NESTED TABLE Wyniki_dyscyplin STORE AS PB_Wynik_Table;

CREATE OR REPLACE TRIGGER Check_Data_Urodzenia
BEFORE INSERT OR UPDATE ON Osoba_tab
FOR EACH ROW
BEGIN
    IF :NEW.Data_urodzenia > ADD_MONTHS(SYSDATE, -12 * 7) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Data urodzenia musi wskazywac na wiek co najmniej 7 lat.');
    END IF;
END;

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

CREATE OR REPLACE TRIGGER TR_DyscyplinyZawodnika
BEFORE INSERT OR UPDATE ON Osoba_tab
FOR EACH ROW
WHEN (NEW.Rola = 'zawodnik')
DECLARE
    liczba_dyscyplin NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO liczba_dyscyplin
    FROM TABLE(:NEW.Dyscypliny);

    IF liczba_dyscyplin > 5 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Zawodnik moze miec maksymalnie 5 dyscyplin.');
    END IF;
END;

CREATE OR REPLACE TRIGGER TR_AktywneUbezpieczenie
BEFORE INSERT OR UPDATE ON Osoba_tab
FOR EACH ROW
WHEN (NEW.Rola = 'zawodnik')
BEGIN
    IF :NEW.Koniec_ubezpieczenia <= SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20006, 'Zawodnik musi posiadac aktywne ubezpieczenie.');
    END IF;
END;

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
    RAISE_APPLICATION_ERROR(-20010, 'Osoba o tym samym imieniu, nazwisku i dacie urodzenia ju¿ istnieje.');
  END IF;
END;

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
         RAISE_APPLICATION_ERROR(-20011,
            'Wystêp z t¹ sam¹ nazw¹, miejscowoœci¹ i konkurencj¹ ju¿ istnieje wœród wystêpów danej osoby.');
      END IF;
   END IF;
END;

CREATE OR REPLACE TYPE BODY Osoba_typ AS
    MEMBER FUNCTION PelneImie RETURN VARCHAR2 IS
    BEGIN
        RETURN Imie || ' ' || Nazwisko;
    END;
END;

CREATE OR REPLACE PACKAGE OBSLUGA_ZAWODNIKA AS
    -- Dodanie zawodnika
    PROCEDURE DodajZawodnika(
        p_Imie VARCHAR2,
        p_Nazwisko VARCHAR2,
        p_Kraj_pochodzenia VARCHAR2,
        p_Data_urodzenia DATE,
        p_Przydzielony_trener NUMBER,
        p_Koniec_ubezpieczenia DATE
    );

    -- Usuniecie zawodnika
    PROCEDURE UsunZawodnika(p_Osoba_id NUMBER);

    -- Aktualizacja danych zawodnika
    PROCEDURE AktualizujDaneZawodnika(
        p_Osoba_id NUMBER,
        p_Imie VARCHAR2 := NULL,
        p_Nazwisko VARCHAR2 := NULL,
        p_Kraj_pochodzenia VARCHAR2 := NULL,
        p_Data_urodzenia DATE := NULL,
        p_Przydzielony_trener NUMBER := NULL
    );

    -- Ustawienie zawodnika jako aktywnego/nieaktywnego
    PROCEDURE ZmienStatusZawodnika(
        p_Osoba_id NUMBER,
        p_Status NUMBER
    );

    -- Dodanie wystepu zawodnikowi
    PROCEDURE DodajWystep(
        p_Osoba_id NUMBER,
        p_Wystep Wystepy_typ
    );

    -- Aktualizacja wynikow PB zawodnika
    PROCEDURE AktualizujPB(
        p_Osoba_id   NUMBER,
        p_Dyscyplina VARCHAR2,
        p_Wynik      NUMBER,
        p_Rok        NUMBER
    );

    -- Dodanie nowej dyscypliny zawodnikowi
    PROCEDURE DodajDyscypline(
        p_Osoba_id NUMBER,
        p_Dyscyplina Dyscyplina_typ
    );

    -- Aktualizacja ubezpieczenia zawodnika
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


CREATE OR REPLACE PACKAGE BODY OBSLUGA_ZAWODNIKA AS
    PROCEDURE DodajZawodnika(
        p_Imie VARCHAR2,
        p_Nazwisko VARCHAR2,
        p_Kraj_pochodzenia VARCHAR2,
        p_Data_urodzenia DATE,
        p_Przydzielony_trener NUMBER,
        p_Koniec_ubezpieczenia DATE
    ) IS
    BEGIN
        INSERT INTO Osoba_tab VALUES (
            Osoba_typ(
                seq_zawodnik_id.NEXTVAL, p_Imie, p_Nazwisko, p_Kraj_pochodzenia,
                p_Data_urodzenia, 'zawodnik', p_Przydzielony_trener,
                NEW wytrenowanie_typ(100, 70, 180, SYSDATE),
                Wystepy_tab(),
                Dyscyplina_tab(),
                PB_Wynik_tab(),
                1,
                p_Koniec_ubezpieczenia
            )
        );
    END;

    PROCEDURE UsunZawodnika(p_Osoba_id NUMBER) IS
    BEGIN
        DELETE FROM Osoba_tab WHERE Osoba_id = p_Osoba_id;
    END;

    PROCEDURE AktualizujDaneZawodnika(
        p_Osoba_id NUMBER,
        p_Imie VARCHAR2 := NULL,
        p_Nazwisko VARCHAR2 := NULL,
        p_Kraj_pochodzenia VARCHAR2 := NULL,
        p_Data_urodzenia DATE := NULL,
        p_Przydzielony_trener NUMBER := NULL
    ) IS
    BEGIN
        UPDATE Osoba_tab
        SET Imie = NVL(p_Imie, Imie),
            Nazwisko = NVL(p_Nazwisko, Nazwisko),
            Kraj_pochodzenia = NVL(p_Kraj_pochodzenia, Kraj_pochodzenia),
            Data_urodzenia = NVL(p_Data_urodzenia, Data_urodzenia),
            Przelozony = NVL(p_Przydzielony_trener, Przelozony)
        WHERE Osoba_id = p_Osoba_id;
    END;

    PROCEDURE ZmienStatusZawodnika(
        p_Osoba_id NUMBER,
        p_Status NUMBER
    ) IS
    BEGIN
        UPDATE Osoba_tab
        SET Active = p_Status
        WHERE Osoba_id = p_Osoba_id;
    END;

    PROCEDURE DodajWystep(
        p_Osoba_id NUMBER,
        p_Wystep Wystepy_typ
    ) IS
        v_Wystepy Wystepy_tab;
    BEGIN
        SELECT Wystepy INTO v_Wystepy
        FROM Osoba_tab
        WHERE Osoba_id = p_Osoba_id;

        v_Wystepy.EXTEND;
        v_Wystepy(v_Wystepy.LAST) := p_Wystep;

        UPDATE Osoba_tab
        SET Wystepy = v_Wystepy
        WHERE Osoba_id = p_Osoba_id;
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
      -- Pobranie aktualnego zbioru wyników dla danego zawodnika
      SELECT Wyniki_dyscyplin
        INTO v_Wyniki
        FROM Osoba_tab
       WHERE Osoba_id = p_Osoba_id
       FOR UPDATE;
  
      -- Przeszukanie tablicy, czy istnieje wpis dla zadanego roku
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
          -- Jeœli wpis istnieje, aktualizujemy tylko pole dla danej dyscypliny
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
          -- Zapisujemy zaktualizowany obiekt do tablicy
          v_Wyniki(v_idx) := v_temp;
  
      ELSE
          -- Jeœli wpis dla zadanego roku nie istnieje, tworzymy nowy obiekt
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
  
      -- Zapisanie zaktualizowanej tablicy wyników do rekordu
      UPDATE Osoba_tab
      SET Wyniki_dyscyplin = v_Wyniki
      WHERE Osoba_id = p_Osoba_id;
  
      COMMIT;
  END AktualizujPB;

    PROCEDURE DodajDyscypline(
        p_Osoba_id NUMBER,
        p_Dyscyplina Dyscyplina_typ
    ) IS
        v_dyscypliny DYSCYPLINA_TAB;
    BEGIN
        SELECT Dyscypliny INTO v_dyscypliny
        FROM Osoba_tab
        WHERE Osoba_id = p_Osoba_id;
    
        v_dyscypliny.EXTEND;
        v_dyscypliny(v_dyscypliny.LAST) := p_Dyscyplina;
    
        UPDATE Osoba_tab
        SET Dyscypliny = v_dyscypliny
        WHERE Osoba_id = p_Osoba_id;
    END;

    PROCEDURE AktualizujUbezpieczenie(
        p_Osoba_id NUMBER,
        p_Koniec_ubezpieczenia DATE
    ) IS
    BEGIN
        UPDATE Osoba_tab
        SET Koniec_ubezpieczenia = p_Koniec_ubezpieczenia
        WHERE Osoba_id = p_Osoba_id;
    END;
    
    FUNCTION CzyZawodnikIstnieje(p_OsobaId NUMBER) RETURN BOOLEAN IS
    v_Count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_Count
        FROM Osoba_tab
        WHERE Osoba_id = p_OsobaId;
    
        RETURN v_Count > 0;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END;
    
    FUNCTION LiczbaAktywnychZawodnikow RETURN NUMBER IS
        v_Count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_Count
        FROM Osoba_tab
        WHERE Active = 1;
    
        RETURN v_Count;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END;
    
    FUNCTION PobierzSzczegolyZawodnika(p_OsobaId NUMBER) RETURN VARCHAR2 IS
        v_RefCursor SYS_REFCURSOR;
        v_Imie VARCHAR2(50);
        v_Nazwisko VARCHAR2(50);
        v_Kraj_pochodzenia VARCHAR2(50);
        v_Data_urodzenia DATE;
        v_Rola VARCHAR2(50);
        v_Active NUMBER;
        v_Przydzielony_trener NUMBER;
        v_Output VARCHAR2(4000) := '';
    BEGIN
        OPEN v_RefCursor FOR
            SELECT Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Active, Przelozony
            FROM Osoba_tab
            WHERE Osoba_id = p_OsobaId;
    
            LOOP
            FETCH v_RefCursor INTO v_Imie, v_Nazwisko, v_Kraj_pochodzenia, v_Data_urodzenia, v_Rola, v_Active, v_Przydzielony_trener;
            EXIT WHEN v_RefCursor%NOTFOUND;
    
            -- Przygotowanie tekstu z danymi zawodnika
            v_Output := 'Imie: ' || v_Imie || ' | Nazwisko: ' || v_Nazwisko || ' | Kraj: ' || v_Kraj_pochodzenia || 
                        ' | Data urodzenia: ' || TO_CHAR(v_Data_urodzenia, 'YYYY-MM-DD') || ' | Rola: ' || v_Rola ||
                        ' | Aktywny: ' || CASE WHEN v_Active = 1 THEN 'Tak' ELSE 'Nie' END || ' | Trener: ' || v_Przydzielony_trener;
        END LOOP;
        
        CLOSE v_RefCursor;
    
        DBMS_OUTPUT.PUT_LINE(v_Output);
        RETURN v_Output;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Blad podczas pobierania danych zawodnika';
    END PobierzSzczegolyZawodnika;

    
    FUNCTION WyswietlWystepyZawodnika(p_Osoba_id NUMBER) RETURN VARCHAR2 IS
        v_Cursor SYS_REFCURSOR;
        v_Nazwa         VARCHAR2(50);
        v_Miejscowosc   VARCHAR2(50);
        v_Konkurencja   VARCHAR2(50);
        v_Wynik_miejsce VARCHAR2(50);
        v_Output        VARCHAR2(4000) := '';
    BEGIN
        OPEN v_Cursor FOR
            SELECT wt.Nazwa, wt.Miejscowosc, wt.Konkurencja, wt.Wynik_miejsce
            FROM TABLE(
                SELECT o.Wystepy
                FROM Osoba_tab o
                WHERE o.Osoba_id = p_Osoba_id
            ) wt;
    
        LOOP
            FETCH v_Cursor INTO v_Nazwa, v_Miejscowosc, v_Konkurencja, v_Wynik_miejsce;
            EXIT WHEN v_Cursor%NOTFOUND;
    
            -- Wyœwietlanie ka¿dej linii z nowym polem Konkurencja
            v_Output := v_Output || 'Nazwa: ' || v_Nazwa ||
                        ' | Miejscowoœæ: ' || v_Miejscowosc ||
                        ' | Konkurencja: ' || v_Konkurencja ||
                        ' | Wynik: ' || v_Wynik_miejsce || CHR(10);
        END LOOP;
    
        CLOSE v_Cursor;
    
        DBMS_OUTPUT.PUT_LINE(v_Output);
        RETURN v_Output;
    END WyswietlWystepyZawodnika;


    
    FUNCTION ZwrocPrzelozonego(p_Osoba_id NUMBER) RETURN VARCHAR2 IS
        v_Nazwisko VARCHAR2(50);
    BEGIN
        SELECT Nazwisko INTO v_Nazwisko
        FROM Osoba_tab
        WHERE Osoba_id = (SELECT Przelozony FROM Osoba_tab WHERE Osoba_id = p_Osoba_id);

        RETURN v_Nazwisko;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Brak przelozonego';
        WHEN OTHERS THEN
            RETURN 'Blad podczas pobierania przelozonego';
    END ZwrocPrzelozonego;
    
    FUNCTION WyswietlWynikiZawodnika(p_Osoba_id NUMBER) RETURN VARCHAR2 IS
    v_RefCursor          SYS_REFCURSOR;
    v_Bieg_100m          NUMBER(5,3);
    v_Bieg_110m_plotki   NUMBER(5,3);
    v_Bieg_400m          NUMBER(5,3);
    v_Bieg_1500m         NUMBER(7,3);
    v_Skok_wzwyz         NUMBER(5,3);
    v_Skok_tyczka        NUMBER(5,3);
    v_Skok_w_dal         NUMBER(5,3);
    v_Metry_kula         NUMBER(5,3);
    v_Metry_oszczep      NUMBER(5,3);
    v_Metry_dysk         NUMBER(5,3);
    v_Metry_mlot         NUMBER(5,3);
    v_Rok                NUMBER;
    v_Line               VARCHAR2(1000);
    v_Output             VARCHAR2(4000) := '';
BEGIN
    OPEN v_RefCursor FOR
        SELECT 
            wt.Bieg_100m,
            wt.Bieg_110m_plotki,
            wt.Bieg_400m,
            wt.Bieg_1500m,
            wt.Skok_wzwyz,
            wt.Skok_tyczka,
            wt.Skok_w_dal,
            wt.Metry_kula,
            wt.Metry_oszczep,
            wt.Metry_dysk,
            wt.Metry_mlot,
            wt.Rok
        FROM TABLE(
            SELECT o.Wyniki_dyscyplin
            FROM Osoba_tab o
            WHERE o.Osoba_id = p_Osoba_id
        ) wt;

    LOOP
        FETCH v_RefCursor INTO 
            v_Bieg_100m, v_Bieg_110m_plotki, v_Bieg_400m, v_Bieg_1500m, 
            v_Skok_wzwyz, v_Skok_tyczka, v_Skok_w_dal, 
            v_Metry_kula, v_Metry_oszczep, v_Metry_dysk, v_Metry_mlot, v_Rok;
        EXIT WHEN v_RefCursor%NOTFOUND;

        -- Budujemy liniê wyników dla danego rekordu
        v_Line := 'Rok: ' || v_Rok;
        IF v_Bieg_100m IS NOT NULL THEN
            v_Line := v_Line || ' | Sprint 100m: ' || v_Bieg_100m;
        END IF;
        IF v_Bieg_110m_plotki IS NOT NULL THEN
            v_Line := v_Line || ' | 110m_plotki: ' || v_Bieg_110m_plotki;
        END IF;
        IF v_Bieg_400m IS NOT NULL THEN
            v_Line := v_Line || ' | 400m: ' || v_Bieg_400m;
        END IF;
        IF v_Bieg_1500m IS NOT NULL THEN
            v_Line := v_Line || ' | 1500m: ' || v_Bieg_1500m;
        END IF;
        IF v_Skok_wzwyz IS NOT NULL THEN
            v_Line := v_Line || ' | Skok_wzwyz: ' || v_Skok_wzwyz;
        END IF;
        IF v_Skok_tyczka IS NOT NULL THEN
            v_Line := v_Line || ' | Skok_tyczka: ' || v_Skok_tyczka;
        END IF;
        IF v_Skok_w_dal IS NOT NULL THEN
            v_Line := v_Line || ' | Skok_w_dal: ' || v_Skok_w_dal;
        END IF;
        IF v_Metry_kula IS NOT NULL THEN
            v_Line := v_Line || ' | Metry_kula: ' || v_Metry_kula;
        END IF;
        IF v_Metry_oszczep IS NOT NULL THEN
            v_Line := v_Line || ' | Metry_oszczep: ' || v_Metry_oszczep;
        END IF;
        IF v_Metry_dysk IS NOT NULL THEN
            v_Line := v_Line || ' | Metry_dysk: ' || v_Metry_dysk;
        END IF;
        IF v_Metry_mlot IS NOT NULL THEN
            v_Line := v_Line || ' | Metry_mlot: ' || v_Metry_mlot;
        END IF;
        
        v_Output := v_Output || v_Line || CHR(10);
    END LOOP;

    CLOSE v_RefCursor;
    DBMS_OUTPUT.PUT_LINE(v_Output);
    RETURN v_Output;
END WyswietlWynikiZawodnika;

    
    FUNCTION WyswietlZawodnikowPodTrenerem(p_Trener_id NUMBER) RETURN VARCHAR2 IS
        v_RefCursor SYS_REFCURSOR;
        v_Osoba_id NUMBER;
        v_Imie VARCHAR2(50);
        v_Nazwisko VARCHAR2(50);
        v_Data_urodzenia DATE;
        v_Kraj_pochodzenia VARCHAR2(50);
        v_Output VARCHAR2(4000) := '';
    BEGIN
        OPEN v_RefCursor FOR
            SELECT Osoba_id, Imie, Nazwisko, Data_urodzenia, Kraj_pochodzenia
            FROM Osoba_tab
            WHERE Przelozony = p_Trener_id AND Rola = 'zawodnik';
    
        LOOP
            FETCH v_RefCursor INTO v_Osoba_id, v_Imie, v_Nazwisko, v_Data_urodzenia, v_Kraj_pochodzenia;
            EXIT WHEN v_RefCursor%NOTFOUND;
    
            -- Przygotowanie tekstu z wynikami
            v_Output := v_Output || 'Osoba ID: ' || v_Osoba_id || ' | Imie: ' || v_Imie || ' | Nazwisko: ' || v_Nazwisko || 
                        ' | Data urodzenia: ' || TO_CHAR(v_Data_urodzenia, 'YYYY-MM-DD') || ' | Kraj: ' || v_Kraj_pochodzenia || CHR(10);
        END LOOP;
    
        CLOSE v_RefCursor;
    
        DBMS_OUTPUT.PUT_LINE(v_Output);
        RETURN v_Output;
    END WyswietlZawodnikowPodTrenerem;

END OBSLUGA_ZAWODNIKA;
/


--Testy
INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Dominik', 'Kowalczyk', 'Polska', TO_DATE('1980-05-15', 'YYYY-MM-DD'), 'Boss', NULL, NULL, NULL, NULL, NULL, 1, NULL);

select * from Osoba_tab;

INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Dominik', 'Kowalczyk', 'Polska', TO_DATE('1979-09-25', 'YYYY-MM-DD'), 'Trener', 3, NULL, NULL, NULL, NULL, 1, NULL);
INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Piotr', 'Nowak', 'Polska', TO_DATE('1975-08-20', 'YYYY-MM-DD'), 'Trener', 3, NULL, NULL, NULL, NULL, 1, NULL);
INSERT INTO Osoba_tab (Osoba_id, Imie, Nazwisko, Kraj_pochodzenia, Data_urodzenia, Rola, Przelozony, wytrenowanie, Wystepy, Dyscypliny, Wyniki_dyscyplin, Active, Koniec_ubezpieczenia)
VALUES (seq_zawodnik_id.NEXTVAL, 'Anna', 'Zielinska', 'Polska', TO_DATE('1982-02-10', 'YYYY-MM-DD'), 'Trener', 3, NULL, NULL, NULL, NULL, 1, NULL);


select * from osoba_tab;

BEGIN
    OBSLUGA_ZAWODNIKA.DodajZawodnika(
        p_Imie => 'Jan',
        p_Nazwisko => 'Kowalski',
        p_Kraj_pochodzenia => 'Polska',
        p_Data_urodzenia => TO_DATE('1990-02-15', 'YYYY-MM-DD'),
        p_Przydzielony_trener => 4,
        p_Koniec_ubezpieczenia => TO_DATE('2025-12-31', 'YYYY-MM-DD')
    );
end;
begin
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

set serveroutput on;

DECLARE
    v_Output VARCHAR2(4000);
BEGIN
    v_Output := OBSLUGA_ZAWODNIKA.WyswietlWystepyZawodnika(p_Osoba_id => 8);
END;

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
    OBSLUGA_ZAWODNIKA.AktualizujPB(
        p_Osoba_id   => 8,
        p_Dyscyplina => 'Bieg_100m',
        p_Wynik      => 10.25,
        p_Rok        => 2023
    );

    OBSLUGA_ZAWODNIKA.AktualizujPB(
        p_Osoba_id   => 8,
        p_Dyscyplina => 'Bieg_110m_plotki',
        p_Wynik      => 11.10,
        p_Rok        => 2022
    );
    
    OBSLUGA_ZAWODNIKA.AktualizujPB(
        p_Osoba_id   => 8,
        p_Dyscyplina => 'Bieg_100m',
        p_Wynik      => 9.80,
        p_Rok        => 2021
    );
    
    OBSLUGA_ZAWODNIKA.AktualizujPB(
        p_Osoba_id   => 8,
        p_Dyscyplina => 'Bieg_100m',
        p_Wynik      => 9.80,
        p_Rok        => 2021
    );
    
    OBSLUGA_ZAWODNIKA.AktualizujPB(
        p_Osoba_id   => 8,
        p_Dyscyplina => 'Bieg_400m',
        p_Wynik      => 47.80,
        p_Rok        => 2021
    );
    
    OBSLUGA_ZAWODNIKA.AktualizujPB(
        p_Osoba_id   => 8,
        p_Dyscyplina => 'Metry_oszczep',
        p_Wynik      => 95.80,
        p_Rok        => 2021
    );
    
    OBSLUGA_ZAWODNIKA.AktualizujPB(
        p_Osoba_id   => 8,
        p_Dyscyplina => 'Metry_mlot',
        p_Wynik      => 25.80,
        p_Rok        => 2021
    );
    
    COMMIT;
END;

DECLARE
    v_Output VARCHAR2(4000);
BEGIN
    v_Output := OBSLUGA_ZAWODNIKA.WyswietlWynikiZawodnika(p_Osoba_id => 8);
END;


BEGIN
    OBSLUGA_ZAWODNIKA.ZmienStatusZawodnika(
        p_Osoba_id => 1,
        p_Status => 1 -- Status aktywny
    );

    OBSLUGA_ZAWODNIKA.ZmienStatusZawodnika(
        p_Osoba_id => 2,
        p_Status => 1 -- Status aktywny
    );

    OBSLUGA_ZAWODNIKA.ZmienStatusZawodnika(
        p_Osoba_id => 3,
        p_Status => 0 -- Status nieaktywny
    );
    
    COMMIT;
END;

SELECT 
    Osoba_id, 
    Imie, 
    Nazwisko, 
    CASE 
        WHEN Active = 1 THEN 'Aktywny' 
        ELSE 'Nieaktywny' 
    END AS Status
FROM 
    Osoba_tab;


SELECT 
    Imie, 
    Nazwisko, 
    Kraj_pochodzenia, 
    TO_CHAR(Data_urodzenia, 'YYYY-MM-DD') AS Data_urodzenia, 
    Rola, 
    CASE 
        WHEN Active = 1 THEN 'Aktywny' 
        ELSE 'Nieaktywny' 
    END AS Status, 
    Przelozony AS Trener 
FROM 
    Osoba_tab
WHERE 
    Osoba_id = 8;
    

BEGIN
    DECLARE
    v_Dyscyplina Dyscyplina_typ := Dyscyplina_typ(seq_dyscyplina_id.NEXTVAL, 'Bieg 100m');
    BEGIN
        OBSLUGA_ZAWODNIKA.DodajDyscypline(p_Osoba_id => 1, p_Dyscyplina => v_Dyscyplina);
        COMMIT;
    END;
END;



BEGIN
    OBSLUGA_ZAWODNIKA.AktualizujUbezpieczenie(
        p_Osoba_id => 1,
        p_Koniec_ubezpieczenia => TO_DATE('2026-12-31', 'YYYY-MM-DD')
    );
    COMMIT;
END;

DECLARE
    v_Exists BOOLEAN;
BEGIN
    v_Exists := OBSLUGA_ZAWODNIKA.CzyZawodnikIstnieje(p_OsobaId => 80);
    DBMS_OUTPUT.PUT_LINE('Czy zawodnik istnieje: ' || CASE WHEN v_Exists THEN 'Tak' ELSE 'Nie' END);
END;


DECLARE
    v_Count NUMBER;
BEGIN
    v_Count := OBSLUGA_ZAWODNIKA.LiczbaAktywnychZawodnikow;
    DBMS_OUTPUT.PUT_LINE('Liczba aktywnych zawodnikow: ' || v_Count);
END;


DECLARE
    v_Details VARCHAR2(4000);
BEGIN
    v_Details := OBSLUGA_ZAWODNIKA.PobierzSzczegolyZawodnika(p_OsobaId => 8);
END;


SET SERVEROUTPUT on;


DECLARE
    v_Przydzielony_trener VARCHAR2(50);
BEGIN
    v_Przydzielony_trener := OBSLUGA_ZAWODNIKA.ZwrocPrzelozonego(p_Osoba_id => 8);
    DBMS_OUTPUT.PUT_LINE('Prze³o¿ony zawodnika: ' || v_Przydzielony_trener);
END;


DECLARE
    v_Output VARCHAR2(4000);
BEGIN
    v_Output := OBSLUGA_ZAWODNIKA.WyswietlZawodnikowPodTrenerem(p_Trener_id => 101);
    DBMS_OUTPUT.PUT_LINE(v_Output);
END;


BEGIN
TERMINARZ.dodaj_miejsce('BOISKO_2', 25);
TERMINARZ.dodaj_miejsce('BOISKO_1', 25);
TERMINARZ.dodaj_miejsce('BASEN', 10);
TERMINARZ.dodaj_miejsce('BIE¯NA NA POWIETRZU', 5);
TERMINARZ.dodaj_miejsce('SALA MASAZYSTY', 2);
END;

select * from miejsca_tab;
BEGIN
TERMINARZ.DODAJ_AKTYWNOSC('MASAZ REGENERACYJNY', TERMIN(10,15,5,2),1,OSOBY_ID_TAB(1,3),5);
END;
BEGIN
TERMINARZ.DODAJ_AKTYWNOSC('TRENING OGOLNY', TERMIN(21,15,3,2),1,OSOBY_ID_TAB(1,2,3,4,5),3);
TERMINARZ.DODAJ_AKTYWNOSC('TRENING OGOLNY', TERMIN(21,15,1,5),0,OSOBY_ID_TAB(1,2),1);
TERMINARZ.DODAJ_AKTYWNOSC('TRENING NA BOISKU', TERMIN(8,15,3,2),1,OSOBY_ID_TAB(1,2,3,4,5),2);
end;
BEGIN
TERMINARZ.DODAJ_AKTYWNOSC('TRENING SILOWY', TERMIN(14,15,3,1),0,OSOBY_ID_TAB(2),4);
END;

SET SERVEROUTPUT ON;
BEGIN
WYSWIETLANIE.POKAZ_WSZYTSKIE_AKTYWNOSCI;

END;
BEGIN
trener.wyswietl_obecnosci_zawodnika(2);
end;
BEGIN
WYSWIETLANIE.WYSWIETL_KONDYCJE_ZAWODNIKA(3);
END;