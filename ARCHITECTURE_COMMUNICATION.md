# Comment les données circulent dans SolarFlow
## Guide de communication entre le Dashboard, le Backend, et l'Arduino

---

## Vue d'ensemble — Le système en 3 blocs

```
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│                 │        │                 │        │                 │
│   ARDUINO /     │◄──────►│    BACKEND      │◄──────►│   DASHBOARD     │
│   PROTEUS       │        │   (Flask)       │        │  (Navigateur)   │
│                 │        │                 │        │                 │
│ Le "cerveau"    │        │ Le "traducteur" │        │ L'écran de      │
│ du matériel     │        │ intermédiaire   │        │ contrôle        │
└─────────────────┘        └─────────────────┘        └─────────────────┘

   Capteurs & moteurs         Ordinateur PC              Fenêtre Chrome
```

> Pense à ça comme une **chaîne téléphonique** :
> l'Arduino parle au Backend, le Backend parle au Dashboard.
> Ils ne se parlent jamais directement entre eux.

---

## Bloc 1 — L'Arduino / Proteus

### C'est quoi ?
L'Arduino est une **petite carte électronique** qui lit les capteurs physiques
(température, humidité, niveau d'eau...) et contrôle les actionneurs (pompe,
ventilateur, chauffage...).

**Proteus** est un logiciel qui **simule** l'Arduino sur ordinateur — exactement
comme si la vraie carte électronique était branchée.

### Ce qu'il fait toutes les 500ms (demi-seconde)
Il envoie un message texte contenant toutes les valeurs des capteurs.
Ce message ressemble à ça :

```
{"t":25.3, "h":62, "sol":58, "co2":42, "ldr":55, "res":78,
 "pompe":0, "vanne":0, "vent":0, "chauf":0, "ombre":1,
 "mode":"AUTO"}
```

**Traduction de ce message :**
| Code | Signification | Valeur dans l'exemple |
|---|---|---|
| `t` | Température en °C | 25.3°C |
| `h` | Humidité de l'air en % | 62% |
| `sol` | Humidité du sol en % | 58% |
| `co2` | Concentration CO₂ en % | 42% |
| `ldr` | Luminosité en % | 55% |
| `res` | Niveau du réservoir en % | 78% |
| `pompe` | Pompe active (1) ou non (0) | Éteinte |
| `vent` | Ventilateur actif (1) ou non (0) | Éteint |
| `ombre` | Ombrage actif (1) ou non (0) | **Allumé** |
| `mode` | Mode de fonctionnement | Automatique |

### Comment il envoie ce message ?
Via un **câble USB** (ou un port COM virtuel pour Proteus).
C'est comme un fil téléphonique entre l'Arduino et le PC.

---

## Bloc 2 — Le Backend (Flask)

### C'est quoi ?
C'est un **programme Python** qui tourne sur le PC en arrière-plan.
Tu ne le vois pas directement, mais il est indispensable.

Son rôle est d'être le **traducteur et gardien** entre l'Arduino et le Dashboard.

### Ce qu'il fait

```
         ARDUINO                    BACKEND                   DASHBOARD
            │                          │                          │
            │  Envoie données JSON      │                          │
            │ ─────────────────────►  │                          │
            │                          │  Redistribue en direct   │
            │                          │ ────────────────────────►│
            │                          │                          │
            │                          │◄─── Commande (ex: POMPE_ON)
            │◄─── Envoie sur câble USB │                          │
```

**3 tâches principales :**

1. **ÉCOUTER l'Arduino** — Il lit le câble USB en permanence.
   Dès qu'un nouveau message arrive, il le décode.

2. **DIFFUSER au Dashboard** — Il envoie immédiatement les données
   au navigateur via une connexion en temps réel (WebSocket).
   C'est comme un flux de télévision en direct.

3. **TRANSMETTRE les commandes** — Quand tu cliques sur "Allumer la pompe"
   dans le Dashboard, le Backend envoie la commande `POMPE_ON`
   à l'Arduino via le câble USB.

### Mode DEMO
Si aucun Arduino n'est branché, le Backend **génère de fausses données réalistes**
tout seul. Le Dashboard fonctionne exactement pareil — tu ne vois pas la différence.

---

## Bloc 3 — Le Dashboard (Navigateur web)

### C'est quoi ?
C'est la page web que tu ouvres dans Chrome/Firefox à l'adresse
`http://localhost:5000` (ou `http://127.0.0.1:5000`).

C'est l'**interface visuelle** — graphiques, chiffres, boutons.

### Ce qu'il affiche
Il reçoit les données du Backend et les affiche immédiatement :
- Les **chiffres** des capteurs se mettent à jour en direct
- Les **graphiques** s'allongent vers la droite au fil du temps
- Les **indicateurs de couleur** passent du vert (normal) au rouge (alerte)

### Ce qu'il envoie
Quand tu cliques sur un bouton (ex: activer le chauffage) :
1. Le Dashboard envoie `CHAUFF_ON` au Backend
2. Le Backend envoie `CHAUFF_ON` à l'Arduino
3. L'Arduino allume le chauffage
4. L'Arduino renvoie l'état mis à jour dans son prochain message
5. Le Dashboard affiche "Actif" sur le bouton Chauffage

---

## Le câble de communication : le Port COM

### En mode réel (Arduino physique)
```
Arduino ──── câble USB ──── PC (Port COM3 ou COM4...)
```
C'est un simple câble USB qui fait passer le texte JSON dans les deux sens.

### En mode Proteus (simulation)
Proteus ne peut pas utiliser un vrai câble USB.
On crée donc un **faux câble** entre deux logiciels grâce à **com0com** :

```
Proteus ──── Port COM10 ════════ Port COM11 ──── Backend Flask
             (côté Proteus)   (câble virtuel)   (côté Python)
```

`com0com` crée cette "autoroute virtuelle" entre les deux ports.
Ce que Proteus écrit sur COM10 arrive instantanément sur COM11, et vice-versa.

---

## Résumé en image

```
                    TOUTES LES 500 MILLISECONDES
                    ┌──────────────────────────────────────────────┐
                    │                                              │
  ┌──────────┐      │   ┌──────────┐      ┌──────────────────┐   │
  │ CAPTEURS │─────►│   │          │ JSON │                  │   │
  │          │      │   │ ARDUINO  │─────►│    BACKEND       │───┤───► DASHBOARD
  │Temp/Hum/ │      │   │    /     │      │    (Python)      │   │    (Navigateur)
  │Sol/CO2..│      │   │ PROTEUS  │◄─────│                  │◄──┤◄── Commandes
  └──────────┘      │   └──────────┘ CMD  └──────────────────┘   │   utilisateur
                    │         │                     │             │
                    │    Port COM USB          Port 5000          │
                    └──────────────────────────────────────────────┘
```

---

## Modes de fonctionnement

| Mode | Qui génère les données | Actionneurs contrôlables |
|---|---|---|
| **DEMO** | Le Backend (données simulées) | Oui, depuis le Dashboard |
| **AUTO** | L'Arduino (capteurs réels) | Non — l'Arduino décide seul |
| **MANUEL** | L'Arduino (capteurs réels) | Oui, depuis le Dashboard |
| **SIM** | L'Arduino (scénarios pré-définis) | Selon le scénario |

---

## En cas de problème

| Symptôme | Cause probable |
|---|---|
| Dashboard vide / pas de données | Backend non démarré |
| "Hors ligne" dans le Dashboard | Pas de connexion WebSocket |
| Données figées | Arduino/Proteus arrêté |
| Commandes ignorées | Mode AUTO actif (pas MANUEL) |
| Port COM introuvable | Driver com0com non installé |

---

*Document SolarFlow — Architecture de communication — Mai 2026*
