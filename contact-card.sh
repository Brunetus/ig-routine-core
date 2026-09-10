#!/bin/zsh
# contact-card.sh — the one writer of a job folder's CONTACT-<who>.txt card.
# Sourced by run-reel-worker.sh (after each render session exits) and by
# backfill-contact-cards.sh (historical folders). One definition so the two
# paths cannot drift.
#
# WHY A CARD AND NOT A RENAMED FOLDER (Marcus, 2026-08-27): the folder name IS
# the server job id. release-reel.sh derives it from the directory name
# (`for P in "$JOBS_DIR"/*/PENDING-RELEASE`), so a renamed folder strands the
# delivery — the customer's finished reel never ships. The card gives the same
# "whose is this?" at a glance with none of that risk.
#
# WHY IT IS WRITTEN LATE: the render session's cwd IS the job folder, and
# run-reel-worker.sh deliberately strips email/phone out of job.json so the
# session never sees contact info. The card is written only once that session
# has exited, and is deleted again before any re-dispatch.

# write_contact_card <job_dir> <id> <email> <phone> <handle> <client> <created> <story> <url> [note]
write_contact_card() {
  local JOB="$1" ID="$2" EMAIL="$3" PHONE="$4" HANDLE="$5" CLIENT="$6" CREATED="$7" STORY="$8" URL="$9"
  local NOTE="${10:-}"
  [ -d "$JOB" ] || return 1

  # No email and no client means nobody is waiting on this one: it's one of
  # Marcus's own runs (variation showcase, e2e test). Say that, rather than
  # filing nine folders under "unknown".
  local LABEL="${EMAIL:-${CLIENT:-}}"
  if [ -z "$LABEL" ]; then
    if [ -n "$NOTE" ]; then LABEL="internal"; else LABEL="unknown"; fi
  fi
  # normEmail caps nothing, and a >247-char label makes the open() fail with
  # "file name too long" while this function still returns 0 — a silently
  # missing card that reads as success.
  LABEL="${LABEL[1,120]}"
  # Whitelist, not blacklist: this subsumes the slash and colon cases and caps
  # BYTES at chars, so a multi-byte local part cannot blow past NAME_MAX.
  LABEL="${LABEL//[^A-Za-z0-9._@+-]/-}"
  [ -n "$LABEL" ] || LABEL="unknown"

  # One card per folder: a re-run after the email is known must not leave the
  # old CONTACT-unknown.txt sitting beside the new one.
  rm -f "$JOB"/CONTACT-*.txt(N) 2>/dev/null   # (N): an unmatched glob must not abort the rm

  {
    printf 'job:        %s\n' "$ID"
    if [ -n "$EMAIL" ]; then printf 'email:      %s\n' "$EMAIL"
    elif [ -n "$CLIENT" ]; then printf 'email:      (none - drive-watch client job)\n'
    elif [ -n "$NOTE" ]; then printf "email:      (none - Marcus's own run, nobody is waiting on it)\n"
    else printf 'email:      (none)\n'; fi
    printf 'phone:      %s\n' "${PHONE:-(none)}"
    if [ -n "$HANDLE" ]; then printf 'instagram:  @%s\n' "$HANDLE"; else printf 'instagram:  (not given)\n'; fi
    if [ -n "$CLIENT" ]; then printf 'client:     %s\n' "$CLIENT"
    elif [ -n "$EMAIL" ]; then printf 'client:     (free reel)\n'
    else printf 'client:     (not a customer job)\n'; fi
    printf 'created:    %s\n' "${CREATED:-(unknown)}"
    printf 'reel:       %s\n' "${URL:-(unknown)}"
    printf '\n'
    printf 'what they said is happening in the clips:\n'
    printf '%s\n' "${STORY:-(no story - this job predates the required context field, 2026-08-27)}"
    if [ -n "$NOTE" ]; then
      printf '\n'
      printf "marcus_note (this was a directed run, not a plain intake):\n"
      printf '%s\n' "${NOTE[1,300]}"
    fi
  } > "$JOB/CONTACT-$LABEL.txt" 2>/dev/null

  # Report the truth: a failed redirection must not read as success.
  [ -f "$JOB/CONTACT-$LABEL.txt" ] || return 1
  return 0
}
