#!/usr/bin/env python3
"""
Générateur de clés de licence Cheque Manager Pro (réservé au vendeur).

Prérequis : pip install cryptography
Le fichier cle_privee_vendeur.txt doit rester secret (jamais dans le dépôt).

Exemples :
    python generer_licence.py K7Q2-M9XD annuelle
    python generer_licence.py K7Q2-M9XD mensuelle
    python generer_licence.py K7Q2-M9XD vie
    python generer_licence.py K7Q2-M9XD annuelle --cle C:\\chemin\\cle_privee_vendeur.txt
"""
import argparse
import base64
import datetime as dt
import pathlib
import sys

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
ORIGINE = dt.date(2026, 1, 1)
FORMULES = {"annuelle": (1, 365), "vie": (2, 0), "mensuelle": (3, 31)}


def b32_encoder(octets: bytes) -> str:
    out, buf, bits = [], 0, 0
    for o in octets:
        buf = (buf << 8) | o
        bits += 8
        while bits >= 5:
            out.append(ALPHABET[(buf >> (bits - 5)) & 31])
            bits -= 5
    if bits:
        out.append(ALPHABET[(buf << (5 - bits)) & 31])
    return "".join(out)


def b32_decoder(texte: str) -> bytes:
    propre = "".join(c for c in texte.upper() if c in ALPHABET)
    out, buf, bits = [], 0, 0
    for c in propre:
        buf = ((buf << 5) | ALPHABET.index(c)) & 0xFFFFFF
        bits += 5
        if bits >= 8:
            out.append((buf >> (bits - 8)) & 0xFF)
            bits -= 8
    return bytes(out)


def generer(code_appareil: str, formule: str, cle_privee_b64: str, jours=None, aujourd_hui=None):
    appareil = b32_decoder(code_appareil)
    if len(appareil) != 5:
        raise ValueError("Code appareil invalide (8 caractères, ex. K7Q2-M9XD)")
    code, duree = FORMULES[formule]
    if jours is not None:
        duree = jours
    aujourd_hui = aujourd_hui or dt.date.today()
    if duree == 0:
        expiration_jours, expiration = 0, None
    else:
        expiration = aujourd_hui + dt.timedelta(days=duree)
        expiration_jours = (expiration - ORIGINE).days
    payload = bytes([1]) + appareil + expiration_jours.to_bytes(2, "big") + bytes([code])
    cle = Ed25519PrivateKey.from_private_bytes(base64.b64decode(cle_privee_b64.strip()))
    brut = b32_encoder(payload + cle.sign(payload))
    groupes = "-".join(brut[i:i + 6] for i in range(0, len(brut), 6))
    return groupes, expiration


def main():
    p = argparse.ArgumentParser(description="Générer une clé de licence Cheque Manager Pro")
    p.add_argument("code_appareil", help="Code affiché dans l'application (Paramètres > Licence)")
    p.add_argument("formule", choices=FORMULES.keys())
    p.add_argument("--jours", type=int, help="Durée personnalisée en jours (0 = à vie)")
    p.add_argument("--cle", default=str(pathlib.Path(__file__).with_name("cle_privee_vendeur.txt")),
                   help="Fichier de la clé privée du vendeur")
    a = p.parse_args()
    try:
        cle_privee = pathlib.Path(a.cle).read_text()
    except FileNotFoundError:
        sys.exit(f"Clé privée introuvable : {a.cle}")
    licence, expiration = generer(a.code_appareil, a.formule, cle_privee, a.jours)
    print("\nClé de licence pour l'appareil", a.code_appareil.upper())
    print("Formule :", a.formule, "| Expiration :", expiration.strftime("%d/%m/%Y") if expiration else "jamais")
    print("\n" + licence + "\n")


if __name__ == "__main__":
    main()
