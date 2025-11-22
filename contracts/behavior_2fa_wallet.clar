;; ------------------------------------------------------------
;; Contract: behavior_2fa_wallet
;; Purpose: Behavior-triggered 2FA smart wallet
;; Owner can transfer freely unless:
;;   - transfer amount > threshold
;;   - recipient has never received before
;; Then guardian approval is required.
;; ------------------------------------------------------------

;; -------------------------
;; Data Vars
;; -------------------------

(define-data-var owner principal tx-sender)
(define-data-var guardian principal tx-sender)

;; Maximum amount that does NOT require guardian approval
(define-data-var threshold uint u1000000) ;; default = 1,000,000 microSTX (1 STX)

;; Tracks known recipients
(define-map known-recipients
  { recipient: principal }
  { known: bool })

;; Pending transfer state
(define-data-var pending-amount uint u0)
(define-data-var pending-recipient principal 'SP000000000000000000002Q6VF78)
(define-data-var pending-active bool false)

;; -------------------------
;; Error Codes
;; -------------------------

(define-constant ERR-NOT-OWNER        (err u100))
(define-constant ERR-NOT-GUARDIAN     (err u101))
(define-constant ERR-TRANSFER-PENDING (err u102))
(define-constant ERR-NO-PENDING       (err u103))
(define-constant ERR-INVALID-AMOUNT   (err u104))
(define-constant ERR-NOT-ACTIVE       (err u105))

;; -------------------------
;; Helper Checks
;; -------------------------

(define-read-only (is-owner (sender principal))
  (is-eq sender (var-get owner))
)

(define-read-only (is-guardian (sender principal))
  (is-eq sender (var-get guardian))
)

(define-read-only (is-known (rcp principal))
  (match (map-get? known-recipients { recipient: rcp })
    data (get known data)
    false
  )
)

;; -------------------------
;; Change guardian (owner only)
;; -------------------------

(define-public (set-guardian (new-g principal))
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    (asserts! (not (is-eq new-g (as-contract tx-sender))) ERR-INVALID-AMOUNT)
    (var-set guardian new-g)
    (ok true)
  )
)

;; -------------------------
;; Set behavior threshold
;; -------------------------

(define-public (set-threshold (new-threshold uint))
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    (asserts! (> new-threshold u0) ERR-INVALID-AMOUNT)
    (var-set threshold new-threshold)
    (ok true)
  )
)

;; -------------------------
;; Normal or 2FA-Triggered Transfer
;; -------------------------

(define-public (transfer (amount uint) (recipient principal))
  (begin
    ;; Only owner can initiate a transfer
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    ;; Can't start a new transfer if one is pending
    (asserts! (not (var-get pending-active)) ERR-TRANSFER-PENDING)
    ;; Cannot send zero
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    (let
      (
        (over-limit (> amount (var-get threshold)))
        (new-recipient (not (is-known recipient)))
      )

      (if (or over-limit new-recipient)
          ;; ----------------------------------------
          ;; Store transfer as pending (requires 2FA)
          ;; ----------------------------------------
          (begin
            (var-set pending-amount amount)
            (var-set pending-recipient recipient)
            (var-set pending-active true)
            (ok { requires-2fa: true })
          )

          ;; ----------------------------------------
          ;; Proceed with normal transfer
          ;; ----------------------------------------
          (match (stx-transfer? amount tx-sender recipient)
            success
              (begin
                (map-set known-recipients { recipient: recipient } { known: true })
                (ok { requires-2fa: false })
              )
            error (err u200)
          )
      )
    )
  )
)

;; -------------------------
;; Guardian Approves Pending Transfer (2FA)
;; -------------------------

(define-public (approve-transfer)
  (begin
    (asserts! (is-guardian tx-sender) ERR-NOT-GUARDIAN)
    (asserts! (var-get pending-active) ERR-NO-PENDING)

    (let
      (
        (amount (var-get pending-amount))
        (recipient (var-get pending-recipient))
      )

      ;; Execute transfer as contract on behalf of owner
      (as-contract
        (match (stx-transfer? amount (var-get owner) recipient)
          success
            (begin
              (map-set known-recipients { recipient: recipient } { known: true })
              (var-set pending-amount u0)
              (var-set pending-active false)
              (ok true)
            )
          error (err u201)
        )
      )
    )
  )
)

;; -------------------------
;; Owner can cancel pending transfer
;; -------------------------

(define-public (cancel-pending)
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    (asserts! (var-get pending-active) ERR-NO-PENDING)

    (var-set pending-amount u0)
    (var-set pending-active false)
    (ok true)
  )
)

;; -------------------------
;; View Pending Transfer State
;; -------------------------

(define-read-only (pending-state)
  { amount: (var-get pending-amount),
    recipient: (var-get pending-recipient),
    active: (var-get pending-active) }
)
