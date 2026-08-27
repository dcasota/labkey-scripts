#!/usr/bin/env bash
# install-labkey-sleepdrive-lab.sh
#
# Student lab for Nature paper:
#   Wake-activated neuronal populations that regulate sleep drive
#   DOI 10.1038/s41586-026-10928-3  (Joo, Diester, Bitsikas, … Schier et al.)
#
# Downloads the 5 public Source Data Excel files (Figs 1–5), converts each
# sheet to CSV, imports Lists into LabKey, and installs an English student
# exercise path (wiki + hand-in list) similar to the V940 Evidence shelf.
#
set -euo pipefail

DATA_DIR="${LK_SLEEP_DIR:-$HOME/src/labkeySleepDriveLab}"
LK_IMPORT=0
LK_DRY_RUN=0
LK_INSECURE="${LK_INSECURE:-0}"
LK_URL="${LK_URL:-https://127.0.0.1:8443}"
LK_USER="${LK_USER:-}"
LK_PASSWORD="${LK_PASSWORD:-}"
LK_APIKEY="${LK_APIKEY:-}"
LK_PROJECT="${LK_PROJECT:-SleepDrive-Lab}"
LK_FOLDER="${LK_FOLDER:-Source Data Lab}"
LK_FORCE=0
LK_LANDING_ONLY=0
LK_MAX_ROWS="${LK_MAX_ROWS:-50000}"

PAPER_DOI="10.1038/s41586-026-10928-3"
PAPER_URL="https://www.nature.com/articles/s41586-026-10928-3"
PAPER_TITLE="Wake-activated neuronal populations that regulate sleep drive"
ATLAS_URL="https://sleep-wake-atlas.scicore.unibas.ch/"

usage() {
  cat <<EOF
Nature sleep-drive student lab → LabKey (DOI ${PAPER_DOI})

  $0 --dry-run
  $0 --import --url https://127.0.0.1:8443 --user admin --password secret --insecure

Options:
  --import          download, convert, import lists, install student path
  --landing-only    re-apply wiki + student hand-in (lists already present)
  --force           recreate student lists
  --dir PATH        data root (default: $DATA_DIR)
  --project NAME    LabKey project (default: $LK_PROJECT)
  --folder NAME     working folder under project (default: $LK_FOLDER)
  --url URL         LabKey base URL
  --user / --password / --apikey
  --insecure        skip TLS verify
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --import)       LK_IMPORT=1; shift ;;
    --landing-only) LK_LANDING_ONLY=1; LK_IMPORT=1; shift ;;
    --dry-run)      LK_DRY_RUN=1; shift ;;
    --force)        LK_FORCE=1; shift ;;
    --dir)          DATA_DIR="$2"; shift 2 ;;
    --project)      LK_PROJECT="$2"; shift 2 ;;
    --folder)       LK_FOLDER="$2"; shift 2 ;;
    --url)          LK_URL="$2"; shift 2 ;;
    --user)         LK_USER="$2"; shift 2 ;;
    --password)     LK_PASSWORD="$2"; shift 2 ;;
    --apikey)       LK_APIKEY="$2"; shift 2 ;;
    --insecure)     LK_INSECURE=1; shift ;;
    *) echo "unknown: $1"; exit 1 ;;
  esac
done

log()  { printf '[sleepdrive-lab] %s\n' "$*"; }
warn() { printf '[sleepdrive-lab] WARN: %s\n' "$*" >&2; }
die()  { printf '[sleepdrive-lab] ERROR: %s\n' "$*" >&2; exit 1; }

mkdir -p "$DATA_DIR/raw" "$DATA_DIR/prepared" "$DATA_DIR/sources" "$DATA_DIR/figures"

# ── quiz engine ───────────────────────────────────────────────────
# The quiz is a LabKey *Survey*: one question per card, real radio buttons for
# single-answer questions and tick boxes where several parts form the answer,
# navigated with LabKey's own Previous / Next buttons plus a "Cancel the Quiz"
# link on the bottom of every card. The wizard's step list is hidden with a rule
# in the project stylesheet, and auto-save is off so a cancelled attempt leaves
# nothing behind.
#
#   * one survey design per paper (LK_QUIZ_PAPERS of them), each a different
#     draw from the question pool with the A/B/C/D order shuffled
#   * one List per paper holds the answers — a row per attempt, so there is no
#     limit on how often a student takes the quiz
#   * SD_launch is a one-cell grid embedded in the quiz page: its link opens the
#     student's next paper directly, chosen from how many attempts they already
#     have, so nobody picks a paper by name and there is no page in between
#   * SD_my_attempts / SD_my_review show only your own rows (USERID()) and
#     carry a "Back to the quiz" button in their button bar
#   * nothing per question lives in the wiki: the whole quiz is one page
LK_QUIZ_PAPERS="${LK_QUIZ_PAPERS:-8}"
LK_QUIZ_QUESTIONS="${LK_QUIZ_QUESTIONS:-30}"

ensure_quiz_assets() {
  local here bank builder
  mkdir -p "$DATA_DIR/quiz"
  here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || here="."
  bank="$DATA_DIR/quiz/quiz_bank.json"
  builder="$DATA_DIR/quiz/build_quiz.py"

  # An instructor can drop an own quiz_bank.json next to this script to swap
  # the question pool; otherwise the embedded 100-question pool is used.
  if [[ -s "$here/quiz_bank.json" ]]; then
    cp -f "$here/quiz_bank.json" "$bank"
    log "quiz pool from $here/quiz_bank.json"
  else
    cat >"$bank" <<'QUIZ_BANK_JSON'
[
 {
  "id": 1,
  "level": "easy",
  "type": "single",
  "question": "What is the primary scientific question of this paper?",
  "choices": [
   "How SCN clocks alone generate all behavior",
   "Which wake-activated neuronal populations encode and regulate sleep drive",
   "How orexin neurons alone control every transition",
   "Whether REM sleep is required for all memory"
  ],
  "correct": [
   1
  ],
  "explanation": "Wake-activated aMPO and MR populations encode sleep deficit and regulate sleep drive.",
  "figure": null
 },
 {
  "id": 2,
  "level": "easy",
  "type": "single",
  "question": "MR stands for?",
  "choices": [
   "Medial reticular formation",
   "Median raphe",
   "Motor cortex region",
   "Medial septum"
  ],
  "correct": [
   1
  ],
  "explanation": "MR = median raphe.",
  "figure": null
 },
 {
  "id": 3,
  "level": "easy",
  "type": "single",
  "question": "aMPO stands for?",
  "choices": [
   "Anterior medial preoptic area",
   "Amygdala medial pathway",
   "Anterior midbrain pons",
   "Accessory motor organ"
  ],
  "correct": [
   0
  ],
  "explanation": "aMPO = anterior medial preoptic area.",
  "figure": null
 },
 {
  "id": 4,
  "level": "easy",
  "type": "single",
  "question": "After prolonged wakefulness, sleep drive is compensated by increases in:",
  "choices": [
   "Only REM duration",
   "Sleep duration and intensity (NREM SWA)",
   "Only heart-rate variability",
   "Only body temperature"
  ],
  "correct": [
   1
  ],
  "explanation": "Abstract: duration and intensity (NREM slow-wave activity).",
  "figure": null
 },
 {
  "id": 5,
  "level": "easy",
  "type": "single",
  "question": "NREM delta / SWA is measured mainly in which band?",
  "choices": [
   "12–30 Hz",
   "0.25–4 Hz",
   "30–80 Hz",
   "Only 8–12 Hz"
  ],
  "correct": [
   1
  ],
  "explanation": "Delta ≈ 0.25–4 Hz indexes sleep intensity.",
  "figure": null
 },
 {
  "id": 6,
  "level": "easy",
  "type": "single",
  "question": "Whole-brain activity mapping used which marker?",
  "choices": [
   "FOS (c-Fos) immunostaining",
   "GFP without activity dependence",
   "Tau pathology only",
   "Myelin basic protein only"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 1: whole-brain FOS mapping.",
  "figure": null
 },
 {
  "id": 7,
  "level": "easy",
  "type": "single",
  "question": "TRAP2 labeling depends on:",
  "choices": [
   "Orexin only",
   "Fos-driven iCreERT2 (Fos-2A-iCreERT2)",
   "Melatonin only",
   "Myelin genes only"
  ],
  "correct": [
   1
  ],
  "explanation": "TRAP2 uses Fos-2A-iCreERT2 with 4-OHT.",
  "figure": null
 },
 {
  "id": 8,
  "level": "easy",
  "type": "single",
  "question": "Main chemogenetic activation pair:",
  "choices": [
   "ChR2 + blue light",
   "hM3Dq + CNO",
   "ArchT + green light",
   "Cas9 + gRNA"
  ],
  "correct": [
   1
  ],
  "explanation": "Excitatory DREADD hM3Dq activated by CNO.",
  "figure": null
 },
 {
  "id": 9,
  "level": "easy",
  "type": "single",
  "question": "Activating MR deprivation-TRAP cells mainly increases:",
  "choices": [
   "Only REM",
   "NREM duration and often intensity",
   "Only seizures",
   "Only burst-suppression"
  ],
  "correct": [
   1
  ],
  "explanation": "Fig. 2: NREM ~2–3× and delta power.",
  "figure": null
 },
 {
  "id": 10,
  "level": "easy",
  "type": "single",
  "question": "Co-inhibition cutting sleep by ~70% targets:",
  "choices": [
   "Orexin and MCH only",
   "GABAergic (Vgat+) and serotonergic (Sert+)",
   "Only Vglut2+",
   "Only cortex"
  ],
  "correct": [
   1
  ],
  "explanation": "Fig. 5 / abstract: MR Vgat+ and Sert+ co-inhibition.",
  "figure": null
 },
 {
  "id": 11,
  "level": "easy",
  "type": "single",
  "question": "Wake-promoting LHA deprivation-TRAP cells largely express:",
  "choices": [
   "Orexin",
   "Only somatostatin",
   "Only MCH",
   "Only oxytocin"
  ],
  "correct": [
   0
  ],
  "explanation": "LHA orexin+ cells promote wakefulness.",
  "figure": null
 },
 {
  "id": 12,
  "level": "easy",
  "type": "single",
  "question": "CNO means:",
  "choices": [
   "Cortical neural oscillator",
   "Clozapine-N-oxide",
   "Cyclic nucleotide opener",
   "Calcium-nitrous oxide"
  ],
  "correct": [
   1
  ],
  "explanation": "Ligand used to activate DREADDs.",
  "figure": null
 },
 {
  "id": 13,
  "level": "easy",
  "type": "single",
  "question": "Kir2.1 is used to:",
  "choices": [
   "Chronically excite neurons",
   "Chronically inhibit neurons",
   "Only trace axons",
   "Measure blood flow"
  ],
  "correct": [
   1
  ],
  "explanation": "Inward-rectifier K+ channel for chronic inhibition.",
  "figure": null
 },
 {
  "id": 14,
  "level": "easy",
  "type": "single",
  "question": "Sleep scoring relies primarily on:",
  "choices": [
   "EEG (plus behavior/EMG as designed)",
   "Only fMRI",
   "Only PET",
   "Only ultrasound"
  ],
  "correct": [
   0
  ],
  "explanation": "EEG epoch scoring: wake, NREM, REM.",
  "figure": null
 },
 {
  "id": 15,
  "level": "easy",
  "type": "single",
  "question": "Type 3 FOS responses are:",
  "choices": [
   "Only early cortical novelty peaks",
   "Sustained during deprivation, wake-correlated, encoding sleep deficit",
   "Only glial scars",
   "Only recovery-only peaks"
  ],
  "correct": [
   1
  ],
  "explanation": "Fig. 1 type 3: deficit-encoding (e.g. MR, aMPO).",
  "figure": null
 },
 {
  "id": 16,
  "level": "easy",
  "type": "multi",
  "question": "Which regions encode sleep deficit? (select all that apply)",
  "choices": [
   "aMPO",
   "Median raphe (MR)",
   "Primary visual cortex only",
   "Cerebellar Purkinje cells only"
  ],
  "correct": [
   0,
   1
  ],
  "explanation": "Abstract and Fig. 1: aMPO and MR.",
  "figure": null
 },
 {
  "id": 17,
  "level": "easy",
  "type": "single",
  "question": "Deprivation-TRAP vs recovery-TRAP in MR labels about:",
  "choices": [
   "Equal numbers",
   "~3× more cells with deprivation-TRAP",
   "100× more",
   "Fewer with deprivation-TRAP"
  ],
  "correct": [
   1
  ],
  "explanation": "Fig. 2: ~3× more with deprivation-TRAP.",
  "figure": null
 },
 {
  "id": 18,
  "level": "easy",
  "type": "single",
  "question": "Fig. 4 synergy refers to co-activation of:",
  "choices": [
   "Vgat+ and Sert+ MR cells",
   "Only Vglut2+",
   "Only cortical interneurons",
   "Only motoneurons"
  ],
  "correct": [
   0
  ],
  "explanation": "GABAergic + serotonergic co-activation.",
  "figure": null
 },
 {
  "id": 19,
  "level": "easy",
  "type": "multi",
  "question": "Which populations promote wakefulness when they are activated? (tick all that apply)",
  "choices": [
   "Orexin neurons of the lateral hypothalamus (LHA)",
   "Vglut2+ glutamatergic neurons of the median raphe",
   "Vgat+ GABAergic neurons of the median raphe",
   "Sert+ serotonergic neurons of the median raphe"
  ],
  "correct": [
   0,
   1
  ],
  "explanation": "LHA orexin cells and the MR Vglut2+ subset drive wake; the MR Vgat+ and Sert+ populations promote NREM sleep.",
  "figure": null
 },
 {
  "id": 20,
  "level": "easy",
  "type": "single",
  "question": "Sleep attempts during deprivation are:",
  "choices": [
   "Only wheel running",
   "Immobile posture + NREM-like SWA (often interrupted)",
   "Only REM without EEG",
   "Only seizures"
  ],
  "correct": [
   1
  ],
  "explanation": "Methods: immobility + NREM SWA.",
  "figure": null
 },
 {
  "id": 21,
  "level": "easy",
  "type": "single",
  "question": "Which MR cell class promotes wake when activated?",
  "choices": [
   "Vglut2+ glutamatergic",
   "Only Sert+",
   "Only Vgat+",
   "Only astrocytes"
  ],
  "correct": [
   0
  ],
  "explanation": "Vglut2+ activation promotes wakefulness.",
  "figure": null
 },
 {
  "id": 22,
  "level": "easy",
  "type": "single",
  "question": "Delta power is a proxy for:",
  "choices": [
   "Sleep intensity (NREM SWA)",
   "Only heart rate",
   "Only body weight",
   "Only SpO₂"
  ],
  "correct": [
   0
  ],
  "explanation": "Higher NREM delta = more intense slow-wave sleep.",
  "figure": null
 },
 {
  "id": 23,
  "level": "easy",
  "type": "single",
  "question": "4-OHT in TRAP2 is used to:",
  "choices": [
   "Permanently open the BBB",
   "Enable Cre activity in Fos+ cells for labeling",
   "Block all serotonin receptors",
   "Always anesthetize for 6 h"
  ],
  "correct": [
   1
  ],
  "explanation": "4-hydroxytamoxifen induces recombination.",
  "figure": null
 },
 {
  "id": 24,
  "level": "easy",
  "type": "single",
  "question": "Chronic sleep reduction — abstract note:",
  "choices": [
   "All mice die within hours",
   "Most survivors lack large compensatory rebound or major behavioral collapse",
   "Always 200% rebound the next day",
   "Memory is always fully lost"
  ],
  "correct": [
   1
  ],
  "explanation": "Most mice survive without large compensatory drive increases.",
  "figure": null
 },
 {
  "id": 25,
  "level": "easy",
  "type": "single",
  "question": "LPO means:",
  "choices": [
   "Lateral preoptic area",
   "Lateral parietal operculum",
   "Left prefrontal only",
   "Lumbar proprioceptive organ"
  ],
  "correct": [
   0
  ],
  "explanation": "Lateral preoptic area — MR projection target.",
  "figure": null
 },
 {
  "id": 26,
  "level": "easy",
  "type": "multi",
  "question": "Methods used in the study include (select all):",
  "choices": [
   "FOS whole-brain mapping",
   "Chemogenetics (DREADDs)",
   "EEG sleep scoring",
   "Human clinical PET only"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Core mouse methods; not clinical PET.",
  "figure": null
 },
 {
  "id": 27,
  "level": "easy",
  "type": "single",
  "question": "Recovery sleep features elevated:",
  "choices": [
   "Only muscle tone",
   "NREM amount and/or SWA after sleep loss",
   "Only cortisol without EEG change",
   "Only REM without NREM"
  ],
  "correct": [
   1
  ],
  "explanation": "Homeostatic recovery sleep.",
  "figure": null
 },
 {
  "id": 28,
  "level": "easy",
  "type": "single",
  "question": "hM4Di is used to:",
  "choices": [
   "Excite neurons",
   "Inhibit neurons",
   "Only measure voltage",
   "Edit the genome"
  ],
  "correct": [
   1
  ],
  "explanation": "Inhibitory DREADD.",
  "figure": null
 },
 {
  "id": 29,
  "level": "easy",
  "type": "multi",
  "question": "Which readouts are used in this study to quantify sleep drive? (tick all that apply)",
  "choices": [
   "NREM sleep amount (duration)",
   "NREM slow-wave activity (delta power)",
   "Sleep attempts during enforced wakefulness",
   "Circadian phase of the suprachiasmatic nucleus alone"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Sleep drive is read out as sleep amount, sleep intensity (SWA) and the sleep attempts that break through during deprivation. Circadian phase is a separate process.",
  "figure": null
 },
 {
  "id": 30,
  "level": "easy",
  "type": "single",
  "question": "Serotonergic MR neurons are marked as:",
  "choices": [
   "Sert+",
   "Only ChAT+",
   "Only TH+",
   "Only PV+"
  ],
  "correct": [
   0
  ],
  "explanation": "Sert+ marks serotonergic cells.",
  "figure": null
 },
 {
  "id": 31,
  "level": "easy",
  "type": "single",
  "question": "GABAergic MR neurons are marked as:",
  "choices": [
   "Vgat+",
   "Only Vglut1+",
   "Only Chat+",
   "Only DBH+"
  ],
  "correct": [
   0
  ],
  "explanation": "Vgat+ marks GABAergic cells.",
  "figure": null
 },
 {
  "id": 32,
  "level": "easy",
  "type": "single",
  "question": "Fig. 1 main theme:",
  "choices": [
   "Whole-brain mapping of deprivation and recovery",
   "Only liver RNA-seq",
   "Only human clinic PSG",
   "Only fly courtship song"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 1 FOS mapping.",
  "figure": "Fig1.png"
 },
 {
  "id": 33,
  "level": "easy",
  "type": "single",
  "question": "Fig. 2 main theme:",
  "choices": [
   "Deprivation-TRAP activation promotes NREM and SWA",
   "Only spinal regeneration",
   "Only cochlear implants",
   "Only microbiome"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 2 chemogenetic activation.",
  "figure": "Fig2.png"
 },
 {
  "id": 34,
  "level": "easy",
  "type": "multi",
  "question": "Which median raphe cell classes were labelled or manipulated in this study? (tick all that apply)",
  "choices": [
   "Sert+ serotonergic neurons",
   "Vgat+ GABAergic neurons",
   "Vglut2+ glutamatergic neurons",
   "Retinal ganglion cells"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "MR deprivation-TRAP cells split into serotonergic, GABAergic and a smaller glutamatergic fraction; the retina is not part of the MR.",
  "figure": "Fig5.png"
 },
 {
  "id": 35,
  "level": "easy",
  "type": "multi",
  "question": "True about sleep intensity here (select all):",
  "choices": [
   "Delta power in NREM indexes intensity",
   "SWA often rises after deprivation",
   "Intensity equals BMI only",
   "EEG is irrelevant"
  ],
  "correct": [
   0,
   1
  ],
  "explanation": "SWA/delta indexes intensity and rises with prior wake.",
  "figure": null
 },
 {
  "id": 36,
  "level": "medium",
  "type": "single",
  "question": "Type 1 FOS responses are best described as:",
  "choices": [
   "Early peak; often cortical / sensory-novelty related",
   "Only chronic glial scars",
   "Only recovery hypothalamic peaks",
   "Only spinal motor pools"
  ],
  "correct": [
   0
  ],
  "explanation": "Type 1: early peak, novelty/sensory.",
  "figure": null
 },
 {
  "id": 37,
  "level": "medium",
  "type": "single",
  "question": "Type 2 FOS responses peak mainly during:",
  "choices": [
   "Recovery (sleep-active subcortical regions such as LPO/VM)",
   "Only the first 30 s of novelty",
   "Only REM without NREM",
   "Only seizures"
  ],
  "correct": [
   0
  ],
  "explanation": "Type 2: recovery peak.",
  "figure": null
 },
 {
  "id": 38,
  "level": "medium",
  "type": "single",
  "question": "Control-TRAP activation fails to promote sleep like deprivation-TRAP because:",
  "choices": [
   "Different ensembles; deprivation-responsive cells are specific",
   "CNO never works in controls",
   "EEG machines were off",
   "MR does not exist in controls"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 2: ensemble specificity.",
  "figure": null
 },
 {
  "id": 39,
  "level": "medium",
  "type": "single",
  "question": "LPO-projecting MR cell activation primarily increases:",
  "choices": [
   "NREM duration but not necessarily delta power (partial mediation)",
   "Only REM density",
   "Only cortical gamma",
   "Only heart rate"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 3: partial mediation of the full phenotype.",
  "figure": null
 },
 {
  "id": 40,
  "level": "medium",
  "type": "single",
  "question": "After sleep deprivation, Vgat+ MR cells show:",
  "choices": [
   "Depolarized resting potential, lower threshold, more spontaneous firing",
   "Complete permanent silencing",
   "Only increased myelin",
   "Loss of all synapses"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 4 physiology: increased excitability.",
  "figure": null
 },
 {
  "id": 41,
  "level": "medium",
  "type": "single",
  "question": "Sert+ excitability after deprivation is described as:",
  "choices": [
   "Always the same large increase as Vgat+",
   "Not showing the same excitability increase as Vgat+",
   "Conversion into glia",
   "Elimination by apoptosis"
  ],
  "correct": [
   1
  ],
  "explanation": "Contrast with Vgat+ excitability changes.",
  "figure": null
 },
 {
  "id": 42,
  "level": "medium",
  "type": "multi",
  "question": "MR deprivation-TRAP cells project to (select all):",
  "choices": [
   "aMPO / LPO",
   "LHA",
   "Hippocampus / thalamus / hindbrain–midbrain targets",
   "Retina only"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Fig. 3 projection map.",
  "figure": null
 },
 {
  "id": 43,
  "level": "medium",
  "type": "single",
  "question": "Activation of MR deprivation-TRAP induces FOS in aMPO/LPO and suppresses FOS in:",
  "choices": [
   "LHA (wake effector)",
   "Only cerebellum",
   "Only skin",
   "Only liver"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 3: sleep effectors up, LHA down.",
  "figure": null
 },
 {
  "id": 44,
  "level": "medium",
  "type": "single",
  "question": "Approximate MR deprivation-TRAP composition:",
  "choices": [
   "~40% Sert+, ~20% Vgat+, small Vglut2+ fraction",
   "100% orexin cells",
   "100% cortical pyramids",
   "0% serotonergic"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 4 cell-type split.",
  "figure": null
 },
 {
  "id": 45,
  "level": "medium",
  "type": "single",
  "question": "Chronic Kir2.1 co-inhibition increases wake bout length by roughly:",
  "choices": [
   "No change",
   ">2× longer wake bouts",
   "Only shorter bouts",
   "Only REM bouts"
  ],
  "correct": [
   1
  ],
  "explanation": "Fig. 5: wake bouts >2×.",
  "figure": null
 },
 {
  "id": 46,
  "level": "medium",
  "type": "single",
  "question": "Lethality under chronic co-inhibition was about:",
  "choices": [
   "0%",
   "~17% of mice",
   "100%",
   "Only in vitro"
  ],
  "correct": [
   1
  ],
  "explanation": "Minority lethality (~16–17%).",
  "figure": null
 },
 {
  "id": 47,
  "level": "medium",
  "type": "single",
  "question": "Survivors’ post-deprivation rebound sleep is:",
  "choices": [
   "Exaggerated beyond wild-type",
   "Reduced",
   "Always unchanged",
   "Converted entirely to REM"
  ],
  "correct": [
   1
  ],
  "explanation": "Fig. 5: reduced rebound.",
  "figure": null
 },
 {
  "id": 48,
  "level": "medium",
  "type": "single",
  "question": "Fear conditioning pattern reported:",
  "choices": [
   "Perfect memory in all tests",
   "Modest recent recall deficit; remote more spared",
   "Complete aphasia",
   "Only olfactory loss"
  ],
  "correct": [
   1
  ],
  "explanation": "Behavioral battery results.",
  "figure": null
 },
 {
  "id": 49,
  "level": "medium",
  "type": "single",
  "question": "Open-field locomotion in Kir2.1 mice tends to be:",
  "choices": [
   "Decreased to zero",
   "Increased (high-arousal wakefulness)",
   "Unmeasurable",
   "Only circular walking in darkness"
  ],
  "correct": [
   1
  ],
  "explanation": "Increased locomotion / high arousal.",
  "figure": null
 },
 {
  "id": 50,
  "level": "medium",
  "type": "multi",
  "question": "Inhibition tools in this paper include (select all):",
  "choices": [
   "hM4Di + CNO",
   "Kir2.1 expression",
   "PSAM4-GlyR based inhibition",
   "Only ChR2 excitation without inhibitory tools"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Inhibitory chemogenetics, Kir2.1, PSAM4-GlyR.",
  "figure": null
 },
 {
  "id": 51,
  "level": "medium",
  "type": "multi",
  "question": "Which are genuine limitations of FOS-based whole-brain mapping? (tick all that apply)",
  "choices": [
   "FOS is an indirect proxy of neuronal activity",
   "FOS integrates activity over tens of minutes, so it has poor temporal resolution",
   "A FOS map alone cannot establish that a region causes the behaviour",
   "FOS staining reports the myelin content of an axon tract"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "FOS is indirect, slow and correlative — which is exactly why the paper follows the maps with TRAP and chemogenetics. FOS says nothing about myelin.",
  "figure": null
 },
 {
  "id": 52,
  "level": "medium",
  "type": "single",
  "question": "In unperturbed cycles, MR/aMPO FOS tends to:",
  "choices": [
   "Rise at night (more wake) and fall at light onset (more sleep)",
   "Stay constant 24/7",
   "Appear only after death",
   "Track only body weight"
  ],
  "correct": [
   0
  ],
  "explanation": "Wake-correlated natural pattern.",
  "figure": null
 },
 {
  "id": 53,
  "level": "medium",
  "type": "single",
  "question": "Flp/Cre intersectional strategies mainly allow:",
  "choices": [
   "Projection-defined ensembles (e.g. LPO-projecting MR cells)",
   "Deleting the entire brain",
   "Only staining blood vessels",
   "Only measuring temperature"
  ],
  "correct": [
   0
  ],
  "explanation": "Pathway-specific chemogenetics.",
  "figure": null
 },
 {
  "id": 54,
  "level": "medium",
  "type": "single",
  "question": "If only Vglut2+ MR cells are activated, expected effect:",
  "choices": [
   "More wakefulness / less NREM intensity",
   "Deep recovery NREM only",
   "Only spinal shock",
   "Only increased hunger without wake change"
  ],
  "correct": [
   0
  ],
  "explanation": "Vglut2+ promotes wake.",
  "figure": null
 },
 {
  "id": 55,
  "level": "medium",
  "type": "multi",
  "question": "Which statements about the aMPO in this study are supported? (tick all that apply)",
  "choices": [
   "It lies in the preoptic area of the hypothalamus",
   "Its deprivation-TRAP cells promote sleep when they are activated",
   "Inhibiting its deprivation-TRAP cells reduces NREM sleep",
   "It is a subdivision of the cerebellar cortex"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "aMPO = anterior medial preoptic area, one of the two type-3 regions; activation promotes sleep and inhibition reduces it. It is not cerebellar.",
  "figure": "Fig2.png"
 },
 {
  "id": 56,
  "level": "medium",
  "type": "single",
  "question": "Delta power is often normalized to:",
  "choices": [
   "A baseline period from the experimental design",
   "Random numbers",
   "Room temperature only",
   "The experimenter’s age"
  ],
  "correct": [
   0
  ],
  "explanation": "Baseline normalization.",
  "figure": null
 },
 {
  "id": 57,
  "level": "medium",
  "type": "multi",
  "question": "Reasonable interpretations of sleep drive here (select all):",
  "choices": [
   "A homeostatic pressure that builds with wakefulness",
   "Encoded in part by wake-activated aMPO/MR ensembles",
   "Identical to the SCN circadian clock alone",
   "Only a subjective feeling with no neural basis"
  ],
  "correct": [
   0,
   1
  ],
  "explanation": "Homeostatic + neural encoding — not solely the clock.",
  "figure": null
 },
 {
  "id": 58,
  "level": "medium",
  "type": "single",
  "question": "Ablation (e.g. Casp3) of Sert+ or Vgat+ MR cells is reported to:",
  "choices": [
   "Decrease NREM",
   "Increase NREM only",
   "Have no EEG effect",
   "Only change fur color"
  ],
  "correct": [
   0
  ],
  "explanation": "Extended data: ablation decreases NREM.",
  "figure": null
 },
 {
  "id": 59,
  "level": "medium",
  "type": "single",
  "question": "PSAM4-GlyR acute inhibition during deprivation tests:",
  "choices": [
   "Whether acute silencing reduces sleep attempts while deprivation is ongoing",
   "Long-term memory only",
   "Only peripheral nerve conduction",
   "Only gut motility"
  ],
  "correct": [
   0
  ],
  "explanation": "Acute reduction of sleep attempts.",
  "figure": null
 },
 {
  "id": 60,
  "level": "medium",
  "type": "single",
  "question": "Fig. 4 synergy means:",
  "choices": [
   "Combined Vgat+ and Sert+ activation exceeds separate effects on sleep measures",
   "Cells cancel each other completely",
   "Only Vglut2+ matters",
   "Synergy refers only to software"
  ],
  "correct": [
   0
  ],
  "explanation": "Cooperative GABA–serotonin promotion.",
  "figure": "Fig4.png"
 },
 {
  "id": 61,
  "level": "medium",
  "type": "single",
  "question": "A key control for chemogenetic specificity is:",
  "choices": [
   "Comparing deprivation-TRAP vs control-TRAP (or vehicle) under the same CNO delivery",
   "Never using controls",
   "Testing only one mouse",
   "Ignoring EEG"
  ],
  "correct": [
   0
  ],
  "explanation": "Control-TRAP / vehicle comparisons.",
  "figure": null
 },
 {
  "id": 62,
  "level": "medium",
  "type": "single",
  "question": "Whole-cell patch clamp was performed in:",
  "choices": [
   "Acute brain slices from rested vs deprived mice",
   "Only intact human patients",
   "Only non-neural cell lines",
   "Only plant cells"
  ],
  "correct": [
   0
  ],
  "explanation": "Slice physiology.",
  "figure": null
 },
 {
  "id": 63,
  "level": "medium",
  "type": "single",
  "question": "Inhibiting aMPO deprivation-TRAP cells expects:",
  "choices": [
   "Reduced NREM / reduced attempts",
   "Forced continuous NREM",
   "Only increased REM forever",
   "No possible EEG change"
  ],
  "correct": [
   0
  ],
  "explanation": "Silencing a sleep-promoting ensemble.",
  "figure": null
 },
 {
  "id": 64,
  "level": "medium",
  "type": "multi",
  "question": "Which findings support causality (select all):",
  "choices": [
   "Chemogenetic activation increases NREM/SWA",
   "Inhibition reduces sleep and attempts",
   "FOS rises in MR during deprivation (correlative)",
   "The journal name is Nature"
  ],
  "correct": [
   0,
   1
  ],
  "explanation": "Gain- and loss-of-function establish causality.",
  "figure": null
 },
 {
  "id": 65,
  "level": "medium",
  "type": "single",
  "question": "Dark-phase CNO delivery is useful because:",
  "choices": [
   "Mice are normally more awake then, so sleep promotion is a strong contrast",
   "Mice never sleep at night under any condition",
   "CNO only works in darkness chemically",
   "EEG only records at night"
  ],
  "correct": [
   0
  ],
  "explanation": "Challenging the active phase.",
  "figure": null
 },
 {
  "id": 66,
  "level": "medium",
  "type": "multi",
  "question": "Which statements about TRAP2 labelling are correct? (tick all that apply)",
  "choices": [
   "Cre recombinase is driven from the activity-dependent Fos locus (Fos-2A-iCreERT2)",
   "4-OHT (tamoxifen metabolite) opens the time window in which labelling can happen",
   "Cells active around that window become permanently marked and re-accessible later",
   "It labels only cells that first become active several weeks after the injection"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "TRAP = Targeted Recombination in Active Populations: Fos-driven CreER plus 4-OHT converts a transient activity pattern into a permanent genetic handle.",
  "figure": null
 },
 {
  "id": 67,
  "level": "medium",
  "type": "single",
  "question": "‘Nearly 70%’ sleep reduction refers mainly to:",
  "choices": [
   "Chronic co-inhibition of MR Vgat+ and Sert+",
   "A 70% drop in body weight",
   "70% fewer cortical neurons",
   "70% less food intake only"
  ],
  "correct": [
   0
  ],
  "explanation": "Abstract / Fig. 5 scale.",
  "figure": "Fig5.png"
 },
 {
  "id": 68,
  "level": "medium",
  "type": "multi",
  "question": "Which states are distinguished by the EEG-based scoring used here? (tick all that apply)",
  "choices": [
   "NREM sleep",
   "REM sleep",
   "Wake, including a higher-theta wake subtype",
   "Human polysomnography stage N3"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Rodent scoring separates NREM, REM and wake (with a high-theta wake subtype). N1–N3 staging belongs to human polysomnography.",
  "figure": null
 },
 {
  "id": 69,
  "level": "medium",
  "type": "multi",
  "question": "Which observations show that the median raphe is functionally heterogeneous? (tick all that apply)",
  "choices": [
   "Vgat+ and Sert+ activation promotes sleep",
   "Vglut2+ activation promotes wakefulness instead",
   "Deprivation-TRAP cells are a mixture (~40% Sert+, ~20% Vgat+, some Vglut2+)",
   "Every MR neuron releases the same neurotransmitter"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Opposing effects of neighbouring cell classes plus a mixed transmitter composition are the definition of a heterogeneous nucleus.",
  "figure": null
 },
 {
  "id": 70,
  "level": "hard",
  "type": "single",
  "question": "Best isolation of sleep-deficit encoding vs pure sensory novelty:",
  "choices": [
   "Shared type-3 FOS across deprivation methods that scales with wake duration",
   "Any single novel-object trial without recovery comparison",
   "Only wheel-running without EEG",
   "Only FOS after anesthesia"
  ],
  "correct": [
   0
  ],
  "explanation": "Cross-method type-3 + wake-duration scaling.",
  "figure": null
 },
 {
  "id": 71,
  "level": "hard",
  "type": "single",
  "question": "Partial mediation by LPO-projecting MR cells implies:",
  "choices": [
   "Other projection targets or local mechanisms also contribute to the full NREM+SWA phenotype",
   "LPO explains 100% of all sleep biology",
   "MR has no other projections",
   "Delta power is unrelated to sleep"
  ],
  "correct": [
   0
  ],
  "explanation": "NREM↑ without delta↑ → incomplete pathway.",
  "figure": null
 },
 {
  "id": 72,
  "level": "hard",
  "type": "multi",
  "question": "Observations arguing MR ensembles are sleep-promoting (select all):",
  "choices": [
   "Activation increases NREM and delta",
   "Inhibition decreases NREM and attempts",
   "Vglut2+ subset promotes wake (cell-type heterogeneity)",
   "FOS exists somewhere in the brain"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Gain-of-function, loss-of-function, and cell-type split.",
  "figure": null
 },
 {
  "id": 73,
  "level": "hard",
  "type": "single",
  "question": "CNO off-target concerns are mitigated by:",
  "choices": [
   "Control-TRAP / non-DREADD animals receiving CNO",
   "Never running controls",
   "Using one dose without vehicle",
   "Ignoring pharmacology literature"
  ],
  "correct": [
   0
  ],
  "explanation": "Pharmacological controls.",
  "figure": null
 },
 {
  "id": 74,
  "level": "hard",
  "type": "single",
  "question": "Depolarization of Vgat+ cells after deprivation suggests a mechanism for:",
  "choices": [
   "Increased likelihood of sleep-promoting output after sleep loss",
   "Permanent loss of GABA synthesis only",
   "Conversion to serotonergic identity",
   "Only muscle paralysis"
  ],
  "correct": [
   0
  ],
  "explanation": "Higher excitability biases circuits toward recovery sleep.",
  "figure": null
 },
 {
  "id": 75,
  "level": "hard",
  "type": "single",
  "question": "Stable reduction of sleep drive under chronic inhibition without full rebound implies:",
  "choices": [
   "The inhibited populations are necessary for normal homeostatic rebound expression",
   "Homeostasis is entirely peripheral",
   "EEG cannot measure rebound",
   "Sleep drive is only circadian"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 5 phenotype interpretation.",
  "figure": null
 },
 {
  "id": 76,
  "level": "hard",
  "type": "single",
  "question": "Best use of Fig. 5 source tables for a high grade:",
  "choices": [
   "Quantify Control vs Kir2.1 contrast and link it to Vgat+/Sert+ co-inhibition",
   "Only restate the paper title",
   "Ignore tables and cite a blog",
   "Claim the table proves cortical blindness"
  ],
  "correct": [
   0
  ],
  "explanation": "Lab rubric: concrete table-backed comparison.",
  "figure": "Fig5.png"
 },
 {
  "id": 77,
  "level": "hard",
  "type": "multi",
  "question": "Limitations a careful student should mention (select all):",
  "choices": [
   "Mouse models may not fully translate to human therapy",
   "Chemogenetic/viral targeting has spatial and efficiency limits",
   "FOS is an indirect activity proxy with temporal integration limits",
   "The paper proves all sleep is only serotonergic"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Real limitations; the last option overclaims.",
  "figure": null
 },
 {
  "id": 78,
  "level": "hard",
  "type": "single",
  "question": "Why might inhibiting sleep-promoting cells be lethal in a minority?",
  "choices": [
   "Extreme sleep loss can be physiologically unsustainable in some individuals",
   "Kir2.1 always melts electrodes",
   "Serotonin is only a vitamin",
   "EEG cables cause infection in 100% of cases"
  ],
  "correct": [
   0
  ],
  "explanation": "Severe chronic sleep reduction; ~17% mortality reported.",
  "figure": null
 },
 {
  "id": 79,
  "level": "hard",
  "type": "single",
  "question": "Alternative explanation for MR FOS during deprivation that the design tries to rule out:",
  "choices": [
   "Pure stress/novelty without homeostatic deficit — addressed by multiple methods and wake-duration scaling",
   "That FOS is DNA",
   "That mice do not have a median raphe",
   "That CNO is a protein"
  ],
  "correct": [
   0
  ],
  "explanation": "Shared type-3 signals argue against pure method artifact.",
  "figure": null
 },
 {
  "id": 80,
  "level": "hard",
  "type": "single",
  "question": "Intersectional projection experiments test the idea that:",
  "choices": [
   "Output pathways are heterogeneous; not every MR axon carries the same sleep function",
   "All axons are identical",
   "Projections do not exist",
   "Only blood vessels carry signals"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 3 pathway-specific contributions.",
  "figure": null
 },
 {
  "id": 81,
  "level": "hard",
  "type": "single",
  "question": "Co-activation synergy of Vgat+ and Sert+ is important because:",
  "choices": [
   "Sleep promotion is not a single-cell-type phenomenon; mixed ensembles cooperate",
   "Only one transmitter exists in MR",
   "Synergy means statistical error",
   "GABA and serotonin never coexist"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 4 cooperative promotion.",
  "figure": "Fig4.png"
 },
 {
  "id": 82,
  "level": "hard",
  "type": "multi",
  "question": "Metrics to extract from source data to test Fig. 2 (select all):",
  "choices": [
   "NREM amount or fraction control vs CNO",
   "Delta power control vs CNO",
   "Only the PDF file size",
   "Only the number of authors"
  ],
  "correct": [
   0,
   1
  ],
  "explanation": "Fig. 2 claims rest on NREM and SWA/delta contrasts.",
  "figure": null
 },
 {
  "id": 83,
  "level": "hard",
  "type": "single",
  "question": "A false-positive ‘activation increases sleep’ could occur if:",
  "choices": [
   "CNO was given when animals were already entering a strong sleep phase without proper controls",
   "EEG sampling rate is 100–200 Hz as designed",
   "Baseline normalization is reported",
   "n is adequate and tests are two-sided"
  ],
  "correct": [
   0
  ],
  "explanation": "Circadian confounds require timed controls.",
  "figure": null
 },
 {
  "id": 84,
  "level": "hard",
  "type": "single",
  "question": "‘Wake-activated populations that regulate sleep drive’ is not contradictory because:",
  "choices": [
   "Neurons active in wake can track sleep need and later promote sleep",
   "Wake-active neurons can never affect sleep",
   "Sleep drive is only behavioral without neurons",
   "Activation always equals wake behavior only"
  ],
  "correct": [
   0
  ],
  "explanation": "Core concept: wake-time activity encodes deficit that drives subsequent sleep.",
  "figure": null
 },
 {
  "id": 85,
  "level": "hard",
  "type": "single",
  "question": "Compared with classical sleep-active preoptic neurons, type-3 aMPO/MR cells are distinctive as:",
  "choices": [
   "Wake-correlated during deprivation yet sleep-promoting when activated",
   "Only active during NREM itself in the mapping typology emphasized here",
   "Only motor neurons",
   "Only sensory thalamic relays"
  ],
  "correct": [
   0
  ],
  "explanation": "Deficit trackers, not classic sleep-active firing profiles.",
  "figure": null
 },
 {
  "id": 86,
  "level": "hard",
  "type": "single",
  "question": "Vgat+ inhibition decreases NREM while Vglut2+ activation increases wake. Coherent model:",
  "choices": [
   "MR contains opposing cell classes; net effect depends on which ensemble is engaged",
   "All MR cells do the same thing",
   "Transmitters do not matter",
   "Only glia set NREM"
  ],
  "correct": [
   0
  ],
  "explanation": "Cell-type-specific opposing roles within MR.",
  "figure": null
 },
 {
  "id": 87,
  "level": "hard",
  "type": "multi",
  "question": "For a rigorous student conclusion, combine (select all):",
  "choices": [
   "Source-data numeric contrasts (Figs 1–5 tables)",
   "Causal chemogenetic results from the paper",
   "Awareness of correlative FOS limits",
   "Unrelated social-media polls"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Tables + causal results + methodological humility.",
  "figure": null
 },
 {
  "id": 88,
  "level": "hard",
  "type": "single",
  "question": "Reduced delta accumulation during long wake bouts in Kir2.1 mice suggests:",
  "choices": [
   "Impaired build-up of homeostatic sleep pressure signals in EEG SWA dynamics",
   "Perfect homeostasis",
   "Only electrode failure",
   "Only increased REM pressure"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 5: altered drive dynamics.",
  "figure": null
 },
 {
  "id": 89,
  "level": "hard",
  "type": "single",
  "question": "Most accurate hierarchical summary:",
  "choices": [
   "FOS maps nominate aMPO/MR → TRAP/chemogenetics show causal sleep promotion → cell-type split shows GABA+5-HT synergy → chronic inhibition collapses drive",
   "Only FOS maps are sufficient for all causal claims",
   "Only behavior without neuroscience methods",
   "Only human clinical trials are reported"
  ],
  "correct": [
   0
  ],
  "explanation": "Paper logic chain.",
  "figure": null
 },
 {
  "id": 90,
  "level": "hard",
  "type": "multi",
  "question": "Necessary to claim ‘MR deprivation-TRAP promotes recovery-like sleep’ (select all):",
  "choices": [
   "Labeling tied to deprivation activity (TRAP)",
   "Activation increases NREM/SWA",
   "Control ensembles do not reproduce the phenotype",
   "The journal name alone"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Labeling specificity, positive effect, and control contrast.",
  "figure": null
 },
 {
  "id": 91,
  "level": "hard",
  "type": "single",
  "question": "An animal×hour matrix under Kir2.1 vs control is most useful to estimate:",
  "choices": [
   "Hourly sleep/wake metric differences under inhibition",
   "Only the mouse coat color",
   "Only the filename",
   "Only the DOI string"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 5 sheets support temporal comparison.",
  "figure": null
 },
 {
  "id": 92,
  "level": "hard",
  "type": "multi",
  "question": "Which consequences follow chronic co-inhibition of MR Vgat+ and Sert+ cells? (tick all that apply)",
  "choices": [
   "Sleep is reduced by nearly 70%",
   "Wake bouts become more than twice as long",
   "Rebound sleep after deprivation is reduced",
   "Rebound sleep after deprivation is exaggerated beyond wild-type"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Chronic Kir2.1 co-inhibition collapses sleep drive: much less sleep, much longer wake bouts and a blunted — not exaggerated — rebound.",
  "figure": null
 },
 {
  "id": 93,
  "level": "hard",
  "type": "multi",
  "question": "Which statements about LHA orexin neurons in this work are correct? (tick all that apply)",
  "choices": [
   "They are wake-promoting",
   "Deprivation-TRAP also labels wake-promoting cells in the LHA",
   "Activating MR deprivation-TRAP cells suppresses FOS in the LHA",
   "They are the main generators of NREM slow-wave activity"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "LHA orexin cells are a classic wake effector; the sleep-promoting MR ensemble turns them down. They do not generate slow waves.",
  "figure": null
 },
 {
  "id": 94,
  "level": "hard",
  "type": "single",
  "question": "Homeostatic sleep regulation means:",
  "choices": [
   "Sleep need rises with prior wakefulness and is discharged in recovery sleep",
   "Sleep occurs only at fixed clock times with no wake-history effect",
   "Sleep is random noise",
   "Sleep equals hibernation only"
  ],
  "correct": [
   0
  ],
  "explanation": "Core homeostatic definition.",
  "figure": null
 },
 {
  "id": 95,
  "level": "hard",
  "type": "multi",
  "question": "Accurate figure pairings (select all):",
  "choices": [
   "Fig. 1 ↔ FOS mapping",
   "Fig. 2 ↔ TRAP activation / NREM",
   "Fig. 5 ↔ chronic co-inhibition",
   "Fig. 2 ↔ kidney assays only"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Match figures to claims.",
  "figure": null
 },
 {
  "id": 96,
  "level": "hard",
  "type": "multi",
  "question": "Which controls support the specificity of the chemogenetic results? (tick all that apply)",
  "choices": [
   "Control-TRAP animals that receive the same CNO dose",
   "Vehicle injections instead of CNO in DREADD-expressing animals",
   "Animals without any DREADD that receive CNO",
   "Reporting only the CNO condition without any comparison group"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "Specificity needs the same drug in the wrong ensemble, the same ensemble without the drug, and the drug without a receptor. A single condition proves nothing.",
  "figure": null
 },
 {
  "id": 97,
  "level": "hard",
  "type": "single",
  "question": "‘Recovery-like sleep’ after activating deprivation-TRAP cells means:",
  "choices": [
   "Elevated NREM and intensity resembling post-deprivation recovery",
   "Only insomnia",
   "Only anesthesia",
   "Only forced locomotion"
  ],
  "correct": [
   0
  ],
  "explanation": "Fig. 2 phenotype mirrors recovery sleep.",
  "figure": null
 },
 {
  "id": 98,
  "level": "hard",
  "type": "single",
  "question": "NREM increase without delta increase (LPO-projecting activation) suggests:",
  "choices": [
   "Dissociable circuit control of amount vs intensity of sleep",
   "EEG is broken in all mice",
   "Delta is not a frequency",
   "NREM does not exist"
  ],
  "correct": [
   0
  ],
  "explanation": "Amount vs intensity can be partially separable.",
  "figure": null
 },
 {
  "id": 99,
  "level": "hard",
  "type": "multi",
  "question": "Which statements about the three FOS response types are correct? (tick all that apply)",
  "choices": [
   "Type 1 peaks early and is largely cortical / sensory-novelty related",
   "Type 2 peaks during recovery sleep in sleep-active regions such as LPO",
   "Type 3 is sustained across deprivation, correlates with time awake and tracks sleep deficit",
   "Type 3 appears only after recovery sleep has ended"
  ],
  "correct": [
   0,
   1,
   2
  ],
  "explanation": "The type-3 profile is the one that behaves like a sleep-deficit signal, which is why aMPO and MR were followed up.",
  "figure": null
 },
 {
  "id": 100,
  "level": "hard",
  "type": "single",
  "question": "Best overall take-home message:",
  "choices": [
   "Wake-activated aMPO/MR ensembles track deficit and can drive recovery sleep; GABA+5-HT co-inhibition can collapse drive",
   "Sleep is only cortical",
   "Only REM matters",
   "Only circadian clocks matter"
  ],
  "correct": [
   0
  ],
  "explanation": "Synthesis of mapping, causality, and cell-type findings.",
  "figure": null
 }
]
QUIZ_BANK_JSON
  fi
  cat >"$builder" <<'BUILD_QUIZ_PY'
#!/usr/bin/env python3
"""Generate the sleep-drive quiz as LabKey Survey designs.

Why surveys: LabKey's plain insert forms cannot render radio buttons (their
renderer knows select / checkbox / text / textarea / file only), and one
question per page needed a wiki page per question. The Survey module solves
both — its card layout shows one section at a time with Next / Previous /
Cancel, and an ExtJS radiogroup gives real radio buttons — while keeping every
question out of the wiki: a paper is one survey design, not 30 pages.

Per paper this emits
  * a responses List (one row per attempt, one column per answer)
  * a survey design (30 sections = 30 questions, radios or tick boxes)
  * a LabKey SQL query that grades it
  * a static "finished" page served from the file repository, which offers the
    next paper — so a student can retake the quiz as often as they like and
    never picks a paper by name
plus the shared roll-ups (history, review, answer key) and one wiki page.

usage: build_quiz3.py <bank.json> <outdir> <containerPath> <papers> <per_paper>
"""
import csv
import html
import json
import random
import sys
from pathlib import Path
from urllib.parse import quote

STR = "http://www.w3.org/2001/XMLSchema#string"
INT = "http://www.w3.org/2001/XMLSchema#int"
LETTERS = "ABCD"


def h(s):
    return html.escape(str(s), quote=True)


def opt(i, text):
    return f"{LETTERS[i]}) {text}"


# ── question papers ──────────────────────────────────────────────────────────
def stratified_pool(bank):
    rng = random.Random(20260826)
    by_level = {}
    for q in bank:
        by_level.setdefault(q["level"], []).append(q)
    for qs in by_level.values():
        rng.shuffle(qs)
    order, levels = [], [l for l in ("easy", "medium", "hard") if l in by_level]
    while any(by_level[l] for l in levels):
        for l in levels:
            if by_level[l]:
                order.append(by_level[l].pop())
    return order


def make_papers(bank, papers, per_paper):
    pool = stratified_pool(bank)
    n = len(pool)
    step = max(1, (n - per_paper) // max(1, papers - 1)) if papers > 1 else 0
    out = []
    for p in range(papers):
        start = (p * step) % n
        picked = [pool[(start + i) % n] for i in range(per_paper)]
        random.Random(f"paper-{p}-order").shuffle(picked)
        paper = []
        for q in picked:
            order = list(range(len(q["choices"])))
            random.Random(f"paper-{p}-q{q['id']}").shuffle(order)
            paper.append({"q": q, "order": order})
        out.append(paper)
    return out


def shown(item):
    return [(pos, orig, item["q"]["choices"][orig]) for pos, orig in enumerate(item["order"])]


def right_positions(item):
    return sorted(item["order"].index(c) for c in item["q"]["correct"])


# ── survey design ────────────────────────────────────────────────────────────
def question_config(item, position):
    """The answer control: radio buttons for one answer, tick boxes for several.

    The question itself is the card's subtitle, so the control carries no label
    and the options sit directly under the text.
    """
    q = item["q"]
    col = f"q{position:02d}"
    if q["type"] == "single":
        cfg = {
            "xtype": "radiogroup", "name": col, "hideLabel": True,
            "columns": 1, "vertical": True, "width": 820, "cls": "sd-answers",
            "items": [{"boxLabel": html.escape(opt(i, t)), "name": col, "inputValue": LETTERS[i]}
                      for i, _, t in shown(item)],
        }
    else:
        cfg = {
            "xtype": "fieldcontainer", "name": col, "hideLabel": True,
            "width": 820, "cls": "sd-answers",
            "items": [{
                "xtype": "panel", "border": False,
                "defaults": {"xtype": "checkbox", "inputValue": "true", "uncheckedValue": "false"},
                "items": [{"boxLabel": html.escape(opt(i, t)), "name": f"{col}_{LETTERS[i].lower()}"}
                          for i, _, t in shown(item)],
            }],
        }
    return {"extConfig": cfg}


def section_config(item, position, total, quiz_url):
    """One card of the wizard = one question."""
    q = item["q"]
    subtitle = f'<div class="sd-question">{html.escape(q["question"])}</div>'
    if q["type"] != "single":
        subtitle += (f'<div class="sd-hint">this answer has {len(q["correct"])} parts — '
                     f'tick every box that belongs to it</div>')
    return {"title": f"Question {position} of {total}", "subTitle": subtitle,
            "questions": [question_config(item, position), cancel_item(quiz_url)]}


def cancel_item(quiz_url):
    """A "Cancel the Quiz" button on the bottom of every card, next to the
    Previous / Next toolbar. It is a plain link — no JavaScript."""
    return {"extConfig": {
        "xtype": "displayfield", "hideLabel": True,
        "value": (f'<div style="margin-top:20px;padding-top:12px;border-top:1px solid #e0e6ec">'
                  f'<a class="labkey-button sd-cancel" href="{h(quiz_url)}"><span>Cancel the Quiz</span></a>'
                  f'<span style="color:#777;font-size:90%;margin-left:10px">'
                  f'leaves the quiz — nothing is recorded until you submit</span></div>'),
    }}


START_TEXT = (
    '<div style="max-width:760px">'
    '<p>The quiz has <b>{n}</b> questions and shows <b>one at a time</b>.</p>'
    '<ul>'
    '<li><b>Next</b> and <b>Previous</b> (bottom right) move between questions.</li>'
    '<li>Most questions have <b>one</b> answer — pick a radio button. The rest have an answer '
    'made of <b>several parts</b> — tick every box that belongs to it; the point counts only '
    'for the exact set.</li>'
    '<li>The last page has <b>Submit completed form</b>. Nothing is recorded before you press it, '
    'so <b>Cancel the Quiz</b> leaves no trace.</li>'
    '<li>You may take the quiz as often as you like; each run is a different set of questions.</li>'
    '</ul>'
    '<p>Press <b>Next</b> to see question 1.</p>'
    '<div style="margin-top:16px;padding-top:12px;border-top:1px solid #e0e6ec">'
    '<a class="labkey-button sd-cancel" href="{url}"><span>Cancel the Quiz</span></a></div>'
    '</div>')


def design_metadata(paper, per_paper, quiz_url):
    """The card layout is the wizard: one section = one card = one question.

    sidebarWidth (lower-case b — the panel reads `survey.sidebarWidth`) shrinks
    the step list the wizard insists on drawing; the project stylesheet hides
    what is left of it, so the student never sees "1. Start, 2. Q1, ...".
    start.useDefaultLabel drops the "Survey Label" box off the first card and
    stamps the attempt with the date instead, and disableAutoSave keeps a
    cancelled attempt out of the results.
    """
    return {"survey": {
        "layout": "card",
        "mainPanelWidth": 900,
        "sidebarWidth": 1,
        "showCounts": False,
        "disableAutoSave": True,
        "start": {
            "sectionTitle": "Start",
            "useDefaultLabel": True,
            "description": START_TEXT.format(n=per_paper, url=h(quiz_url)),
        },
        "sections": [section_config(item, i + 1, per_paper, quiz_url)
                     for i, item in enumerate(paper)],
    }}


def responses_domain(listname, paper, per_paper, paper_no):
    fields = [{"name": "Key", "rangeURI": INT}]
    for i, item in enumerate(paper):
        col = f"q{i + 1:02d}"
        if item["q"]["type"] == "single":
            fields.append({"name": col, "rangeURI": STR, "scale": 4,
                           "label": f"Q{i + 1} answer"})
        else:
            for j in range(len(item["q"]["choices"])):
                fields.append({"name": f"{col}_{LETTERS[j].lower()}", "rangeURI": STR, "scale": 8,
                               "label": f"Q{i + 1} {LETTERS[j]}"})
    return {
        "kind": "IntList",
        "domainDesign": {"name": listname,
                         "description": f"Quiz answers, paper {paper_no} ({per_paper} questions)",
                         "fields": fields},
        "options": {"keyName": "Key", "keyType": "AutoIncrementInteger"},
    }


# ── grading ──────────────────────────────────────────────────────────────────
def correct_expr(item, position):
    col = f"q{position:02d}"
    right = right_positions(item)
    if item["q"]["type"] == "single":
        return f"CASE WHEN {col} = '{LETTERS[right[0]]}' THEN 1 ELSE 0 END"
    terms = []
    for i in range(len(item["q"]["choices"])):
        c = f"COALESCE({col}_{LETTERS[i].lower()}, 'false') = 'true'"
        terms.append(c if i in right else f"NOT ({c})")
    return "CASE WHEN " + " AND ".join(terms) + " THEN 1 ELSE 0 END"


def given_expr(item, position):
    col = f"q{position:02d}"
    if item["q"]["type"] == "single":
        return f"COALESCE({col}, '-')"
    parts = [f"CASE WHEN COALESCE({col}_{LETTERS[i].lower()}, 'false') = 'true' THEN '{LETTERS[i]}' ELSE '' END"
             for i in range(len(item["q"]["choices"]))]
    return "(" + " || ".join(parts) + ")"


def score_sql(listname, paper, paper_no, per_paper):
    total = "\n    + ".join(correct_expr(it, i + 1) for i, it in enumerate(paper))
    per_q = "".join(f"  {correct_expr(it, i + 1)} AS q{i + 1:02d}_ok,\n" for i, it in enumerate(paper))
    return f"""-- Paper {paper_no}: one row per attempt (generated — do not edit by hand).
SELECT
  s.student, s.attempt, s.paper, s.started, s.last_change, s.n_correct, s.n_questions,
  ROUND(100.0 * s.n_correct / NULLIF(s.n_questions, 0), 1) AS percent_correct,
{''.join(f'  s.q{i + 1:02d}_ok,' + chr(10) for i in range(len(paper)))[:-2]}
FROM (
SELECT
  CreatedBy AS student,
  Key AS attempt,
  'Paper {paper_no}' AS paper,
  Created AS started,
  Modified AS last_change,
{per_q}  ({total}) AS n_correct,
  {per_paper} AS n_questions
FROM {listname}
) s"""


def review_sql(listname, paper, paper_no):
    branches = []
    for i, item in enumerate(paper):
        pos = i + 1
        branches.append(
            f"SELECT CreatedBy AS student, Key AS attempt, 'Paper {paper_no}' AS paper, "
            f"{pos} AS position, {item['q']['id']} AS qnum, "
            f"CAST({given_expr(item, pos)} AS VARCHAR) AS your_answer, "
            f"CASE WHEN {correct_expr(item, pos)} = 1 THEN 'right' ELSE 'wrong' END AS result, "
            f"Modified AS answered\nFROM {listname}")
    return (f"-- Paper {paper_no}: what each attempt answered, question by question.\n"
            + "\nUNION ALL\n".join(branches))


def history_sql(mine, n_papers):
    union = "\nUNION ALL\n".join(
        f"SELECT student, attempt, paper, started, last_change, n_correct, n_questions, percent_correct "
        f"FROM SD_score_paper{p + 1:02d}" for p in range(n_papers))
    where = "\nWHERE student = USERID()" if mine else ""
    who = "your own attempts" if mine else "every student's attempts"
    return f"""-- One row per attempt ({who}); a new attempt is a new row, so there is no limit.
SELECT student, paper, attempt AS attempt_no, n_correct AS correct, n_questions AS questions,
       percent_correct, started, last_change AS last_answer
FROM (
{union}
) a{where}"""


def launch_sql(n_papers):
    """One row, one cell: the link that opens this student's next paper.

    The paper rotates with the number of attempts already made, so a repeat is a
    different paper and nobody picks one by name. This is embedded straight into
    the quiz page, so "Start the quiz" opens the survey with no page in between.
    __DESIGN_n__ is replaced with the real survey design id once the designs exist.
    """
    cases = "\n".join(f"    WHEN {p + 1} THEN __DESIGN_{p + 1}__" for p in range(n_papers))
    return f"""-- The launch button embedded on the quiz page.
SELECT
  'Start the quiz' AS start_the_quiz,
  CASE n.paper_no
{cases}
  END AS design_id
FROM (
  SELECT MOD(COUNT(*), {n_papers}) + 1 AS paper_no
  FROM SD_my_attempts
) n"""


LAUNCH_METADATA = """<tables xmlns="http://labkey.org/data/xml">
  <table tableName="SD_launch" tableDbType="NOT_IN_DB">
    <columns>
      <column columnName="start_the_quiz">
        <columnTitle> </columnTitle>
        <url>{survey}</url>
        <urlTarget>_top</urlTarget>
      </column>
      <column columnName="design_id"><isHidden>true</isHidden></column>
    </columns>
    <buttonBarOptions position="none" includeStandardButtons="false"/>
  </table>
</tables>"""


def my_review_sql(n_papers):
    union = "\nUNION ALL\n".join(f"SELECT * FROM SD_review_paper{p + 1:02d}" for p in range(n_papers))
    return f"""-- Your answers, question by question, with the correct one beside them.
SELECT r.paper, r.attempt AS attempt_no, r.position, r.qnum, k.question, k.options,
       r.your_answer, k.correct_letters AS correct_answer, r.result, k.explanation, r.answered
FROM (
{union}
) r
LEFT JOIN SD_quiz_key k ON k.paper = r.paper AND k.position = r.position
WHERE r.student = USERID()"""


BACK_BUTTON = """<tables xmlns="http://labkey.org/data/xml">
  <table tableName="{name}" tableDbType="NOT_IN_DB">
    <buttonBarOptions position="both" includeStandardButtons="true">
      <item text="&#8592; Back to the quiz">
        <target>{url}</target>
      </item>
    </buttonBarOptions>
  </table>
</tables>"""

KEY_FIELDS = [
    {"name": "paper", "rangeURI": STR, "scale": 20, "label": "Paper"},
    {"name": "position", "rangeURI": INT, "label": "No."},
    {"name": "qnum", "rangeURI": INT, "label": "Pool Q"},
    {"name": "level", "rangeURI": STR, "scale": 20, "label": "Level"},
    {"name": "answer_type", "rangeURI": STR, "scale": 40, "label": "Answer type"},
    {"name": "question", "rangeURI": STR, "scale": 400, "label": "Question"},
    {"name": "options", "rangeURI": STR, "scale": 1200, "label": "Options as shown"},
    {"name": "correct_letters", "rangeURI": STR, "scale": 20, "label": "Correct"},
    {"name": "correct_answer", "rangeURI": STR, "scale": 700, "label": "Correct answer"},
    {"name": "explanation", "rangeURI": STR, "scale": 1000, "label": "Why"},
]


# ── pages ────────────────────────────────────────────────────────────────────
class Urls:
    def __init__(self, container):
        self.c = quote(container.strip("/"))

    def wiki(self, name):
        return f"/{self.c}/wiki-page.view?name={name}"

    def query(self, name):
        return f"/{self.c}/query-executeQuery.view?schemaName=lists&query.queryName={name}"

    def files(self, name):
        return f"/_webdav/{self.c}/%40files/quiz/{name}"

    def launcher(self):
        """The one-cell launch grid, stripped of page chrome, for embedding."""
        return (f"/{self.c}/query-executeQuery.view?schemaName=lists"
                f"&query.queryName=SD_launch&_template=Body")

    def survey_url_expression(self):
        """URL behind the launch button: the design id comes from the row, and
        submitting returns the student to their own attempt list."""
        ret = quote(self.query("SD_my_attempts"), safe="")
        return (f"/{self.c}/survey-updateSurvey.view?surveyDesignId=${{design_id}}"
                f"&returnUrl={ret}")


# The survey wizard always draws a numbered step list ("1. Start, 2. Q1, ...")
# down the left-hand side; there is no metadata switch for it. This goes into
# the project's custom stylesheet, between markers so a re-install can replace
# its own block and leave anything else in that stylesheet alone.
CSS_BEGIN = "/* BEGIN sleepdrive-lab quiz */"
CSS_END = "/* END sleepdrive-lab quiz */"
QUIZ_CSS = f"""{CSS_BEGIN}
/* Hide the survey wizard's step list: the quiz is navigated with Next and
   Previous only, and the list would give away the questions. */
.labkey-ancillary-wizard-background {{ display: none !important; }}
.lk-survey-panel .labkey-ancillary-wizard-steps {{ display: none !important; }}
/* A question and its options should read like text, not like a form. */
.sd-question {{ font-size: 15px; line-height: 1.45; max-width: 820px; }}
.sd-hint {{ margin-top: 6px; font-style: italic; color: #555; }}
.sd-answers .x4-form-cb-label {{ font-size: 14px; line-height: 1.5; padding-left: 4px; }}
.sd-answers .x4-form-item {{ margin-bottom: 4px; }}
/* LabKey title-cases button captions; "Cancel The Quiz" reads badly. */
a.labkey-button.sd-cancel span {{ text-transform: none; }}

/* The quiz page embeds the one-cell launch grid so that "Start the quiz" opens
   the survey directly, with no page in between. Every rule is scoped to a grid
   that actually contains the launch column — :has() keeps this off every other
   grid in the project, and where :has() is unsupported the block simply does
   nothing: the link still works, it just looks like an ordinary grid link. */
:root:has(th[data-column-name="query:start_the_quiz"]) body {{
  margin: 0; overflow: hidden; background: transparent; }}
:root:has(th[data-column-name="query:start_the_quiz"]) .lk-body-ct {{ padding: 0 !important; }}
:root:has(th[data-column-name="query:start_the_quiz"]) .lk-region-bar,
:root:has(th[data-column-name="query:start_the_quiz"]) .labkey-pagination {{ display: none !important; }}
table.labkey-data-region:has(th[data-column-name="query:start_the_quiz"]) {{ border: 0 !important; }}
table.labkey-data-region:has(th[data-column-name="query:start_the_quiz"]) .labkey-col-header-row {{
  display: none !important; }}
table.labkey-data-region:has(th[data-column-name="query:start_the_quiz"]) td,
table.labkey-data-region:has(th[data-column-name="query:start_the_quiz"]) tr {{
  border: 0 !important; padding: 0 !important; background: transparent !important; }}
table.labkey-data-region:has(th[data-column-name="query:start_the_quiz"]) td a {{
  display: inline-block; padding: 9px 22px; border-radius: 4px; background: #116596;
  color: #fff !important; text-decoration: none; font-weight: 600; font-size: 15px; }}
table.labkey-data-region:has(th[data-column-name="query:start_the_quiz"]) td a:hover {{
  background: #0d4f75; }}
{CSS_END}
"""

BTN = ("display:inline-block;padding:7px 17px;border-radius:4px;background:#116596;"
       "color:#fff;text-decoration:none;font-weight:600")
BTN_GREY = ("display:inline-block;padding:6px 14px;border-radius:4px;background:#eef3f8;"
            "color:#123; border:1px solid #c6cdd6;text-decoration:none")


def quiz_page(u, papers, per_paper, pool_size):
    n_multi = sum(1 for it in papers[0] if it["q"]["type"] == "multi")
    return f"""<h2>Lab quiz — {per_paper} questions on the sleep-drive paper</h2>
<p>The quiz shows <b>one question at a time</b>. Answer it and press <b>Next</b>; <b>Previous</b> goes
back, and <b>Cancel the Quiz</b> — the button under every question — leaves without recording anything.
Roughly {per_paper - n_multi} questions have a single answer (radio buttons) and {n_multi} have an
answer made of several parts (tick boxes — tick every part; the point counts only for the exact set).</p>

<p style="margin:22px 0"><iframe src="{h(u.launcher())}" title="Start the quiz"
   style="width:150px;height:42px;border:0;overflow:hidden;display:block"></iframe></p>

<div style="border:1px solid #d3dce6;border-left:5px solid #116596;background:#f6f9fc;padding:10px 14px;margin:16px 0">
<b>Good to know</b>
<ul style="margin:6px 0 0 18px">
<li>Take it <b>as often as you like</b> — every run draws another {per_paper} questions from a pool of
    {pool_size} and shuffles the answer order, so a repeat is a new paper.</li>
<li>Nothing is recorded until you press <b>Submit completed form</b> on the last page, so a
    cancelled quiz costs you nothing — but finish in one sitting.</li>
<li>You are recognised by your LabKey login: nothing to type, and you only see your own results.</li>
</ul>
</div>

<h3>Your history</h3>
<p><a href="{h(u.query('SD_my_attempts'))}"><b>My attempts</b></a> — one row per attempt with the score
and when you took it.<br/>
<a href="{h(u.query('SD_my_review'))}"><b>My answers</b></a> — every question you answered, what you
chose, what was right and why.</p>
<p style="color:#666;font-size:90%">Instructors: all students are in
<a href="{h(u.query('SD_quiz_history'))}">SD_quiz_history</a>, the key is
<a href="{h(u.query('SD_quiz_key'))}">SD_quiz_key</a>, and unfinished attempts show up under
Surveys.</p>
<p><a href="project-begin.view">← back to the lab</a></p>"""


# ── main ─────────────────────────────────────────────────────────────────────
def main():
    bank_path, outdir, container, n_papers, per_paper = (
        sys.argv[1], Path(sys.argv[2]), sys.argv[3], int(sys.argv[4]), int(sys.argv[5]))
    bank = sorted(json.load(open(bank_path, encoding="utf-8")), key=lambda q: q["id"])
    outdir.mkdir(parents=True, exist_ok=True)
    u = Urls(container)
    papers = make_papers(bank, n_papers, per_paper)

    lists, designs, queries, files, key_rows = [], [], [], [], []
    for idx, paper in enumerate(papers):
        no = idx + 1
        listname = f"SD_paper{no:02d}"
        (outdir / f"dom_{listname}.json").write_text(
            json.dumps(responses_domain(listname, paper, per_paper, no)), encoding="utf-8")
        lists.append(f"{listname}\tdom_{listname}.json")

        (outdir / f"design_{no:02d}.json").write_text(json.dumps({
            "label": f"Sleep-drive lab quiz — paper {no}",
            "description": f"{per_paper} questions drawn from the {len(bank)}-question pool",
            "schemaName": "lists", "queryName": listname,
            "metadata": json.dumps(design_metadata(paper, per_paper, u.wiki("quiz"))),
        }), encoding="utf-8")
        designs.append(f"{no}\tdesign_{no:02d}.json\t{listname}")

        for qname, sql in ((f"SD_score_paper{no:02d}", score_sql(listname, paper, no, per_paper)),
                           (f"SD_review_paper{no:02d}", review_sql(listname, paper, no))):
            (outdir / f"sql_{qname}.json").write_text(json.dumps({
                "schemaName": "lists", "queryName": qname, "ff_queryText": sql}), encoding="utf-8")
            queries.append(f"{qname}\tsql_{qname}.json\t{listname}")

        for i, item in enumerate(paper):
            q, right = item["q"], right_positions(item)
            key_rows.append({
                "paper": f"Paper {no}", "position": i + 1, "qnum": q["id"], "level": q["level"],
                "answer_type": "one answer" if q["type"] == "single"
                               else f"{len(right)} answers together",
                "question": q["question"],
                "options": "  ".join(opt(j, t) for j, _, t in shown(item)),
                "correct_letters": "+".join(LETTERS[j] for j in right),
                "correct_answer": " + ".join({j: t for j, _, t in shown(item)}[j] for j in right),
                "explanation": q.get("explanation") or "",
            })

    for qname, sql, meta in (
        ("SD_quiz_history", history_sql(False, n_papers), None),
        ("SD_my_attempts", history_sql(True, n_papers), "back"),
        ("SD_my_review", my_review_sql(n_papers), "back"),
        ("SD_launch", launch_sql(n_papers), "launch"),
    ):
        payload = {"schemaName": "lists", "queryName": qname, "ff_queryText": sql}
        if meta == "back":
            payload["ff_metadataText"] = BACK_BUTTON.format(name=qname, url=h(u.wiki("quiz")))
        elif meta == "launch":
            payload["ff_metadataText"] = LAUNCH_METADATA.format(
                survey=h(u.survey_url_expression()))
        (outdir / f"sql_{qname}.json").write_text(json.dumps(payload), encoding="utf-8")
        queries.append(f"{qname}\tsql_{qname}.json\tSD_paper01")

    with (outdir / "key.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=[f["name"] for f in KEY_FIELDS])
        w.writeheader()
        w.writerows(key_rows)
    (outdir / "key_schema.json").write_text(json.dumps({
        "name": "SD_quiz_key", "description": "Quiz answer key, per paper, in the order shown",
        "fields": KEY_FIELDS, "rows_written": len(key_rows)}), encoding="utf-8")

    (outdir / "wiki_quiz.html").write_text(quiz_page(u, papers, per_paper, len(bank)), encoding="utf-8")
    (outdir / "quiz.css").write_text(QUIZ_CSS, encoding="utf-8")

    (outdir / "lists.tsv").write_text("\n".join(lists) + "\n", encoding="utf-8")
    (outdir / "designs.tsv").write_text("\n".join(designs) + "\n", encoding="utf-8")
    (outdir / "queries.tsv").write_text("\n".join(queries) + "\n", encoding="utf-8")
    (outdir / "files.tsv").write_text("", encoding="utf-8")

    shared = min(len(({i["q"]["id"] for i in papers[a]} & {i["q"]["id"] for i in papers[b]}))
                 for a in range(len(papers)) for b in range(a + 1, len(papers))) if len(papers) > 1 else 0
    print(f"{n_papers} papers × {per_paper} questions from a pool of {len(bank)}; "
          f"as few as {shared} questions shared between two papers")


if __name__ == "__main__":
    main()
BUILD_QUIZ_PY
  chmod +x "$builder" 2>/dev/null || true
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$bank" \
    || die "quiz_bank.json is not valid JSON"

  rm -f "$DATA_DIR/quiz/form_a_bank.json" "$DATA_DIR/quiz/form_a_key.json" \
        "$DATA_DIR/quiz/quiz_wiki_body.html" "$DATA_DIR/quiz/quiz_key_body.html" \
        "$DATA_DIR/quiz/take_fields.json" "$DATA_DIR/quiz/grade_quiz.py" \
        "$DATA_DIR/quiz/build_quiz_html.py" "$DATA_DIR/quiz/quiz.html" \
        "$DATA_DIR/quiz/simple_quiz.html" "$DATA_DIR/quiz/simple_key.html" \
        "$DATA_DIR/quiz/survey_metadata.json" "$DATA_DIR/quiz/survey_answer_key.json" \
        "$DATA_DIR/quiz/survey_results_fields.json" 2>/dev/null || true
}

lk_form_post() {
  # folder action out kv...  — classic application/x-www-form-urlencoded POST
  local folder="$1" action="$2" out="$3"; shift 3
  local url args=() kv
  url="${base}/$(urlenc "$folder")/${action}"
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  curl "${api_flags[@]}" --connect-timeout 10 --max-time 120 --max-redirs 0 -X POST \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    "${args[@]}" --data-urlencode "X-LABKEY-CSRF=${csrf}" \
    -o "$out" -w '%{http_code}' "$url" 2>/dev/null || true
}

lk_get_json() {
  local folder="$1" action="$2" out="$3"
  curl "${api_flags[@]}" --max-redirs 0 "${auth_args[@]}" -H "Accept: application/json" \
    -b "$cookie_jar" -c "$cookie_jar" -o "$out" -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/${action}" 2>/dev/null || true
}

delete_domain() {
  local folder="$1" name="$2" http
  http="$(lk_post_json "$folder" "property-deleteDomain.api" \
    "$(printf '{"schemaName":"lists","queryName":"%s"}' "$name")" /tmp/sd-deldom.json)"
  [[ "$(http_code "$http")" == "200" ]]
}

delete_custom_query() {
  local folder="$1" name="$2" http
  http="$(http_code "$(lk_form_post "$folder" "query-deleteQuery.view" /tmp/sd-delq.html \
    "schemaName=lists" "queryName=${name}" "confirm=1")")"
  [[ "$http" == "302" || "$http" == "200" ]]
}

delete_wiki_page() {
  local folder="$1" page="$2" http
  http="$(http_code "$(lk_form_post "$folder" "wiki-delete.view" /tmp/sd-delwiki.html \
    "name=${page}" "confirm=1")")"
  [[ "$http" == "302" || "$http" == "200" ]]
}

enable_survey_module() {
  # the Survey module has to be active in the folder before survey designs and
  # the survey schema are reachable
  local folder="$1" mods args=() m
  lk_get_json "$folder" "project-getContainers.api?includeSubfolders=false" /tmp/sd-cont.json >/dev/null
  mods="$(python3 - <<'PY' 2>/dev/null || true
import json
try:
    d = json.load(open("/tmp/sd-cont.json"))
except Exception:
    d = {}
mods = d.get("activeModules") or []
print("\n".join(sorted(set(mods) | {"Survey", "List", "Query", "Wiki", "FileContent", "Experiment"})))
PY
)"
  [[ -n "$mods" ]] || mods=$'Survey\nList\nQuery\nWiki\nFileContent\nExperiment\nPipeline\nAPI\nCore\nSearch\nAnnouncements\nIssues'
  while IFS= read -r m; do [[ -n "$m" ]] && args+=("activeModules=${m}"); done <<< "$mods"
  lk_form_post "$folder" "admin-folderType.view" /tmp/sd-ftype.html \
    "folderType=Collaboration" "${args[@]}" >/dev/null
  if lk_get_json "$folder" "query-getQuery.api?schemaName=survey&query.queryName=SurveyDesigns&maxRows=1" \
       /tmp/sd-surveycheck.json | grep -q 200 && ! grep -q '"exception"' /tmp/sd-surveycheck.json; then
    log "  Survey module active in ${folder}"
  else
    warn "Survey module could not be activated in ${folder} — the quiz will not render"
    return 1
  fi
}

install_quiz_stylesheet() {
  # The survey wizard always draws a numbered step list down the left ("1. Start,
  # 2. Question 1 of 30, ...") and there is no metadata switch for it, so it is
  # hidden with a rule in the project's custom stylesheet. Anything already in
  # that stylesheet is kept: only the block between our own markers is replaced.
  local project="$1" css="$2" merged="/tmp/sd-project.css" http
  curl "${api_flags[@]}" --max-redirs 0 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" -o /tmp/sd-current.css -w '%{http_code}' \
    "${base}/$(urlenc "$project")/core-customStylesheet.view" >/dev/null 2>&1 || true
  python3 - "$css" /tmp/sd-current.css "$merged" <<'PY'
import re, sys
new = open(sys.argv[1], encoding="utf-8").read()
try:
    cur = open(sys.argv[2], encoding="utf-8", errors="replace").read()
except OSError:
    cur = ""
if "<html" in cur.lower() or "<!doctype" in cur.lower():
    cur = ""                      # an error page, not a stylesheet
cur = re.sub(r"/\* BEGIN sleepdrive-lab quiz \*/.*?/\* END sleepdrive-lab quiz \*/\s*",
             "", cur, flags=re.S)
open(sys.argv[3], "w", encoding="utf-8").write(cur.rstrip() + ("\n\n" if cur.strip() else "") + new)
PY
  http="$(curl "${api_flags[@]}" --connect-timeout 10 --max-time 120 --max-redirs 0 -X POST \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -F "customStylesheet=@${merged};filename=quiz.css;type=text/css" \
    -F "X-LABKEY-CSRF=${csrf}" \
    -o /tmp/sd-css.html -w '%{http_code}' "${base}/$(urlenc "$project")/admin-resources.view" 2>/dev/null || true)"
  if [[ "$http" != "200" && "$http" != "302" ]]; then
    warn "could not install the quiz stylesheet in ${project} (HTTP ${http}) — the survey will show its step list"
    return 1
  fi
  # confirm the server really serves it back
  curl "${api_flags[@]}" --max-redirs 0 "${auth_args[@]}" -b "$cookie_jar" -c "$cookie_jar" \
    -o /tmp/sd-check.css "${base}/$(urlenc "$project")/core-customStylesheet.view" >/dev/null 2>&1 || true
  if grep -q "sleepdrive-lab quiz" /tmp/sd-check.css 2>/dev/null; then
    log "  quiz stylesheet installed on project ${project}"
  else
    warn "quiz stylesheet was uploaded to ${project} but is not being served back"
    return 1
  fi
}

survey_design_id() {
  # folder label -> RowId on stdout (empty when the design does not exist yet)
  local folder="$1" label="$2"
  lk_get_json "$folder" "query-getQuery.api?schemaName=survey&query.queryName=SurveyDesigns&query.maxRows=-1" \
    /tmp/sd-designs.json >/dev/null
  LABEL="$label" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    rows = json.load(open("/tmp/sd-designs.json")).get("rows", [])
except Exception:
    rows = []
want = os.environ["LABEL"]
print(next((r["RowId"] for r in rows if (r.get("Label") or "") == want), ""))
PY
}

save_survey_design() {
  # folder designFile -> creates or updates the design, prints its RowId
  local folder="$1" file="$2" label rowid http payload
  label="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["label"])' "$file")"
  rowid="$(survey_design_id "$folder" "$label")"
  payload="$file"
  if [[ -n "$rowid" ]]; then
    payload="${file}.update"
    python3 - "$file" "$rowid" "$payload" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["rowId"] = int(sys.argv[2])
json.dump(d, open(sys.argv[3], "w", encoding="utf-8"))
PY
  fi
  http="$(http_code "$(lk_post_json "$folder" "survey-saveSurveyTemplate.api" "@${payload}" /tmp/sd-design.json)")"
  if [[ "$http" != "200" ]] || ! grep -q '"success" : true' /tmp/sd-design.json; then
    warn "survey design '${label}' HTTP ${http}: $(head -c 250 /tmp/sd-design.json)"
    return 1
  fi
  [[ -n "$rowid" ]] || rowid="$(survey_design_id "$folder" "$label")"
  printf '%s' "$rowid"
}

retire_old_quiz() {
  # lists, queries and wiki pages of every earlier quiz generation
  local folder="$1" name page
  lk_get_json "$folder" "wiki-getPages.api" /tmp/sd-pages.json >/dev/null
  python3 - <<'PY' > /tmp/sd-oldpages.txt 2>/dev/null || true
import json, re
try:
    pages = json.load(open("/tmp/sd-pages.json")).get("pages", [])
except Exception:
    pages = []
dead = re.compile(r"^(go-[a-z]-\d{2}|quiz-[a-z]|done-[a-z]|quiz-key)$")
print("\n".join(p["name"] for p in pages if dead.match(p.get("name", ""))))
PY
  while IFS= read -r page; do
    [[ -n "$page" ]] || continue
    delete_wiki_page "$folder" "$page" >/dev/null && log "  removed obsolete wiki page ${page}"
  done < /tmp/sd-oldpages.txt

  lk_get_json "$folder" "query-getQueries.api?schemaName=lists" /tmp/sd-queries.json >/dev/null
  python3 - <<'PY' > /tmp/sd-oldqueries.txt 2>/dev/null || true
import json, re
try:
    qs = json.load(open("/tmp/sd-queries.json")).get("queries", [])
except Exception:
    qs = []
dead = re.compile(r"^(SD_ans_[A-Z]|SD_quiz_answers|SD_quiz_latest|SD_score_part\d|"
                  r"SD_quiz_scores|SD_quiz_total|SD_start_quiz)$")
print("\n".join(q["name"] for q in qs if dead.match(q.get("name", ""))))
PY
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    delete_custom_query "$folder" "$name" >/dev/null && log "  removed obsolete query ${name}"
  done < /tmp/sd-oldqueries.txt

  lk_get_json "$folder" "query-getQueries.api?schemaName=lists&includeUserQueries=false" \
    /tmp/sd-lists.json >/dev/null
  python3 - <<'PY' > /tmp/sd-oldlists.txt 2>/dev/null || true
import json, re
try:
    qs = json.load(open("/tmp/sd-lists.json")).get("queries", [])
except Exception:
    qs = []
dead = re.compile(r"^(SD_qa_[A-Z]\d{2}|SD_quiz_part\d|SD_quiz_take|SD_quiz_attempts|"
                  r"SD_quiz_bank|SD_quiz_responses)$")
print("\n".join(q["name"] for q in qs if dead.match(q.get("name", ""))))
PY
  local n=0
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    delete_domain "$folder" "$name" && n=$((n + 1))
  done < /tmp/sd-oldlists.txt
  [[ "$n" -gt 0 ]] && log "  removed ${n} obsolete answer lists"
  return 0
}

setup_quiz() {
  local folder="${LK_PROJECT}/${LK_FOLDER}"
  local dir="$DATA_DIR/quiz/prepared"
  local built name file basetable no listname designid ok bad

  ensure_quiz_assets
  rm -rf "$dir"; mkdir -p "$dir"
  built="$(python3 "$DATA_DIR/quiz/build_quiz.py" "$DATA_DIR/quiz/quiz_bank.json" "$dir" \
      "$folder" "$LK_QUIZ_PAPERS" "$LK_QUIZ_QUESTIONS")" \
    || die "could not build the quiz from quiz_bank.json"
  log "quiz: ${built}"

  enable_survey_module "$folder" || return 1
  install_quiz_stylesheet "$LK_PROJECT" "$dir/quiz.css" || true
  retire_old_quiz "$folder"

  # answer lists — one per paper, one row per attempt
  ok=0; bad=0
  while IFS=$'\t' read -r name file; do
    [[ -n "$name" ]] || continue
    if list_exists "$folder" "$name" && [[ "$LK_FORCE" -eq 1 ]]; then
      delete_domain "$folder" "$name" || warn "could not drop ${name}"
    fi
    if list_exists "$folder" "$name"; then
      ok=$((ok + 1))
    elif [[ "$(http_code "$(lk_post_json "$folder" "property-createDomain.api" "@${dir}/${file}" /tmp/sd-qdom.json)")" == "200" ]]; then
      ok=$((ok + 1))
    else
      bad=$((bad + 1)); warn "answer list ${name}: $(head -c 200 /tmp/sd-qdom.json)"
    fi
  done < "$dir/lists.tsv"
  log "  answer lists: ${ok} ready$( [[ $bad -gt 0 ]] && echo ", ${bad} failed" )"

  # survey designs — one per paper — then bake their ids into SD_launch
  : > "$dir/design_ids.tsv"
  while IFS=$'\t' read -r no file listname; do
    [[ -n "$no" ]] || continue
    designid="$(save_survey_design "$folder" "$dir/$file")" || continue
    [[ -n "$designid" ]] && printf '%s\t%s\n' "$no" "$designid" >> "$dir/design_ids.tsv"
  done < "$dir/designs.tsv"
  log "  survey papers: $(wc -l < "$dir/design_ids.tsv") ready"
  python3 - "$dir/design_ids.tsv" "$dir/sql_SD_launch.json" <<'PY' || die "could not map survey design ids"
import json, sys
ids = {}
for line in open(sys.argv[1], encoding="utf-8"):
    if line.strip():
        paper, rowid = line.split("\t")
        ids[paper.strip()] = rowid.strip()
path = sys.argv[2]
doc = json.load(open(path, encoding="utf-8"))
sql = doc["ff_queryText"]
for paper, rowid in ids.items():
    sql = sql.replace(f"__DESIGN_{paper}__", rowid)
if "__DESIGN_" in sql:
    raise SystemExit("some papers have no survey design id")
doc["ff_queryText"] = sql
json.dump(doc, open(path, "w", encoding="utf-8"))
PY

  # answer key (rebuilt each run so it cannot pick up a second copy)
  LK_FORCE=1 import_list "$folder" "$dir/key.csv" "$dir/key_schema.json" \
    "SD_quiz_key" "Quiz answer key, per paper, in the order shown" || true

  # grading, history, review and the rotating start page
  while IFS=$'\t' read -r name file basetable; do
    [[ -n "$name" ]] || continue
    lk_form_post "$folder" "query-newQuery.view" /tmp/sd-newquery.html \
      "schemaName=lists" "ff_newQueryName=${name}" "ff_baseTableName=${basetable}" \
      "ff_redirect=sourceQuery" >/dev/null
    if [[ "$(http_code "$(lk_post_json "$folder" "query-saveSourceQuery.api" "@${dir}/${file}" /tmp/sd-savequery.json)")" != "200" ]] \
       || grep -q '"parseErrors"' /tmp/sd-savequery.json 2>/dev/null; then
      warn "query ${name}: $(head -c 300 /tmp/sd-savequery.json)"
    fi
  done < "$dir/queries.tsv"
  log "  scoring and history queries ready"

  save_wiki "$folder" "Lab quiz" "$(cat "$dir/wiki_quiz.html")" "quiz" || true

  log "quiz ready — ${base}/$(urlenc "$folder")/wiki-page.view?name=quiz"
}

HELPER="$DATA_DIR/helper.py"
cookie_jar="$DATA_DIR/cookies.txt"

if ! python3 -c 'import openpyxl' 2>/dev/null; then
  log "installing openpyxl…"
  python3 -m pip install --user -q openpyxl \
    || python3 -m pip install -q openpyxl \
    || die "openpyxl required (pip install openpyxl)"
fi
base="${LK_URL%/}"
api_flags=(-sS)
[[ "$LK_INSECURE" == "1" ]] && api_flags+=(-k)
auth_args=()
[[ -n "$LK_APIKEY" ]] && auth_args+=(-H "Authorization: LabKeyApiKey $LK_APIKEY")

# Source Data Fig. 1–5 (Springer Nature open access ESM)
SOURCES_JSON='[
  {"id":"fig1","name":"Source Data Fig. 1","file":"fig1.xlsx",
   "url":"https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_MOESM3_ESM.xlsx",
   "note":"Fos clusters, example subregions, wake proportion"},
  {"id":"fig2","name":"Source Data Fig. 2","file":"fig2.xlsx",
   "url":"https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_MOESM4_ESM.xlsx",
   "note":"TRAP, chemogenetic activation (CNO) sleep metrics"},
  {"id":"fig3","name":"Source Data Fig. 3","file":"fig3.xlsx",
   "url":"https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_MOESM5_ESM.xlsx",
   "note":"Inhibition / sleep propensity assays"},
  {"id":"fig4","name":"Source Data Fig. 4","file":"fig4.xlsx",
   "url":"https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_MOESM6_ESM.xlsx",
   "note":"Median raphe projections and cell types"},
  {"id":"fig5","name":"Source Data Fig. 5","file":"fig5.xlsx",
   "url":"https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_MOESM7_ESM.xlsx",
   "note":"GABA/5-HT co-modulation; Kir2.1 inhibition"}
]'
printf '%s\n' "$SOURCES_JSON" > "$DATA_DIR/sources.json"

# Main-text figure PNGs (Nature CDN, open-access article)
FIGURES_JSON='[
  {"id":"fig1","file":"Fig1.png","caption":"Fig. 1 — Mapping of whole-brain activity reveals correlates of sleep deprivation and recovery.",
   "url":"https://media.springernature.com/full/springer-static/image/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_Fig1_HTML.png"},
  {"id":"fig2","file":"Fig2.png","caption":"Fig. 2 — Deprivation-TRAP cells promote NREM sleep and slow-wave activity.",
   "url":"https://media.springernature.com/full/springer-static/image/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_Fig2_HTML.png"},
  {"id":"fig3","file":"Fig3.png","caption":"Fig. 3 — Targets and projection-specific functions of MR deprivation-TRAP cells.",
   "url":"https://media.springernature.com/full/springer-static/image/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_Fig3_HTML.png"},
  {"id":"fig4","file":"Fig4.png","caption":"Fig. 4 — MR GABAergic cells synergistically promote sleep with serotonergic cells.",
   "url":"https://media.springernature.com/full/springer-static/image/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_Fig4_HTML.png"},
  {"id":"fig5","file":"Fig5.png","caption":"Fig. 5 — Inhibition of MR GABAergic and serotonergic cells stably reduces sleep drive.",
   "url":"https://media.springernature.com/full/springer-static/image/art%3A10.1038%2Fs41586-026-10928-3/MediaObjects/41586_2026_10928_Fig5_HTML.png"}
]'
printf '%s\n' "$FIGURES_JSON" > "$DATA_DIR/figures.json"

cat > "$HELPER" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import csv, json, os, re, sys, time
from typing import Any

def scrub(s: Any) -> str:
    if s is None:
        return ""
    if isinstance(s, (dict, list)):
        s = json.dumps(s, ensure_ascii=False)
    return re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", str(s).replace("\x00", ""))[:4000]

def clean_col(name: str, used: set[str]) -> str:
    s = re.sub(r"[^A-Za-z0-9_]+", "_", scrub(name)).strip("_") or "col"
    if s[0].isdigit():
        s = "c_" + s
    if s.lower() in {"key", "entityid", "container"}:
        s = "c_" + s
    base, n = s, 2
    while s.lower() in used:
        s = f"{base}_{n}"
        n += 1
    used.add(s.lower())
    return s[:80]

def infer_uri(vals: list[str]) -> str:
    nums = 0
    for v in vals:
        if not v:
            continue
        try:
            float(v)
            nums += 1
        except Exception:
            return "http://www.w3.org/2001/XMLSchema#string"
    if nums:
        return "http://www.w3.org/2001/XMLSchema#double"
    return "http://www.w3.org/2001/XMLSchema#string"

def write_rows(path: str, rows: list[dict[str, str]], max_rows: int = 0) -> tuple[int, list[dict]]:
    if not rows:
        return 0, []
    keys: list[str] = []
    seen: set[str] = set()
    for r in rows:
        for k in r:
            if k not in seen:
                seen.add(k)
                keys.append(k)
    used: set[str] = set()
    headers = [clean_col(k, used) for k in keys]
    samples = {h: [] for h in headers}
    n = 0
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(headers)
        for r in rows:
            if max_rows and n >= max_rows:
                break
            vals = [r.get(k, "") for k in keys]
            w.writerow(vals)
            if n < 250:
                for h, v in zip(headers, vals):
                    samples[h].append(v)
            n += 1
    fields = []
    for h in headers:
        uri = infer_uri(samples[h])
        item = {"name": h, "rangeURI": uri, "label": h}
        if uri.endswith("string"):
            item["inferred"] = "string"
            item["scale"] = 4000
        else:
            item["inferred"] = "double"
        fields.append(item)
    return n, fields

def _nn(row) -> list:
    return [c for c in row if c is not None and str(c).strip() != ""]

def sheet_blocks(ws) -> list[tuple[str, list[str], list[list[Any]]]]:
    """Split a Nature source sheet into (section_title, headers, data_rows)."""
    all_rows = [list(r) for r in ws.iter_rows(values_only=True)]
    blocks: list[tuple[str, list[str], list[list[Any]]]] = []
    title = "block"
    i, n = 0, len(all_rows)
    while i < n:
        row = all_rows[i]
        cells = _nn(row)
        if not cells:
            i += 1
            continue
        # section title row
        if len(cells) == 1 and not isinstance(cells[0], (int, float)):
            title = str(cells[0]).strip()[:120]
            i += 1
            continue
        # header + following data until blank or new title
        if len(cells) >= 2:
            headers = [(str(c).strip() if c is not None else f"col_{j}") for j, c in enumerate(row)]
            data: list[list[Any]] = []
            i += 1
            while i < n:
                r = all_rows[i]
                rc = _nn(r)
                if not rc:
                    i += 1
                    break
                if (len(rc) == 1 and not isinstance(rc[0], (int, float))
                        and not any(isinstance(c, (int, float)) for c in r if c is not None)):
                    break
                data.append(r)
                i += 1
            if data:
                keep = [j for j in range(len(headers))
                        if any(j < len(r) and r[j] is not None and str(r[j]).strip() != ""
                               for r in data)]
                if keep:
                    h2 = [headers[j] for j in keep]
                    d2 = [[(r[j] if j < len(r) else None) for j in keep] for r in data]
                    blocks.append((title, h2, d2))
            continue
        i += 1
    return blocks

def cmd_convert() -> None:
    import openpyxl
    xlsx, dest, max_rows = sys.argv[2], sys.argv[3], int(sys.argv[4])
    os.makedirs(dest, exist_ok=True)
    wb = openpyxl.load_workbook(xlsx, read_only=True, data_only=True)
    manifest = []
    for sheet in wb.sheetnames:
        blocks = sheet_blocks(wb[sheet])
        if not blocks:
            continue
        for bi, (title, headers, data) in enumerate(blocks):
            sid = re.sub(r"[^A-Za-z0-9_]+", "_", sheet)[:40]
            if len(blocks) > 1:
                sid = f"{sid}_b{bi+1}"
            rows = []
            for r in data:
                rec = {"section": title}
                for h, v in zip(headers, r):
                    rec[str(h)] = scrub(v)
                rows.append(rec)
            csv_path = os.path.join(dest, f"{sid}.csv")
            n, fields = write_rows(csv_path, rows, max_rows)
            schema_path = os.path.join(dest, f"{sid}.schema.json")
            with open(schema_path, "w", encoding="utf-8") as fh:
                json.dump({"ok": n > 0, "rows_written": n, "n_columns": len(fields),
                           "fields": fields, "sheet": sheet, "section": title}, fh, indent=2)
            manifest.append({"id": sid, "sheet": sheet, "section": title, "rows": n,
                             "csv": csv_path, "schema": schema_path})
    wb.close()
    out = os.path.join(dest, "manifest.json")
    json.dump(manifest, open(out, "w", encoding="utf-8"), indent=2)
    print(json.dumps({"ok": len(manifest) > 0, "tables": len(manifest), "manifest": out}))

def cmd_domain() -> None:
    schema = json.load(open(sys.argv[2], encoding="utf-8"))
    name = scrub(sys.argv[3])[:200]
    desc = scrub(sys.argv[4] if len(sys.argv) > 4 else "")[:400]
    fields = [{"name": "Key", "rangeURI": "http://www.w3.org/2001/XMLSchema#int"}]
    for f in schema.get("fields") or []:
        item = {"name": scrub(f["name"])[:80],
                "rangeURI": f.get("rangeURI") or "http://www.w3.org/2001/XMLSchema#string",
                "label": scrub(f.get("label") or f["name"])[:200]}
        if f.get("inferred") == "string":
            item["scale"] = int(f.get("scale") or 4000)
        fields.append(item)
    json.dump({"kind": "IntList",
               "domainDesign": {"name": name, "description": desc, "fields": fields},
               "options": {"keyName": "Key", "keyType": "AutoIncrementInteger"}}, sys.stdout)

def cmd_rows() -> None:
    path = sys.argv[2]
    with open(path, encoding="utf-8", newline="") as fh:
        rows = [{k: scrub(v) for k, v in rec.items() if k} for rec in csv.DictReader(fh)]
    json.dump(rows, sys.stdout)

def cmd_student_populate() -> None:
    dest = sys.argv[2]
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    rows = [
        {"reviewer": "auto", "claim_id": "SLEEP-DRIVE-AMPO-MR",
         "figure": "Fig1-2", "region": "aMPO / median raphe",
         "finding": "Regions encode sleep deficit; activation mimics recovery sleep",
         "supported_by_source_data": "yes", "grade": "A", "suggested_grade": "A",
         "rubric_score": "90", "notes": "Core claim of the paper; see Fos maps + chemogenetics",
         "date": time.strftime("%Y-%m-%d")},
        {"reviewer": "auto", "claim_id": "SLEEP-DRIVE-COINHIBITION",
         "figure": "Fig5", "region": "GABA + serotonergic MR",
         "finding": "Co-inhibition decreases sleep by nearly 70%",
         "supported_by_source_data": "yes", "grade": "A", "suggested_grade": "A",
         "rubric_score": "88", "notes": "Check Fig5 control vs Kir2.1 animal time series",
         "date": time.strftime("%Y-%m-%d")},
        {"reviewer": "auto", "claim_id": "SLEEP-DRIVE-ATLAS",
         "figure": "atlas", "region": "whole brain",
         "finding": "Whole-brain atlas is public at sleep-wake-atlas.scicore.unibas.ch",
         "supported_by_source_data": "partial", "grade": "B", "suggested_grade": "B",
         "rubric_score": "70", "notes": "Atlas is external; source XLSX are figure-level",
         "date": time.strftime("%Y-%m-%d")},
    ]
    n, fields = write_rows(dest, rows, 0)
    schema_dir = os.path.dirname(dest) or "."
    json.dump({"ok": n > 0, "rows_written": n, "n_columns": len(fields), "fields": fields},
              open(os.path.join(schema_dir, "schema.json"), "w", encoding="utf-8"), indent=2)
    print(json.dumps({"ok": n > 0, "rows": n}))

def cmd_wiki_fields() -> None:
    html = open("/tmp/sd-wikiedit.html", encoding="utf-8", errors="replace").read()
    fields = {}
    for m in re.finditer(r"<input[^>]+>", html, re.I):
        tag = m.group(0)
        n = re.search(r'name=["\']([^"\']+)["\']', tag, re.I)
        v = re.search(r'value=["\']([^"\']*)["\']', tag, re.I)
        if n:
            fields[n.group(1)] = v.group(1) if v else ""
    entity = fields.get("entityId") or fields.get("entityid") or ""
    if not entity:
        m = re.search(r'entityId["\s:=]+["\']([0-9a-fA-F-]{36})["\']', html)
        entity = m.group(1) if m else ""
    if entity:
        fields["entityId"] = entity
    vers = [int(x) for x in re.findall(r"pageVersionId[^0-9]{0,40}(\d+)", html)]
    if vers:
        fields["pageVersionId"] = str(max(vers))
    fields["name"] = fields.get("name") or "home"
    fields["title"] = sys.argv[2]
    fields["body"] = sys.argv[3]
    fields["rendererType"] = "HTML"
    fields["save"] = "Save"
    if len(sys.argv) > 4 and sys.argv[4]:
        fields["X-LABKEY-CSRF"] = sys.argv[4]
    json.dump({"entityId": entity, "fields": fields}, sys.stdout)

if __name__ == "__main__":
    cmds = {
        "convert": cmd_convert,
        "domain": cmd_domain,
        "rows": cmd_rows,
        "student_populate": cmd_student_populate,
        "wiki_fields": cmd_wiki_fields,
    }
    if len(sys.argv) < 2 or sys.argv[1] not in cmds:
        print(
            "usage: helper.py convert|domain|rows|student_populate|wiki_fields ...",
            file=sys.stderr,
        )
        sys.exit(2)
    cmds[sys.argv[1]]()
PY
chmod +x "$HELPER"

urlenc() { printf '%s' "$1" | sed 's/ /%20/g'; }
http_code() { printf '%s' "$1" | tr -cd '0-9' | tail -c 3; }

# Fail fast if LabKey is down (avoids hundreds of curl (7) lines)
require_labkey() {
  local code
  code="$(curl "${api_flags[@]}" --connect-timeout 3 --max-time 8 \
    -o /tmp/sd-ping.html -w '%{http_code}' \
    "${base}/project-begin.view" 2>/dev/null || true)"
  code="$(http_code "$code")"
  if [[ -z "$code" || "$code" == "000" ]]; then
    die "LabKey not reachable at ${base}
  Start the server first, e.g.:
    bash build-labkey-community.sh   # or your usual start script
  Then re-run this installer with the same --url.
  Tip: without --import this script can still download/convert data offline."
  fi
  log "LabKey reachable (${base} → HTTP ${code})"
}

login_session() {
  csrf=""
  rm -f "$cookie_jar"
  require_labkey
  if [[ -n "$LK_APIKEY" ]]; then
    log "session (API key) on $base"
    return 0
  fi
  [[ -n "$LK_USER" && -n "$LK_PASSWORD" ]] || die "need --user/--password or --apikey"
  local code
  code="$(curl "${api_flags[@]}" --connect-timeout 5 --max-time 30 \
    -c "$cookie_jar" -b "$cookie_jar" \
    -d "email=${LK_USER}&password=${LK_PASSWORD}" \
    -o /tmp/sd-login.html -w '%{http_code}' \
    "${base}/login-loginApi.api" 2>/dev/null || true)"
  code="$(http_code "$code")"
  if [[ "$code" != "200" && "$code" != "302" && "$code" != "303" ]]; then
    die "LabKey login failed (HTTP ${code:-000}) at ${base}/login-loginApi.api — check --user/--password"
  fi
  csrf="$(python3 -c '
import re
t=open("/tmp/sd-login.html",encoding="utf-8",errors="replace").read()
m=re.search(r"CSRF[^0-9A-Za-z]*([0-9A-Za-z_-]{8,})", t)
print(m.group(1) if m else "")
' 2>/dev/null || true)"
  if [[ -z "$csrf" ]]; then
    csrf="$(grep -oE 'X-LABKEY-CSRF[^,}]{0,40}' /tmp/sd-login.html 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$csrf" && -f "$cookie_jar" ]]; then
    csrf="$(awk '/X-LABKEY-CSRF|CSRF/{print $NF; exit}' "$cookie_jar" 2>/dev/null || true)"
  fi
  log "session on $base (login HTTP ${code})"
}

lk_post_json() {
  # payload may be huge (Fig.5 matrices) — never pass it on the argv (ARG_MAX)
  local folder="$1" action="$2" payload="$3" out="$4" url http bodyf
  url="${base}/$(urlenc "$folder")/${action}"
  [[ "$folder" == "/" || -z "$folder" ]] && url="${base}/${action}"
  bodyf="$(mktemp /tmp/sd-body.XXXXXX.json)"
  # payload is either a JSON string or a path to a file starting with @
  if [[ "$payload" == @* && -f "${payload#@}" ]]; then
    cp -f "${payload#@}" "$bodyf"
  else
    printf '%s' "$payload" > "$bodyf"
  fi
  http="$(curl "${api_flags[@]}" --connect-timeout 10 --max-time 300 --max-redirs 0 -X POST \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    --data-binary @"$bodyf" -o "$out" -w '%{http_code}' "$url" || true)"
  rm -f "$bodyf"
  printf '%s' "$http"
}

ensure_container() {
  local parent="$1" name="$2" payload
  payload="$(printf '{"name":"%s","title":"%s","folderType":"Collaboration","isWorkbook":false}' "$name" "$name")"
  lk_post_json "$parent" "core-createContainer.api" "$payload" "/tmp/sd-create.json" >/dev/null || true
}

list_exists() {
  local folder="$1" listname="$2"
  curl "${api_flags[@]}" --max-redirs 0 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" -H "Accept: application/json" \
    -o /tmp/sd-q.json -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/query-getQuery.api?schemaName=lists&query.queryName=${listname}&maxRows=1" \
    >/tmp/sd-q.http || true
  [[ "$(http_code "$(cat /tmp/sd-q.http)")" == "200" ]]
}

import_list() {
  local folder="$1" csv="$2" schema="$3" listname="$4" desc="$5" payload http
  [[ -s "$csv" && -s "$schema" ]] || return 1
  if list_exists "$folder" "$listname"; then
    if [[ "$LK_FORCE" -eq 0 ]]; then
      log "  list ${listname} exists — skip"
      return 0
    fi
    # --force means rebuild, not append: without the drop every re-run added
    # another full copy of the CSV to the list
    delete_domain "$folder" "$listname" || warn "could not drop ${listname}"
  fi
  # createDomain: 500 "already in use" is OK when re-running
  python3 "$HELPER" domain "$schema" "$listname" "$desc" > /tmp/sd-domain-req.json
  http="$(lk_post_json "$folder" "property-createDomain.api" "@/tmp/sd-domain-req.json" "/tmp/sd-domain.json")"
  log "  createDomain ${listname} HTTP $(http_code "$http")"
  if [[ "$(http_code "$http")" != "200" ]]; then
    # domain may already exist — continue to import rows
    true
  fi
  # Build insert payload on disk (avoid ARG_MAX)
  python3 - "$csv" "$listname" <<'PY' > /tmp/sd-insert-req.json
import json, sys, csv
csv_path, listname = sys.argv[1], sys.argv[2]
with open(csv_path, encoding="utf-8", newline="") as fh:
    rows = list(csv.DictReader(fh))
# drop empty keys; coerce simple numbers
clean = []
for r in rows:
    o = {}
    for k, v in r.items():
        if k is None or k == "":
            continue
        if v is None or v == "":
            o[k] = None
            continue
        try:
            if "." in str(v):
                o[k] = float(v)
            else:
                o[k] = int(v)
        except Exception:
            o[k] = v
    clean.append(o)
json.dump({"schemaName": "lists", "queryName": listname, "rows": clean}, sys.stdout)
PY
  http="$(lk_post_json "$folder" "query-insertRows.api" "@/tmp/sd-insert-req.json" "/tmp/sd-insert.json")"
  if [[ "$(http_code "$http")" == "200" ]]; then
    log "  imported ${listname} via insertRows"
    return 0
  fi
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
    -H "Accept: application/json" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -F "schemaName=lists" -F "queryName=${listname}" \
    -F "insertOption=INSERT" -F "importIdentity=false" \
    -F "file=@${csv};type=text/csv" \
    -o /tmp/sd-import.json -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/query-import.api" || true)"
  log "  query-import ${listname} HTTP $(http_code "$http")"
  list_exists "$folder" "$listname"
}

save_wiki() {
  local folder="$1" title="$2" body="$3" page="${4:-home}" http entity rowid ver
  printf '%s' "$body" > /tmp/sd-wikibody.html
  curl "${api_flags[@]}" --max-redirs 5 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" \
    -o /tmp/sd-wikiedit.html \
    "${base}/$(urlenc "$folder")/wiki-editWiki.view?name=${page}" >/dev/null || true
  python3 "$HELPER" wiki_fields "$title" "$body" "${csrf:-}" \
    > /tmp/sd-wikifields.json 2>/dev/null || true
  entity="$(python3 -c 'import json; print(json.load(open("/tmp/sd-wikifields.json")).get("entityId") or "")' 2>/dev/null || true)"
  rowid="$(python3 -c 'import json; print((json.load(open("/tmp/sd-wikifields.json")).get("fields") or {}).get("rowId") or "")' 2>/dev/null || true)"
  ver="$(python3 -c 'import json; print((json.load(open("/tmp/sd-wikifields.json")).get("fields") or {}).get("pageVersionId") or "")' 2>/dev/null || true)"
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -F "name=${page}" \
    -F "title=${title}" \
    -F "rendererType=HTML" \
    -F "body=</tmp/sd-wikibody.html" \
    -F "save=Save" \
    ${entity:+-F "entityId=${entity}"} \
    ${rowid:+-F "rowId=${rowid}"} \
    ${ver:+-F "pageVersionId=${ver}"} \
    -o /tmp/sd-wiki.json -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/wiki-saveWiki.post" || true)"
  log "  wiki ${page} HTTP $(http_code "$http") (${title})"
}

project_wiki() {
  cat <<EOF
<h2>Sleep Drive Lab — student onboarding</h2>
<p>Paper: <em>${PAPER_TITLE}</em><br/>
DOI <a href="${PAPER_URL}">${PAPER_DOI}</a> · Open Access · Nature 19 Aug 2026<br/>
Authors: Joo, Diester, Bitsikas, … Schier et al.</p>
<p>Open <a href="$(urlenc "$LK_FOLDER")/project-begin.view"><strong>${LK_FOLDER}</strong></a>
for the five Source Data Excel tables (Figs 1–5) converted to LabKey lists.</p>
<p>Whole-brain atlas (external): <a href="${ATLAS_URL}">${ATLAS_URL}</a></p>
<h3>Your exercise (45–60 min)</h3>
<p>Test the paper’s central claim using <strong>only</strong> the imported source tables
and the atlas link. Hand in one row in
<a href="$(urlenc "$LK_FOLDER")/query-executeQuery.view?schemaName=lists&amp;query.queryName=SD_student_review">SD_student_review</a>.</p>
<p>Start: <a href="$(urlenc "$LK_FOLDER")/wiki-page.view?name=claim">Exercise brief</a>
 · <a href="$(urlenc "$LK_FOLDER")/wiki-page.view?name=quiz"><strong>Lab quiz</strong></a></p>
EOF
}

landing_wiki() {
  cat <<EOF
<h2>Onboarding — Source Data Lab</h2>
<p>Subfolders <strong>fig1</strong>…<strong>fig5</strong> hold lists from the Nature
Source Data Excel files. Each sheet/block is one list (<code>SD_*</code>).
Main-text figures are under Files → <code>figures/Fig1.png</code>…<code>Fig5.png</code>
and embedded on the step wiki pages.</p>
<p>Paper: <a href="${PAPER_URL}">${PAPER_TITLE}</a> (${PAPER_DOI}).</p>
<div style="display:flex;flex-wrap:wrap;gap:8px;margin:1em 0">
<a href="wiki-page.view?name=step-fig1"><img src="/_webdav/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/@files/figures/Fig1.png" alt="Fig1" style="max-width:180px;height:auto;border:1px solid #ccc"/></a>
<a href="wiki-page.view?name=step-fig2"><img src="/_webdav/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/@files/figures/Fig2.png" alt="Fig2" style="max-width:180px;height:auto;border:1px solid #ccc"/></a>
<a href="wiki-page.view?name=step-fig3"><img src="/_webdav/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/@files/figures/Fig3.png" alt="Fig3" style="max-width:180px;height:auto;border:1px solid #ccc"/></a>
<a href="wiki-page.view?name=step-fig4"><img src="/_webdav/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/@files/figures/Fig4.png" alt="Fig4" style="max-width:180px;height:auto;border:1px solid #ccc"/></a>
<a href="wiki-page.view?name=step-fig5"><img src="/_webdav/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/@files/figures/Fig5.png" alt="Fig5" style="max-width:180px;height:auto;border:1px solid #ccc"/></a>
</div>
<h3>Exercise (45–60 min)</h3>
<p><strong>Claim to test:</strong> <em>Anterior medial preoptic (aMPO) and median
raphe (MR) populations encode sleep deficit; activating them induces recovery-like
sleep; co-inhibiting GABAergic and serotonergic MR cells strongly reduces sleep.</em></p>
<p><strong>Hand-in:</strong>
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=SD_student_review">SD_student_review</a>
→ Insert one row (<code>reviewer</code> = your name). Do not edit <code>auto</code> rows.</p>
<ol>
<li><a href="wiki-page.view?name=claim">Read the exercise</a></li>
<li><a href="wiki-page.view?name=step-fig1">Fig. 1 — Fos / sleep deficit maps</a></li>
<li><a href="wiki-page.view?name=step-fig2">Fig. 2 — activation / CNO</a></li>
<li><a href="wiki-page.view?name=step-fig5">Fig. 5 — co-inhibition</a></li>
<li><a href="wiki-page.view?name=rubric">Rubric A–D</a></li>
</ol>
<p>Atlas: <a href="${ATLAS_URL}">sleep-wake-atlas.scicore.unibas.ch</a></p>
<h3>Lab quiz</h3>
<p>30 questions, shown <strong>one at a time</strong> with radio buttons and tick boxes, drawn from a
pool of 100 — <a href="wiki-page.view?name=quiz"><strong>start the quiz</strong></a>.
Take it as often as you like; every run is a different paper and LabKey scores it as you go:
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=SD_my_attempts">my attempts</a> ·
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=SD_my_review">my answers</a>.</p>
EOF
}

student_wiki_claim() {
  cat <<'EOF'
<h2>Exercise</h2>
<p>Time: 45–60 minutes. Do not edit rows with <code>reviewer = auto</code>.</p>
<h3>1. Hand-in</h3>
<p>Open
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=SD_student_review">SD_student_review</a>
→ <strong>Insert</strong>. One row. <code>reviewer</code> = your name.</p>
<h3>2. Claim to test</h3>
<blockquote>
Wake-activated neurons in the anterior medial preoptic area and the median
raphe encode sleep drive. Activating deprivation-responsive cells in these
regions produces longer, more intense sleep. Co-inhibiting GABAergic and
serotonergic median-raphe neurons can cut sleep by nearly 70%.
</blockquote>
<h3>3. Steps</h3>
<ol>
<li><a href="wiki-page.view?name=step-fig1">Fig. 1 source tables</a> — which conditions raise Fos in aMPO-related clusters?</li>
<li><a href="wiki-page.view?name=step-fig2">Fig. 2</a> — control vs CNO sleep metrics.</li>
<li><a href="wiki-page.view?name=step-fig5">Fig. 5</a> — control vs Kir2.1 time series; estimate the sleep reduction.</li>
<li><a href="wiki-page.view?name=rubric">Assign grade A–D</a>.</li>
</ol>
<table>
<tr><th>Column</th><th>Write</th></tr>
<tr><td>reviewer</td><td>Your name</td></tr>
<tr><td>claim_id</td><td>SLEEP-DRIVE-MAIN</td></tr>
<tr><td>figure</td><td>fig1 / fig2 / fig5 (primary figure you used)</td></tr>
<tr><td>region</td><td>aMPO, MR, GABA, 5-HT, …</td></tr>
<tr><td>finding</td><td>One sentence from the data</td></tr>
<tr><td>supported_by_source_data</td><td>yes / partial / no</td></tr>
<tr><td>grade</td><td>A, B, C, or D</td></tr>
<tr><td>notes</td><td>Which list/sheet you used</td></tr>
</table>
EOF
}

student_wiki_fig1() {
  cat <<EOF
<h2>Step — Fig. 1 source data</h2>
$(fig_img_html 1 "Mapping of whole-brain activity reveals correlates of sleep deprivation and recovery.")
<p>Open the <strong>fig1</strong> subfolder. Lists come from sheets such as
Fig1b (cluster mean Fos), Fig1d (subregion Fos), Fig1e (proportion awake).</p>
<p>Questions:</p>
<ul>
<li>How does normalized Fos change across deprivation timepoints?</li>
<li>Which example subregions rise under induced grooming SD?</li>
<li>How does “proportion of time spent awake” behave over hours?</li>
</ul>
<p>Next: <a href="wiki-page.view?name=step-fig2">Fig. 2</a></p>
EOF
}

student_wiki_fig2() {
  cat <<EOF
<h2>Step — Fig. 2 source data</h2>
$(fig_img_html 2 "Deprivation-TRAP cells promote NREM sleep and slow-wave activity.")
<p>Open <strong>fig2</strong>. Compare Control vs CNO (or Deprivation TRAP vs
Recovery TRAP) columns in the imported lists.</p>
<p>Does chemogenetic activation increase sleep intensity/duration relative to
control in the tables you see?</p>
<p>Next: <a href="wiki-page.view?name=step-fig5">Fig. 5</a></p>
EOF
}

student_wiki_fig5() {
  cat <<EOF
<h2>Step — Fig. 5 source data</h2>
$(fig_img_html 5 "Inhibition of MR GABAergic and serotonergic cells stably reduces sleep drive.")
<p>Open <strong>fig5</strong>. Several sheets are animal×hour matrices for
Control vs Kir2.1 (or similar inhibition).</p>
<p>Task: pick one sleep-related metric sheet. Summarise whether inhibited
animals show less sleep. The paper states co-inhibition can reduce sleep by
nearly 70% — does your chosen table support a large reduction?</p>
<p>Next: <a href="wiki-page.view?name=rubric">Rubric</a></p>
EOF
}

student_wiki_fig3() {
  cat <<EOF
<h2>Fig. 3 — projections</h2>
$(fig_img_html 3 "Targets and projection-specific functions of MR deprivation-TRAP cells.")
<p>Source tables: subfolder <strong>fig3</strong>.</p>
EOF
}

student_wiki_fig4() {
  cat <<EOF
<h2>Fig. 4 — GABA + serotonin</h2>
$(fig_img_html 4 "MR GABAergic cells synergistically promote sleep with serotonergic cells.")
<p>Source tables: subfolder <strong>fig4</strong>.</p>
EOF
}

student_wiki_rubric() {
  cat <<'EOF'
<h2>Rubric</h2>
<table>
<tr><th>Grade</th><th>Meaning</th></tr>
<tr><td>A</td><td>Finding tied to a named list/sheet with a concrete comparison (e.g. control vs CNO).</td></tr>
<tr><td>B</td><td>Correct region/claim but weak link to a specific table.</td></tr>
<tr><td>C</td><td>Restates the abstract only; no source-table check.</td></tr>
<tr><td>D</td><td>No figure/list cited.</td></tr>
</table>
<p>Insert your row in
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=SD_student_review">SD_student_review</a>.</p>
EOF
}

setup_student_path() {
  local folder="${LK_PROJECT}/${LK_FOLDER}"
  local dir="$DATA_DIR/sources/student_review/prepared"
  mkdir -p "$dir"
  python3 "$HELPER" student_populate "$dir/data.csv"
  # rebuild on --force, otherwise leave it alone — re-running the installer
  # must not append the three "auto" example rows a second time
  if [[ "$LK_FORCE" -eq 1 ]] && list_exists "$folder" "SD_student_review"; then
    delete_domain "$folder" "SD_student_review" || warn "could not drop SD_student_review"
  fi
  import_list "$folder" "$dir/data.csv" "$dir/schema.json" \
    "SD_student_review" "Student review" || true
  save_wiki "$folder" "Source Data Lab" "$(landing_wiki)" "home" || true
  save_wiki "$folder" "Exercise" "$(student_wiki_claim)" "claim" || true
  save_wiki "$folder" "Fig. 1 source data" "$(student_wiki_fig1)" "step-fig1" || true
  save_wiki "$folder" "Fig. 2 source data" "$(student_wiki_fig2)" "step-fig2" || true
  save_wiki "$folder" "Fig. 3 projections" "$(student_wiki_fig3)" "step-fig3" || true
  save_wiki "$folder" "Fig. 4 GABA serotonin" "$(student_wiki_fig4)" "step-fig4" || true
  save_wiki "$folder" "Fig. 5 source data" "$(student_wiki_fig5)" "step-fig5" || true
  save_wiki "$folder" "Rubric A-D" "$(student_wiki_rubric)" "rubric" || true
  ensure_quiz_assets || true
  if declare -F setup_quiz >/dev/null 2>&1; then
    setup_quiz || true
  else
    warn "setup_quiz not defined in installer (unexpected)"
  fi
  save_wiki "${LK_PROJECT}" "Sleep Drive Lab" "$(project_wiki)" "home" || true
  log "student path ready"
}

download_one() {
  local id="$1" url="$2" file="$3" dest="$DATA_DIR/raw/$file"
  if [[ -s "$dest" && "$LK_FORCE" -eq 0 ]]; then
    log "  already present: $file ($(wc -c < "$dest") bytes)"
    return 0
  fi
  log "  GET $url"
  curl -fsSL -A 'Mozilla/5.0' --connect-timeout 30 --max-time 300 -o "$dest" "$url" || {
    warn "download failed $id"
    return 1
  }
}

download_figures() {
  local id file url dest
  python3 -c 'import json,sys
for r in json.load(open(sys.argv[1])):
    print("\t".join([r["id"], r["file"], r["url"]]))
' "$DATA_DIR/figures.json" | while IFS=$'\t' read -r id file url; do
    dest="$DATA_DIR/figures/$file"
    if [[ -s "$dest" && "$LK_FORCE" -eq 0 ]]; then
      log "  figure present: $file ($(wc -c < "$dest") bytes)"
      continue
    fi
    log "  GET figure $file"
    curl -fsSL -A 'Mozilla/5.0' --connect-timeout 30 --max-time 120 -o "$dest" "$url" \
      || warn "figure download failed $id"
  done
}

webdav_put() {
  local folder="$1" rel="$2" localfile="$3" http ctype
  [[ -s "$localfile" ]] || return 1
  case "${rel##*.}" in
    html|htm) ctype="text/html; charset=utf-8" ;;
    json)     ctype="application/json; charset=utf-8" ;;
    js)       ctype="application/javascript; charset=utf-8" ;;
    css)      ctype="text/css; charset=utf-8" ;;
    png)      ctype="image/png" ;;
    jpg|jpeg) ctype="image/jpeg" ;;
    svg)      ctype="image/svg+xml" ;;
    *)        ctype="application/octet-stream" ;;
  esac
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X PUT \
    -H "Content-Type: ${ctype}" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    --data-binary @"$localfile" \
    -o /tmp/sd-dav.json -w '%{http_code}' \
    "${base}/_webdav/$(urlenc "$folder")/@files/${rel}" || true)"
  log "  webdav PUT ${rel} HTTP $(http_code "$http") (${ctype%%;*})"
}

upload_figures() {
  # Landing folder only (subfolders may not exist yet). Per-fig upload is in process_sources.
  local folder="${LK_PROJECT}/${LK_FOLDER}" file
  python3 -c 'import json,sys
for r in json.load(open(sys.argv[1])):
    print(r["file"])
' "$DATA_DIR/figures.json" | while read -r file; do
    [[ -s "$DATA_DIR/figures/$file" ]] || continue
    webdav_put "$folder" "figures/$file" "$DATA_DIR/figures/$file" || true
  done
}

upload_figure_to_subfolder() {
  local id="$1" file
  file="$(python3 -c 'import json,sys
for r in json.load(open(sys.argv[1])):
    if r["id"]==sys.argv[2]:
        print(r["file"]); break
' "$DATA_DIR/figures.json" "$id" 2>/dev/null || true)"
  [[ -n "$file" && -s "$DATA_DIR/figures/$file" ]] || return 0
  webdav_put "${LK_PROJECT}/${LK_FOLDER}/$id" "figures/$file" "$DATA_DIR/figures/$file" || true
}

fig_img_html() {
  local n="$1" caption="$2" folder="${LK_PROJECT}/${LK_FOLDER}"
  local src="/_webdav/$(urlenc "$folder")/@files/figures/Fig${n}.png"
  cat <<EOF
<figure style="margin:1em 0">
<img src="${src}" alt="Fig. ${n}" style="max-width:100%;height:auto;border:1px solid #ddd"/>
<figcaption><strong>Fig. ${n}.</strong> ${caption}
(<a href="${PAPER_URL}/figures/${n}">Nature figure page</a>)</figcaption>
</figure>
EOF
}

process_sources() {
  local rec id name file url note work listname
  python3 -c 'import json,sys
for r in json.load(open(sys.argv[1])):
    print("\t".join([r["id"], r["name"], r["file"], r["url"], r.get("note") or ""]))
' "$DATA_DIR/sources.json" | while IFS=$'\t' read -r id name file url note; do
    log "Source $id — $name"
    work="$DATA_DIR/sources/$id"
    mkdir -p "$work/prepared"
    if [[ "$LK_DRY_RUN" -eq 1 ]]; then
      log "  dry-run skip download"
      continue
    fi
    download_one "$id" "$url" "$file" || continue
    if [[ "$LK_LANDING_ONLY" -eq 1 ]]; then
      continue
    fi
    prep="$(python3 "$HELPER" convert "$DATA_DIR/raw/$file" "$work/prepared" "$LK_MAX_ROWS" || true)"
    log "  convert $prep"
    if [[ "$LK_IMPORT" -eq 1 ]]; then
      ensure_container "/${LK_PROJECT}/${LK_FOLDER}" "$id" || true
      upload_figure_to_subfolder "$id" || true
      python3 -c '
import json,sys,os
man=json.load(open(sys.argv[1]))
for t in man:
    print(t["id"]+"\t"+t["csv"]+"\t"+t["schema"]+"\t"+t.get("section",""))
' "$work/prepared/manifest.json" 2>/dev/null | while IFS=$'\t' read -r sid csv schema section; do
        listname="SD_${sid}"
        listname="$(printf '%s' "$listname" | cut -c1-60)"
        import_list "${LK_PROJECT}/${LK_FOLDER}/$id" "$csv" "$schema" "$listname" "$section" || true
        # also mirror on landing for easy discovery of small tables
        if [[ "$(python3 -c 'import json; print(json.load(open("'"$schema"'")).get("rows_written",0))')" -lt 5000 ]]; then
          import_list "${LK_PROJECT}/${LK_FOLDER}" "$csv" "$schema" "$listname" "$section" || true
        fi
      done
      save_wiki "${LK_PROJECT}/${LK_FOLDER}/$id" "$name" \
        "<h2>${name}</h2><p>${note}</p><p>Lists: schema <code>lists</code>, names <code>SD_*</code> from each Excel sheet.</p><p><a href='../project-begin.view'>Back to lab</a></p>" \
        "home" || true
    fi
  done
}

# ── main ──────────────────────────────────────────────────────────
if [[ "$LK_DRY_RUN" -eq 0 ]]; then
  download_figures || true
fi

if [[ "$LK_IMPORT" -eq 1 ]]; then
  [[ -n "$LK_APIKEY" || ( -n "$LK_USER" && -n "$LK_PASSWORD" ) ]] || die "--import needs credentials"
  login_session
  ensure_container "/" "$LK_PROJECT"
  ensure_container "/$LK_PROJECT" "$LK_FOLDER"
  upload_figures || true
  save_wiki "${LK_PROJECT}/${LK_FOLDER}" "Source Data Lab" "$(landing_wiki)" "home" || true
fi

process_sources

if [[ "$LK_IMPORT" -eq 1 ]]; then
  upload_figures || true
  setup_student_path || true
  log "Open ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/project-begin.view"
  log "Claim: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/wiki-page.view?name=claim"
  log "Quiz: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/wiki-page.view?name=quiz"
  log "My attempts: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/query-executeQuery.view?schemaName=lists&query.queryName=SD_my_attempts"
  log "All attempts: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/query-executeQuery.view?schemaName=lists&query.queryName=SD_quiz_history"
  log "Hand-in: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/query-executeQuery.view?schemaName=lists&query.queryName=SD_student_review"
  log "Paper: ${PAPER_URL}"
fi
log "Done. Data root: $DATA_DIR"
