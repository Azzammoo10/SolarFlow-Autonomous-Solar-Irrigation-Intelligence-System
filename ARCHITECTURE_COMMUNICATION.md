# Architecture de Communication - SolarFlow (Simulation Proteus)

Ce document détaille le flux de données entre la simulation électronique (Proteus) et l'interface utilisateur (Dashboard Web).

## 1. Vue d'ensemble du Flux de Données

Le système fonctionne selon un modèle en cascade où les données circulent de la simulation vers l'utilisateur final :

`[Arduino Proteus] -> [COMPIM] -> [Port COM Virtuel] -> [Backend Python] -> [Socket.IO] -> [Dashboard Web]`

---

## 2. Analyse Approfondie par Composant

### A. Firmware Arduino (`firmware/PFA-2.ino`)
L'Arduino agit comme un concentrateur de capteurs. Il lit les valeurs analogiques/numériques et les formate en une chaîne de caractères structurée.
*   **Protocole** : ASCII via Série.
*   **Format type** : `T:24.5|H:62|L:450|S:30` (Température, Humidité, Lumière, Sol).
*   **Fréquence** : Envoi toutes les 1000ms à 2000ms.

### B. Le Pont de Simulation (Proteus COMPIM)
Le composant **COMPIM** dans Proteus sert d'interface physique virtuelle. 
*   Il convertit les signaux logiques de la simulation en données série réelles sur le système d'exploitation.
*   **Configuration cruciale** : Baud Rate (9600) et Port Physique (ex: COM2).

### C. Backend Flask (`backend/app.py`)
Le backend est le "cerveau" de l'application. Il remplit trois rôles majeurs :
1.  **Ecoute (Listener)** : Via un thread dédié, il surveille le port COM partenaire (ex: COM3) pour ne jamais manquer une donnée.
2.  **Interprète (Parser)** : Il décompose la chaîne de caractères brute en un objet JSON structuré.
3.  **Diffuseur (Broadcaster)** : Dès qu'une donnée valide est reçue, elle est envoyée via **Socket.IO** à tous les clients connectés.

### D. Interface Temps-Réel (`frontend/index.html`)
Le Dashboard n'attend pas d'être interrogé, il est "notifié" par le serveur.
*   **Socket.IO Client** : Capte l'événement `sensor_update`.
*   **Mise à jour DOM** : Injecte les valeurs dans les jauges et les graphiques de manière fluide.

---

## 3. Avantages de cette Architecture

1.  **Indépendance du Matériel** : Que l'Arduino soit réel ou simulé dans Proteus, le Backend et le Frontend restent identiques.
2.  **Faible Latence** : L'utilisation de Socket.IO permet une réactivité quasi-instantanée (utile pour surveiller une surchauffe critique).
3.  **Persistence** : Parallèlement à l'affichage, les données sont archivées dans une base SQLite pour générer des graphiques historiques.

---

## 4. Configuration Requise pour Proteus

Pour faire fonctionner ce système, l'utilisateur doit disposer d'un émulateur de port série (ex: **Virtual Serial Port Emulator**) créant une paire de ports liés (COM2 <-> COM3).
