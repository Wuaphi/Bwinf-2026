# Bundeswettbewerb Informatik 2026

My Solutions for the **Bundeswettbewerb Informatik** Round 1 and Round 2.

**Participant ID:** 81342
**Author:** Raphael Porsche

---

## Languages & Tools

| Language | Version | Usage |
|----------|---------|-------|
| [Odin](https://odin-lang.org/) | `dev-2026-03:1a5126c6b` | Main solutions (Round 1 & 2) |
| [Julia](https://julialang.org/) | `1.11.7+0.x64.linux.gnu` | Junior tasks (Round 1), output formatting (Round 2) |
| [Raylib](https://www.raylib.com/) | via `vendor:raylib` | Visualization |

**Tested on:** Linux (Zorin OS 17.3)
**Hardware:** Intel Core i7-13700K, 64GB DDR5

---

## Repository Structure

```
BwinfRepo/
├── BundeswettbewerbInformatik_Runde1/
│   ├── Aufgabe1_drehfreudig/       # Rotation-friendly trees (Odin)
│   ├── Aufgabe2_choreograph/       # Choreography planning (Odin)
│   ├── Junioraufgabe1/             # Ball counting (Julia)
│   ├── Junioraufgabe2/             # Syllable separation (Julia)
│   └── *.pdf                       # Task descriptions
├── BundeswettbewerbInformatik_Runde2/
│   ├── Aufgabe2/                   # Watering robots / CVRP (Odin)
│   ├── Aufgabe3/                   # Supply chain routing (Odin)
│   ├── Allgemeines.md              # General notes & instructions
│   └── *.pdf, *.md                 # Task descriptions & write-ups
└── README.md
```

---

## Round 1

### Aufgabe 1: Drehfreudig

Parses tree structures from bracket notation, determines whether each tree is "rotation-friendly" (symmetric in partition sizes and depths when mirrored), and generates visual output.

**Documentation:** [`Aufgabe1.pdf`](BundeswettbewerbInformatik_Runde1/Aufgabe1.pdf)

**Source:** `Aufgabe1_drehfreudig/drehfreudig/Drehfreudig.odin`

**Run:**
```
cd BundeswettbewerbInformatik_Runde1/Aufgabe1_drehfreudig
odin build drehfreudig -o:speed
./drehfreudig.bin
```

### Aufgabe 2: Choreograph

Finds all valid choreography sequences that return dancers to their starting positions within a given time budget, then ranks them by number of figures, unique figures, and distance traveled.

**Documentation:** [`Aufgabe2.pdf`](BundeswettbewerbInformatik_Runde1/Aufgabe2.pdf)

**Source:** `Aufgabe2_choreograph/choreograph/choreograph.odin`

**Run:**
```
cd BundeswettbewerbInformatik_Runde1/Aufgabe2_choreograph
odin build choreograph -o:speed
./choreograph.bin
```

### Junioraufgabe 1: Ball Counting

Reads event schedules and finds the hour with the highest number of simultaneous balls across all days.

**Documentation:** [`Junioraufgabe1.pdf`](BundeswettbewerbInformatik_Runde1/Junioraufgabe1.pdf)

**Source:** `Junioraufgabe1/src/Junioraufgabe1.jl`

**Run:**
```
cd BundeswettbewerbInformatik_Runde1/Junioraufgabe1
julia src/Junioraufgabe1.jl
```

### Junioraufgabe 2: Syllable Separation

Implements two syllable separation algorithms for German text: Lars's rule-based approach and a custom approach using vowel nuclei, diphthong detection, and consonant cluster handling.

**Documentation:** [`Junioraufgabe2.pdf`](BundeswettbewerbInformatik_Runde1/Junioraufgabe2.pdf)

**Source:** `Junioraufgabe2/src/Junioraufgabe2.jl`

**Run:**
```
cd BundeswettbewerbInformatik_Runde1/Junioraufgabe2
julia src/Junioraufgabe2.jl
```

---

## Round 2

See [`Allgemeines.md`](BundeswettbewerbInformatik_Runde2/Allgemeines.md) for general notes, build instructions, and system details.

---

### Aufgabe 2: Gießroboter

A variant of the **Capacitated Vehicle Routing Problem (CVRP)**: place watering robots so their routes cover all trees within a battery limit, minimizing the number of robots.

**Documentation:** [`Aufgabe2.pdf`](BundeswettbewerbInformatik_Runde2/Aufgabe2.pdf) | [`Aufgabe2.md`](BundeswettbewerbInformatik_Runde2/Aufgabe2.md)

#### Heuristics

| Heuristic | Approach | Speed | Quality |
|-----------|----------|-------|---------|
| **Greedy** | Cheapest insertion with KD-tree spatial partitioning and edge caching | Fastest | Baseline |
| **Greedy + 2-Opt** | Greedy followed by local 2-Opt edge-swap improvement | Fast | Better |
| **ALNS fast** | Adaptive Large Neighborhood Search with Simulated Annealing (few iterations) | Medium | Good |
| **ALNS balanced** | ALNS with moderate iterations and patience | Slow | Very good |
| **ALNS thorough** | ALNS with extensive search (up to 1 hour time limit) | Slowest | Best |

**Source:** `Aufgabe2/aufgabe2/` (10 Odin files)

**Run (pre-compiled binary):**
```
cd BundeswettbewerbInformatik_Runde2/Aufgabe2

# Greedy only (no ALNS)
./aufgabe2.bin

# ALNS with n iterations
./aufgabe2.bin $n

# ALNS with n iterations, exact routes, saved to file
./aufgabe2.bin to_file $n
```

**Format output:**
```
julia formatter.jl
```

**Compile from source:**
```
cd BundeswettbewerbInformatik_Runde2/Aufgabe2/aufgabe2
odin build aufgabe2 -o:speed
```

### Aufgabe 3: Lieferkette

Finds shortest paths through a graph of factories belonging to different companies, visiting at least one factory per company in order, while accounting for a single potential factory strike. Uses dynamic programming with three cost modes and Dijkstra with early termination.

**Documentation:** [`Aufgabe3.pdf`](BundeswettbewerbInformatik_Runde2/Aufgabe3.pdf) | [`Aufgabe3.md`](BundeswettbewerbInformatik_Runde2/Aufgabe3.md)

**Source:** `Aufgabe3/aufgabe3/aufgabe3.odin`

**Run (pre-compiled binary):**
```
cd BundeswettbewerbInformatik_Runde2/Aufgabe3
./aufgabe3.bin
```

**Compile from source:**
```
cd BundeswettbewerbInformatik_Runde2/Aufgabe3/aufgabe3
odin build aufgabe3 -o:speed
```

---

## Compilation

Odin is required for compiling from source. Install it from [odin-lang.org](https://odin-lang.org/docs/install/).
All compilation commands must be run from the respective source directories. The pre-compiled `.bin` files (Linux x86_64) can be used without an Odin installation.
