# NetworkOverflow - Herný koncept

## Zhrnutie
NetworkOverflow je 2D strategická puzzle hra, v ktorej hráč buduje káblovú infraštruktúru medzi servermi a počítačmi rôznych farieb. Cieľom je udržať čo najvyšší počet aktívnych pripojení, reagovať na postupne rastúcu mapu kancelárií a zvládať tlak na efektívne rozvádzanie siete. Hra kombinuje rýchle rozhodovanie, priestorové plánovanie a správu rizika cez systém pomeru pripojených zariadení.

## Dizajnové piliere
- **Čitateľná sieťová logika**  
  Hráč musí jasne vidieť, ktoré káble vedú kam, ktoré zariadenia sú pripojené a kde vzniká problém.
- **Napätie z rastúcej komplexity**  
  S každou novou kanceláriou pribúdajú nové trasy, prekážky a konflikty medzi farbami.
- **Jednoduché ovládanie, ťažké rozhodovanie**  
  Ovládanie je zámerne jednoduché (kreslenie a mazanie káblov), no rozhodnutia o trase majú dlhodobé dôsledky.
- **Dôraz na optimalizáciu**  
  Najlepší výsledok nevzniká náhodou, ale dôsledným plánovaním trás, vetvením a správnym poradím akcií.
- **Rýchla spätná väzba**  
  Hráč okamžite vidí, či je PC pripojené, a tým pádom môže adaptovať stratégiu bez zbytočného čakania.

## Pribeh

### Prostredie
Hráč pôsobí ako sieťový technik v dynamicky rastúcom technologickom komplexe. Každá kancelária je samostatný modul budovy, ktorý sa postupne pripája k existujúcej štruktúre. V prostredí plnom stien, úzkych chodieb a rôznych farebných sietí je nutné zachovať pripojenie celej infraštruktúry.

### Hlavný dej
1. **Začiatok** – hráč dostane prvú kanceláriu so serverom.
2. **Rast infraštruktúry** – pribúdajú nové počítače a nové farebné segmenty siete.
3. **Rozšírenie komplexu** – mapa sa rozrastá o ďalšie kancelárie, čím rastie náročnosť trasovania.
4. **Kritický bod** – zlyhanie pomeru pripojení v niektorej farbe vyvolá kolaps siete.
5. **Vyhodnotenie** – po Game Over sa výsledok zapíše do leaderboardu (dátum, score, čas).

### Svet
Svet hry je abstraktný: modulárne kancelárie, centrálne servery, koncové pracovné stanice a pevné prekážky. Farebné segmenty reprezentujú oddelené logické siete, ktoré sa nesmú miešať.

## Gameplay štruktúra

### Herná slučka
1. **Spawn PC / kancelárie**  
   Hra periodicky pridáva nové PC; po naplnení limitu v aktuálnej kancelárii sa spawne nová kancelária.
2. **Analýza situácie**  
   Hráč vyhodnotí dostupné porty, farby, úzke miesta a potenciálne kolízie trás.
3. **Budovanie siete**  
   Hráč ťahom myši kreslí káble podľa aktívnej farby, prípadne ich maže a prerába.
4. **Validácia pripojenia**  
   Systém priebežne prepočítava, ktoré PC sú napojené na server rovnakej farby.
5. **Kontrola stability**  
   Po grace periode sa sleduje pomer pripojených PC v každej farbe; pri poklese pod limit hra končí.
6. **Score a opakovanie**  
   Po Game Over sa uloží výsledok a hráč môže skúsiť nový run.

### Ovládanie
- **LMB (ľavé tlačidlo myši)** – kreslenie káblov aktívnej farby
- **RMB (pravé tlačidlo myši)** – mazanie káblov aktívnej farby
- **1-4** – priama voľba farby kábla
- **Q / E** – prepínanie farby dozadu / dopredu
- **ESC** – návrat do hlavného menu