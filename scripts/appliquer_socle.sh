#!/usr/bin/env bash
# Applique le socle qualité Mathilde-Team à un dépôt créé depuis modele-depot :
#   - branche `dev` créée depuis `main` si absente ;
#   - protections de `main` et `dev` appliquées depuis .github/branch-protection/*.json.
#
# Usage (administrateur du dépôt, gh authentifié) :
#   scripts/appliquer_socle.sh Mathilde-Team/<depot>
#
# À relancer après toute modification des règles versionnées. Idempotent.
set -euo pipefail

depot="${1:?usage : $0 <owner>/<depot>}"
regles="$(cd "$(dirname "$0")/.." && pwd)/.github/branch-protection"

defaut="$(gh api "repos/$depot" --jq .default_branch)"
if [ "$defaut" != "main" ]; then
  echo "Branche par défaut « $defaut » : le socle attend « main »." >&2
  exit 1
fi

if gh api "repos/$depot/branches/dev" > /dev/null 2>&1; then
  echo "dev : déjà présente"
else
  sha="$(gh api "repos/$depot/git/ref/heads/main" --jq .object.sha)"
  gh api -X POST "repos/$depot/git/refs" -f ref=refs/heads/dev -f sha="$sha" > /dev/null
  echo "dev : créée depuis main ($sha)"
fi

for branche in main dev; do
  gh api -X PUT "repos/$depot/branches/$branche/protection" --input "$regles/$branche.json" > /dev/null
  echo "$branche : protection appliquée ($regles/$branche.json)"
done

echo "Socle appliqué à $depot. Vérification : workflow « Protection des branches »."
# Rappel de la règle de couverture (SOCLE.md §4, Mathilde-Team/.github#9) :
# elle n'est pas appliquée par ce script, mais par le job Qualité du dépôt.
echo "Couverture : seuil bloquant 95 % (branches comprises), déclaré une fois dans pyproject.toml"
echo "  ([tool.coverage.report] fail_under). Dépôt existant sous 95 % : fail_under = mesure du jour,"
echo "  relevé à chaque PR de tests jusqu'à 95 ; palier et date cible dans l'issue de suivi."
