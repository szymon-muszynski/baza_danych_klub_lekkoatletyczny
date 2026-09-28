# 🏃 System Zarządzania Klubem Lekkoatletycznym (Oracle PL/SQL)

Obiektowo-relacyjna baza danych stworzona w języku **Oracle PL/SQL**, służąca do zarządzania klubem lekkoatletycznym. System obsługuje zawodników, trenerów, harmonogramy treningów (aktywności), miejsca treningowe oraz raportowanie obecności i postępów (wyników PB – *Personal Bests*). 

Projekt wykorzystuje **typy obiektowe** (z metodami i konstruktorem), **kolekcje** (Nested Tables), **referencje** (`REF`) oraz logikę zamkniętą w **pakietach** i **wyzwalaczach**.

---

## 🏗 Architektura danych

Zamiast wielu tabel łącznikowych system wykorzystuje **tabele zagnieżdżone (Nested Tables)** do przechowywania relacji 1:N i M:N bezpośrednio wewnątrz obiektów. Listy uczestników zajęć i obecnych na raportach są kolekcjami referencji do osób (`OSOBY_REF_TAB` – `TABLE OF REF Osoba_typ`), więc nie kopiują danych osobowych, tylko wskazują na wiersze w `OSOBA_TAB`.

### 1. Typy obiektowe

| Typ | Opis |
|---|---|
| **`TERMIN_TYP`** | Czas zajęć (godzina, minuta, dzień tygodnia, czas trwania). Konstruktor waliduje wartości. Metody: `czas_formatowany()`, `nazwa_dnia_tyg()`, `CZY_KONFLIKT()` (sprawdza nakładanie się terminów). |
| **`WYTRENOWANIE_TYP`** | Kondycja, masa, wzrost i data aktualizacji. Metoda `update_kondycja()` podnosi kondycję o 10, jeśli poprzednia aktualizacja była nie dawniej niż 5 dni temu, a w przeciwnym razie zmniejsza ją o połowę. |
| **`Osoba_typ`** | Zawodnik / trener / kadra, wraz z kolekcjami występów, dyscyplin i wyników PB. Metoda `PelneImie()`. |
| **`MIEJSCE_TYP`** | Miejsce treningowe z maksymalną pojemnością. |
| **`AKTYWNOSCI_TYP`** | Trening, zajęcia lub masaż: termin, cykliczność, lista uczestników, `REF` do miejsca, flaga odbycia. |
| **`RAPORT_OBECNOSCI`** | Raport z zajęć: `REF` do aktywności, lista obecnych, uwagi trenera. |
| **`Dyscyplina_typ`, `PB_Wynik_typ`, `Wystepy_typ`** | Dyscypliny, życiówki (jeden obiekt = jeden rok) i występy zawodnika. |

### 2. Tabele

| Tabela | Opis |
|---|---|
| **`MIEJSCA_TAB`** | Słownik miejsc, bez tabel zagnieżdżonych. |
| **`OSOBA_TAB`** | Zawodnicy, trenerzy i kadra. Tabele zagnieżdżone: `Wystepy`, `Dyscypliny`, `Wyniki_dyscyplin`. Ma klucz obcy do samej siebie (trener), ograniczenie na flagę `Active` oraz unikalność (Imię + Nazwisko + Data urodzenia). |
| **`AKTYWNOSCI_TAB`** | Treningi i zajęcia, z `REF` do miejsca. Tabela zagnieżdżona: `Lista_osob`. |
| **`RAPORTY_TAB`** | Raporty obecności. Tabela zagnieżdżona: `LISTA_OBECNYCH`. |

---

## ⚙️ Logika biznesowa

### Wyzwalacze

| Trigger | Działanie |
|---|---|
| `Check_Data_Urodzenia` | Blokuje dodanie lub zmianę osoby młodszej niż 7 lat. |
| `TR_AktywneUbezpieczenie` | Zawodnik nie może zostać dodany ani zaktualizowany z przeterminowanym ubezpieczeniem. |
| `update_kondycja_after_insert` | Po dodaniu raportu obecności wywołuje `update_kondycja()` dla każdego obecnego zawodnika i zapisuje nowy poziom wytrenowania. |

### Reguły sprawdzane poza wyzwalaczami

- **Unikalność osoby** (Imię + Nazwisko + Data urodzenia) – ograniczenie tabeli.
- **Poprawność terminu** – konstruktor `TERMIN_TYP`.
- **Limit 5 zawodników na trenera, limit 5 dyscyplin na zawodnika, brak duplikatów występów** – walidacje w pakiecie `OBSLUGA_ZAWODNIKA`.
- **Pojemność miejsca i kolizje zawodników w czasie** – walidacje w pakiecie `TERMINARZ`.

---

## 📦 Pakiety

| Pakiet | Zakres |
|---|---|
| **`OBSLUGA_ZAWODNIKA`** | Obsługa zawodników: dodawanie, edycja i usuwanie, zmiana statusu, kondycji i ubezpieczenia, zarządzanie występami, dyscyplinami i rekordami życiowymi (PB, z podziałem na lata) oraz wyświetlanie danych zawodnika. |
| **`TERMINARZ`** | Harmonogram: dodawanie i usuwanie aktywności oraz miejsc. Pilnuje pojemności miejsc i kolizji terminów zawodników, a minione aktywności jednorazowe oznacza automatycznie jako odbyte. |
| **`TRENER`** | Raportowanie: tworzenie i usuwanie raportów obecności (zapis raportu uruchamia aktualizację kondycji) oraz statystyki obecności zawodnika. |
| **`WYSWIETLANIE`** | Prezentacja danych w konsoli (`DBMS_OUTPUT`): harmonogram, aktywności i uczestnicy, kondycja oraz lista zawodników. |

---

## 🚀 Instalacja

Skrypty należy wykonać **w podanej kolejności**:

1. `01_typy_obiektowe.sql` – typy obiektowe
2. `02_sekwencje_i_tabele.sql` – sekwencje i tabele
3. `03_wyzwalacze.sql` – wyzwalacze
4. `04_pakiety_specyfikacje.sql` – specyfikacje pakietów
5. `05_pakiety_ciala.sql` – ciała pakietów
6. *(Opcjonalnie)* `06_dane_startowe_i_testy.sql` – dane startowe i przykładowe testy działania systemu

## 🛠 Wymagania

- Oracle Database 12c lub nowsza
- Klient SQL (np. SQL Developer) z włączonym `SERVEROUTPUT`
