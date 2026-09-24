# 🏃 System Zarządzania Klubem Lekkoatletycznym (Oracle PL/SQL)

Obiektowo-relacyjna baza danych stworzona w języku **Oracle PL/SQL**, służąca do kompleksowego zarządzania klubem lekkoatletycznym. System obsługuje zawodników, trenerów, harmonogramy treningów (aktywności), miejsca treningowe oraz raportowanie obecności i postępów (wyników PB – *Personal Bests*).

Projekt wykorzystuje zaawansowane mechanizmy obiektowe bazy Oracle, w tym **typy obiektowe** (z metodami), **kolekcje** (Nested Tables), **referencje** (`REF`) oraz logikę zamkniętą w **pakietach** i **wyzwalaczach**.

---

## 🏗 Architektura danych: typy i tabele zagnieżdżone (Nested Tables)

Baza odchodzi od czysto relacyjnego modelu na rzecz obiektowo-relacyjnego. Zamiast tworzyć dziesiątki tabel łącznikowych, system powszechnie wykorzystuje **tabele zagnieżdżone (Nested Tables)** do przechowywania relacji jeden-do-wielu (1:N) i wiele-do-wielu (M:N) bezpośrednio wewnątrz obiektów.

### 1. Typy obiektowe (klasy)

| Typ | Opis |
|---|---|
| **`TERMIN`** | Przechowuje czas (godzina, minuta, dzień tygodnia, czas trwania). Posiada metody: `czas_formatowany()` (np. *"10:15, Wtorek"*), `nazwa_dnia_tyg()` (konwersja numeru dnia na nazwę), `CZY_KONFLIKT()` (sprawdza, czy dwa terminy na siebie nachodzą). |
| **`WYTRENOWANIE_TYP`** | Przechowuje parametry fizyczne i poziom wytrenowania. Metoda `update_kondycja()` dynamicznie przelicza poziom kondycji w zależności od częstotliwości aktualizacji/treningów. |
| **`MIEJSCE_TYP`** | Definiuje fizyczne miejsce (np. boisko, bieżnia) wraz z jego maksymalną pojemnością. |
| **`Dyscyplina_typ`, `PB_Wynik_typ`, `Wystepy_typ`** | Typy opisujące odpowiednio dyscypliny, życiówki i zawody zawodnika. |

### 2. Tabele główne i ich tabele zagnieżdżone

W projekcie występują **4 fizyczne tabele**, z czego 3 posiadają zagnieżdżone kolekcje:

#### `MIEJSCA_TAB` *(tabela obiektowa typu `MIEJSCE_TYP`)*
Nie posiada tabel zagnieżdżonych — jest to słownik obiektów.

#### `OSOBA_TAB` *(tabela obiektowa typu `Osoba_typ`)*
Reprezentuje zawodników, trenerów i kadrę zarządzającą. Zawiera 3 tabele zagnieżdżone:
- **`Wystepy`** (typu `Wystepy_tab`) – historia startów i zawodów.
- **`Dyscypliny`** (typu `DYSCYPLINA_TAB`) – uprawiane dyscypliny sportowe.
- **`Wyniki_dyscyplin`** (typu `PB_Wynik_tab`) – rekordy życiowe w danym roku.

#### `AKTYWNOSCI_TAB` *(tabela obiektowa typu `AKTYWNOSCI_TYP`)*
Przechowuje treningi, zajęcia i masaże. Posiada relację do miejsca poprzez wskaźnik `REF MIEJSCE_TYP` (relacja bez kopiowania danych, tylko wskazanie na obiekt w `MIEJSCA_TAB`). Zawiera 1 tabelę zagnieżdżoną:
- **`Lista_osob`** (typu `OSOBY_ID_TAB`) – lista ID osób zapisanych na dane zajęcia.

#### `RAPORTY_TAB` *(tabela obiektowa typu `RAPORT_OBECNOSCI`)*
Przechowuje raporty z przeprowadzonych zajęć (obecność). Zawiera 2 tabele zagnieżdżone:
- **`LISTA_ZAPISANYCH`** (typu `OSOBY_ID_TAB`) – kto miał być.
- **`LISTA_OBECNYCH`** (typu `OSOBY_ID_TAB`) – kto rzeczywiście był.

---

## ⚙️ Logika biznesowa: wyzwalacze (Triggers)

System dba o spójność danych i reguły biznesowe za pomocą wyzwalaczy, które blokują niepoprawne operacje.

| Trigger | Działanie |
|---|---|
| `Check_Data_Urodzenia` | Blokuje dodanie zawodnika młodszego niż 7 lat. |
| `TR_MaxZawodnicyNaTrenera` | Pilnuje limitu zasobów ludzkich: jeden trener może mieć przypisanych maksymalnie 5 zawodników (zabezpiecza kolumnę `Przelozony`). |
| `TR_DyscyplinyZawodnika` | Ogranicza liczbę przypisanych dyscyplin (wewnątrz Nested Table `Dyscypliny`) do maksymalnie 5 na jednego zawodnika. |
| `TR_AktywneUbezpieczenie` | Waliduje datę w kolumnie `Koniec_ubezpieczenia`. Zawodnik nie może zostać zaktualizowany ani dodany, jeśli jego ubezpieczenie jest przeterminowane. |
| `TR_UniqueOsoba` | Emuluje unikalny klucz złożony (Imię + Nazwisko + Data urodzenia). Zapobiega dodaniu duplikatu osoby. |
| `TR_UniqueWystep` | Sprawdza unikalność danych wewnątrz tabeli zagnieżdżonej — zapobiega sytuacji, w której zawodnik miałby wpisane dwa takie same występy (ta sama nazwa, miejscowość, konkurencja). |
| `update_kondycja_after_insert` | Kluczowy trigger automatyzacji. Po dodaniu raportu z obecnościami (`INSERT` na `RAPORTY_TAB`) odczytuje, kto z zawodników był na treningu, wywołuje obiektową metodę `update_kondycja()` dla każdego z nich i podnosi im poziom wytrenowania w `OSOBA_TAB`. |

---

## 📦 Pakiety (Packages) – moduły systemu

Cała logika operacyjna i interfejs dla aplikacji zewnętrznych została podzielona na 4 dedykowane pakiety PL/SQL.

### 1. `OBSLUGA_ZAWODNIKA`
Moduł kadrowy i sportowy (obsługa tabeli `Osoba_tab`).

- **`DodajZawodnika`, `UsunZawodnika`, `AktualizujDaneZawodnika`** – podstawowy moduł CRUD.
- **`ZmienStatusZawodnika`** – włączanie/wyłączanie (np. po kontuzji, opuszczeniu klubu).
- **`DodajWystep`, `DodajDyscypline`** – zarządzanie historią startów.
- **`AktualizujPB`** – dynamiczna aktualizacja rekordów (Personal Bests) z podziałem na roczniki. Jeśli dany rok nie ma jeszcze rekordu, procedura tworzy nowy wiersz w tabeli zagnieżdżonej, jeśli ma – nadpisuje istniejący.
- **Funkcje czytające:** `PobierzSzczegolyZawodnika`, `WyswietlWystepyZawodnika`, `WyswietlWynikiZawodnika`.

### 2. `TERMINARZ`
Rozbudowany silnik rezerwacyjny pilnujący konfliktów i miejsc (obsługa `Aktywnosci_tab`).

**Walidacje konfliktów:**
- **`ZAJETE_MIEJSCE`** – sprawdza, czy w danym czasie i miejscu na obiekcie (np. boisku) nie zostanie przekroczony limit pojemności (`MAX_OSOB`). Oblicza całkowitą liczbę zapisanych w tym terminie osób.
- **`ZAJETY_ZAWODNIK`** – przeszukuje listy uczestników na konkretny termin. Jeśli choć jeden z podanych zawodników ma już inny trening nakładający się w czasie, odrzuca rejestrację.

**Automatyzacja:**
- **`CZYSZCZENIE_AKTYWNOSCI`** – aktualizuje flagę `ODBYTE = 1` dla treningów, których data i godzina względem bieżącego czasu systemowego (`SYSDATE`) minęła. Oczyszcza terminy, blokując przypisywanie do historii.

**Zarządzanie:** `Dodaj_Aktywnosc`, `Dodaj_Miejsce`, usuwanie obiektów.

### 3. `TRENER`
Moduł obsługujący realizację treningów (raportowanie).

- **`DODAJ_RAPORT`** – konwertuje zrealizowaną aktywność w raport. Przenosi listę zaplanowanych zawodników i weryfikuje ich obecność (co wyzwala trigger aktualizujący kondycję zawodników).
- **`WYSWIETL_OBECNOSCI_ZAWODNIKA`** – generuje statystyki (liczba obecności do nieobecności) dla wybranego sportowca.

### 4. `WYSWIETLANIE`
Funkcje pomocnicze do prezentacji danych poprzez konsolę (z użyciem `DBMS_OUTPUT`).

- Wyświetla złożone struktury (np. `WYSWIETL_LISTE` do rzutowania obiektów i kolekcji na jeden ciąg znaków za pomocą funkcji agregującej `LISTAGG`).
- Sortowanie i filtrowanie aktywności po zawodniku, statusie przeterminowania, cykliczności i dniu tygodnia.
- Wyciąganie szczegółów kondycji fizycznej (wzrost, masa, aktualna kondycja obliczona z funkcji obiektu).

---

## 🚀 Instalacja i konfiguracja (Deployment)

Aby wdrożyć projekt w bazie Oracle, należy **bezwzględnie zachować kolejność** wykonywania skryptów. Projekt został rozbity na 6 plików:

1. **`01_typy_obiektowe.sql`** – inicjalizacja klas i definicji struktur.
2. **`02_sekwencje_i_tabele.sql`** – tworzenie instancji tabel (w tym tabel zagnieżdżonych).
3. **`03_wyzwalacze.sql`** – implementacja reguł walidacyjnych blokujących błędne inserty/update'y.
4. **`04_pakiety_specyfikacje.sql`** – stworzenie nagłówków interfejsów PL/SQL.
5. **`05_pakiety_ciala.sql`** – kompilacja logiki silnika bazy.
6. *(Opcjonalnie)* **`06_dane_startowe_i_testy.sql`** – wypełnia bazę przykładowym trenerem, miejscami oraz prezentuje manualne wywołania funkcji (tworzenie zawodnika, rejestracja wyników, sprawdzanie logiki triggerów i harmonogramowania).
---

## 🛠 Wymagania

- Oracle Database (zalecane 12c lub nowsze — wsparcie dla `NONEDITIONABLE`, konstruktorów obiektowych, `NESTED TABLE`).
- Klient SQL (np. SQL Developer).
