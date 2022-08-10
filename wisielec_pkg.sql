create or replace PACKAGE wisielec_pkg IS

TYPE litery_array IS TABLE OF VARCHAR2(1 CHAR) ;
t_litery litery_array := litery_array(); -- tablica wybranych liter do sprawdzenia powtorzen


v_flag_losowanie    BOOLEAN := FALSE;   -- flaga do losowanie hasla, FALSE losuje nowe  haslo
v_haslo_id          NUMBER;             -- id hasla z tabalie hasla
v_haslo             VARCHAR2(30 CHAR);  -- string wylosowanego hasla z tabeli hasla
v_haslo_wylosowane  VARCHAR2(30 CHAR);  -- haslo zakryte z aktualnym postepem
v_counter           NUMBER := 0;        -- licznik skuch(max 9)
v_counter_p         NUMBER := 0;        -- licznik prob;
v_haslo_string      VARCHAR2(4000);     -- string wylosowanego hasla z tabeli haslo wylosowane (aktualny postep)
v_kategoria         VARCHAR2(15 CHAR);  -- kategoria hasla
v_start             VARCHAR2(30);       -- rozpoczecie rozgrywki    

-- Procedura do podawania liter, pierwsza litera losuje haslo
PROCEDURE podaj_litere(p_litera VARCHAR2);

-- Procedura do ogadniecia hasla, nalezy wpisac znaki oddzielajaca jezeli wystepuja w hasle
-- tj. kropka, przecinek, wykrzyknik itp. 

PROCEDURE odgadnij_haslo(p_haslo VARCHAR2);

-- funkcja do liczenia czasu rundy
FUNCTION licznik_czasu (p_start IN VARCHAR2) 
RETURN INTERVAL DAY TO SECOND;

-- funkcja do zmian liter w zakrytym hasle
FUNCTION zmiana_litery (p_string VARCHAR2, p_litera VARCHAR2, p_pozycja NUMBER)
RETURN VARCHAR2;

END wisielec_pkg;
/

create or replace PACKAGE BODY wisielec_pkg IS
TYPE litery_array IS TABLE OF VARCHAR2(1 CHAR) ;

-- Procedury
PROCEDURE podaj_litere(p_litera VARCHAR2) IS
    v_ilosc_hasel       NUMBER;             -- zmienna do pobrania iloscie hasel z tabeli hasla
    v_leng_haslo        NUMBER;             -- zmienna do pobrania dlugosci hasla wylosowanego 
    v_litera_hasla      VARCHAR2(1 CHAR);   -- zmienna do sprawdzania pojedynczych liter w hasle
    v_flag_litera       BOOLEAN := FALSE;   -- flaga do sprawdzenia czy litera jest w hasle
    v_wisielec_string   VARCHAR2(4000);     -- aktualny stan wisielca z tabeli wisielec    
    BEGIN 
        -- Losowanie hasla
        IF v_flag_losowanie = FALSE THEN
            -- pobranie ilosci hasel do wylosowania
            SELECT COUNT(*) INTO v_ilosc_hasel FROM hasla; 
            -- losowanie hasla
            SELECT haslo_id INTO v_haslo_id FROM hasla 
            WHERE haslo_id = (SELECT TRUNC(dbms_random.value(1,v_ilosc_hasel)) FROM DUAL); 
            -- Tworzenie zakrytego hasla
            SELECT REGEXP_REPLACE(haslo, '\w', '*') INTO v_haslo_wylosowane FROM hasla WHERE haslo_id = v_haslo_id;
            -- Zmiana flagi globalnej w celu unikniecia ponownego losowania
            v_flag_losowanie := TRUE;           
            -- licznik rozpoczecia
            v_start := TO_CHAR(sysdate, 'yyyy-mm-dd hh24:mi:ss');
        END IF;        
          -- Pobranie dlugosci wylosowanego hasla, hasla(string) oraz kategorii 
            SELECT length(haslo), haslo, kategoria INTO v_leng_haslo, v_haslo, v_kategoria FROM hasla WHERE haslo_id = v_haslo_id;
        
        v_flag_litera    := FALSE;
        t_litery.EXTEND();      
        
        -- sprawdzenie czy litera juz byla typowana
        FOR i IN t_litery.first..t_litery.last
        LOOP
            IF lower(t_litery(i)) = lower(p_litera) THEN
                dbms_output.put_line(p_litera||' już była wybierana');  
                RETURN;                    
            END IF; 
        END LOOP;
        
        v_counter_p := v_counter_p +1;
        t_litery(v_counter_p) := lower(p_litera);
        
    -- REGEXP_LIKE(LOWER(p_litera), '[a-z]') 
        -- Sprawdzenie czy wybrany znak jest litera alfabetu polskiego
        IF LOWER(p_litera) IN ('a', 'ą', 'b', 'c', 'ć', 'd', 'e', 'ę', 'f', 'g', 'h', 'i', 'j','k'
       , 'l', 'ł', 'm', 'n', 'ń','o', 'ó', 'p',  'r', 's', 'ś', 't', 'u'
       ,  'w',  'y', 'z', 'ź', 'ż') THEN
            dbms_output.put_line('Wybrana litera to   '||p_litera);     
        ELSE
            dbms_output.put_line('To nie jest litera'); 
            RETURN;            
        END IF;
    
        
        -- Sprawdzenie litery w zakrytym hasle
        FOR i IN 1 .. v_leng_haslo
        LOOP
        SELECT substr(haslo,i,1) INTO v_litera_hasla FROM hasla WHERE haslo_id = v_haslo_id;    
            IF v_litera_hasla = UPPER(p_litera) THEN
                 --  Nadpisanie litery w danej pozycji jezeli pasuje;
                  v_haslo_wylosowane :=  zmiana_litery(v_haslo_wylosowane,UPPER(p_litera), i) ;
				  -- Ustawienie flagi, ze litera wystapila
                 v_flag_litera := TRUE;                  
            END IF;   
        END LOOP;
         -- Ustawienie flagi jeśli litera jest zła, zwiekszenie licznika
        IF   v_flag_litera = FALSE THEN
            v_counter := v_counter+1;         
        END IF;         
        -- pobranie aktualnego wisielca
        SELECT wisielec INTO v_wisielec_string FROM wisielec WHERE wisielec_id = v_counter;
           -- Koniec gry po 9 próbach
        IF v_counter = 9 THEN
            dbms_output.put_line('--- GAME OVER ---');
            dbms_output.put_line('Zostałeś Powieszony!');
            dbms_output.put_line(v_wisielec_string); 
            -- diadaj rekord do tabeli hi_scores z porazka
            INSERT INTO hi_scores (USERNAME, HASLO_ID, HASLO, KATEGORIA, PORA, PROBY, CZAS, WYNIK, skuchy)
            VALUES (user, v_haslo_id, v_haslo_wylosowane, v_kategoria, sysdate, v_counter_p, licznik_czasu(v_start), UPPER('PORAŻKA'),v_counter);
            -- zerowanie wartosci
            v_flag_losowanie    := FALSE;
            v_counter           := 0;
            v_counter_p         := 0;
            t_litery.DELETE;           
            COMMIT;
            RETURN;
        END IF;   
        
        -- Konsola
        dbms_output.put_line('HASLO:  '||v_haslo_wylosowane||'  KATEGORIA: '||v_kategoria); 
        dbms_output.put_line('Liczba prób: '||v_counter_p);  
       -- dbms_output.put_line('Liczba skuch: '||v_counter); 
        dbms_output.put_line(v_wisielec_string);          
        
    END podaj_litere;
  
PROCEDURE odgadnij_haslo(p_haslo VARCHAR2) IS
    BEGIN
        -- sprawdzenie czy haslo jest wylosowane
        IF v_flag_losowanie = FALSE THEN
            dbms_output.put_line('Haslo nie zostalo wylosowane. Podaj litere');
            RETURN;
        END IF;
        
        IF lower(p_haslo) = lower(v_haslo) AND v_flag_losowanie = TRUE THEN
            -- doadaj rekord do tabeli hi_scores z wygrana
            INSERT INTO hi_scores (USERNAME, HASLO_ID, HASLO, KATEGORIA, PORA, PROBY, CZAS, WYNIK, skuchy)
            VALUES (user, v_haslo_id, v_haslo_wylosowane, v_kategoria, sysdate, v_counter_p, licznik_czasu(v_start), UPPER('WYGRANA'),v_counter);
            -- zerowanie wartosci            
            v_flag_losowanie    := FALSE;
            v_counter           := 0;
            v_counter_p         := 0;
            t_litery.DELETE;
            dbms_output.put_line('--- GAME OVER ---');
            dbms_output.put_line('Zostałeś Ocalony!');
            COMMIT;
            RETURN;
        ELSE
            dbms_output.put_line('to jest niepoprawne hasło');
        END IF;    
    END odgadnij_haslo;

-- Funkcje
FUNCTION licznik_czasu (p_start IN VARCHAR2) 
RETURN INTERVAL DAY TO SECOND IS
    v_interval INTERVAL DAY(0) TO SECOND(0);
    BEGIN         
         SELECT  TO_TIMESTAMP(TO_CHAR(sysdate, 'yyyy-mm-dd hh24:mi:ss'), 'yyyy-mm-dd hh24:mi:ss') -
         TO_TIMESTAMP(TO_CHAR(TO_DATE(p_start , 'yyyy-mm-dd hh24:mi:ss'), 'yyyy-mm-dd hh24:mi:ss'),'yyyy-mm-dd hh24:mi:ss')   
        INTO v_interval FROM DUAL;
        RETURN v_interval;
    END licznik_czasu;

FUNCTION zmiana_litery (p_string VARCHAR2, p_litera VARCHAR2, p_pozycja NUMBER)
RETURN VARCHAR2 IS 
    v_string VARCHAR2(4000);
    BEGIN
        -- pobranie hasla do wytypowanej pozycji
        v_string := SUBSTR(p_string, 1 , p_pozycja -1);
        -- dodanie litery w danej pozycji do hasla
        v_string := CONCAT(v_string, SUBSTR(p_litera,1,1));
        -- dodanie reszty hasla od pozycji dodanmej litery
        v_string := CONCAT(v_string, SUBSTR(p_string, p_pozycja+1));    
        RETURN v_string;
    END zmiana_litery;
    
END wisielec_pkg;
/