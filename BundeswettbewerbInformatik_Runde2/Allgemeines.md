# Allgemeines

**Teilnahme-ID: 81342**

**Bearbeiter: Raphael Porseche**

---

### Details

- Getestet und Geschrieben auf Linux (Zorin OS 17.3)
- Odin version: `dev-2026-03:1a5126c6b`
- Julia version: `1.11.7+0.x64.linux.gnu`
- Spezifikationen für Testing
    - **Prozessor:** 13th Gen Intel® Core™ i7-13700K × 24
    - **Speicher:** 64GB DDR5


### Programmausführung

Beide Probleme wurden mit Odin gelöst. Odin ist eine kompilierte Programmiersprache. Um beide Programme auszuführen muss das Arbeitsverzeichnes jeweils auf `Aufgabe2` und `Aufgabe3` liegen. Eine einfache Ausführung des Programms benötigt keine Odin-Installation (solange das Programm auf dem gleichem Betriebssystem ausgeführt wird). 

**Wichtig**: . Da das vorgegebene Ausgabenformat nicht die Evaluierung verschiedener Heuristiken ermöglicht, gibt "Aufgabe2" ein eigenes Ausgabenformat zurück. Um trotzdem die Anforderungen der Außgaben zu erreichen, haben wir ein Helfer-Skript erstellt, welches die selbstdefinierten Ausgaben in das benötigte Format bringt. Dieses benötigt eine `Julia` Installation (https://julialang.org/) und kann folgendermaßen ausgeführt werden. Sie erstellt eine neue Ausgabe im `ausgaben_formatted` Verzeichnis basierend auf den gleichnamigen Dateien in `eingaben` und `ausgaben`.

```
julia formatter.jl
```

##### Aufgabe2

Aufgabe2 kann auf verschiedener Weise ausgeführt werden:

`Option 1` (kein ALNS, keine genauen Strecken, nicht gespeichert)

```
./aufgabe2.bin
```

`Option 2` (ALNS mit $n Anzahl Versuchen, keine genaue Strecken, nicht gespeichert)

```
./aufgabe2.bin $n 
```

`Option 3` (ALNS mit $n Anzahl Versuchen, genaue Strecken, in `ausgaben` gespeichert)

```
./aufgabe2.bin to_file $n
```

Ist $n jemals 0, wird ALNS ignoriert. 

**Hinweis:** Während `Greedy` und `Greedy + 2-Opt` alle Beispiele in Millisekunden lösen können, braucht ALNS (besonders die `thorough` Version) sehr lange auf den großen Beispielen. Eine vollstänige Neukalkulierung mit mehreren Versuchen für das ALNS kann bis zu mehrere Stunden brauchen. Anweisungen, wie man das Programm mit oder ohne ALNS starten kann ist in `Allgemeines.pdf` vorzufinden. 

##### Aufgabe3

```
./aufgabe3.bin
```

### Selbst Kompilierung

Für eine eigene Kompilierung ist eine Installation von Odin benötigt (https://odin-lang.org/docs/install/). Um die Programme dann selbst zu kompilieren werden jeweils folgende Befehle gebraucht, die auch wieder im gleichen Arbeitsverzeichnis ausgeführt werden müssen. Mit den vorherigen Befehlen können die enstandenen Binärdateien dann ausgeführt werden.

##### Aufgabe2

```
odin build aufgabe2 -o:speed
```

##### Aufgabe3

```
odin build aufgabe3 -o:speed
```

