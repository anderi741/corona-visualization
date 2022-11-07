# CORONA

Concurrent Organism Recreation Of New Ailment (CORONA)
En simulering av virusspridning. Implementerad med aktörsmodellen i Elixir, och visualiserad i webbläsare med JavaScript.

## Kom igång

### Installera Elixir och Erlang
Installationsguide: [Installera Elixir och Erlang](https://elixir-lang.org/install.html)  
Kontrollera att du har Elixir i version 1.6 eller högre och Erlang i version 20 eller högre genom terminalkommandot:
`elixir -v`.

### Klona projektet
Klona projektet genom terminalkommandot: `git clone https://github.com/uu-dsp-os-ospp-2020/asterix.git` eller klicka på 'Clone or download'-knappen.

### Installera Hex
Hex är pakethanteraren för Erlangs ekosystem.  
Installeras med terminalkommandot: `cd source/ && mix local.hex`

### Installera Phoenix
Installeras med terminalkommandot: `mix archive.install hex phx_new 1.5.3`

### Installera Node.js
Laddas ned här: [Node.js](https://nodejs.org/en/download/)  
OBS. Phoenix kräver att du har Node.js i version 5.0.0 eller högre.  
Installera sedan relevanta node.js-paket med terminalkommandot: `cd assets/ && npm install && cd ..`

### Starta projektet
Hämta hem alla beroenden med terminalkommandot: `mix deps.get`  
Starta upp Phoenix-servern med terminalkommandot: `mix phx.server`  
Öppna din webbläsare och navigera till: `localhost:4000/start`  

### Dokumentation
För att komma åt dokumentationen så ställer du dig i source mappen och skriver `mix docs` i terminalen.  
Då skapas det en HTML-sida med all dokumentation som man kommer åt i `doc/index.html`

## Katalogstruktur
<pre>
.  
└───source  
    ├───assets
    |   ├───css  
    |   ├───js  
    |   └───static
    |       └───images  
    ├───config  
    ├───lib  
    |   ├───corona  
    |   |   └───backend  
    |   └───corona_web  
    |       ├───html
    |       ├───controllers
    |       └───channels
    ├───priv  
    └───test      
</pre>
