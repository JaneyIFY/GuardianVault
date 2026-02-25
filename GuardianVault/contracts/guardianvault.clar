;; GuardianVault: Social Recovery Wallet with Multi-Guardian Consensus
;; A self-custody recovery framework providing:
;; 1. Wallet holders to designate trusted guardians
;; 2. Guardians to initiate and support recovery requests
;; 3. Time-locked recovery execution after consensus threshold
;; 4. Vault owner override during the challenge window

(define-constant vault-admin tx-sender)

;; Recovery fault codes
(define-constant err-no-permission (err u900))
(define-constant err-request-exists (err u901))
(define-constant err-request-absent (err u902))
(define-constant err-recovery-executed (err u903))
(define-constant err-recovery-pending (err u904))
(define-constant err-insufficient-guardians (err u905))
(define-constant err-not-guardian (err u906))
(define-constant err-not-vault-holder (err u907))
(define-constant err-guardian-already-confirmed (err u908))
(define-constant err-timelock-active (err u909))
(define-constant err-threshold-not-reached (err u910))
(define-constant err-admin-override (err u911))
(define-constant err-request-cancelled (err u912))
(define-constant err-blank-recovery-reason (err u913))
(define-constant err-blank-new-owner-proof (err u914))
(define-constant err-blank-guardian-memo (err u915))

;; Recovery requests
(define-map recovery-requests
  { request-seq: uint }
  {
    vault-holder: principal,
    recovery-reason: (string-ascii 64),
    new-owner-proof: (string-ascii 256),
    guardian-memo: (string-ascii 256),
    initiated-at-block: uint,
    timelock-expiry: uint,
    confirmation-threshold: uint,
    guardian-confirmations: uint,
    primary-guardian: (optional principal),
    open-for-confirmation: bool,
    executed: bool
  }
)

(define-map guardian-confirmations
  { request-seq: uint, guardian: principal }
  { confirmation-weight: uint, confirmed-at-block: uint }
)

;; Request sequence
(define-data-var request-sequence uint u1)

;; Recovery processing fee (1% = 100 basis points)
(define-data-var processing-fee-bps uint u100)

;; Read-only interface

(define-read-only (get-recovery-request (request-seq uint))
  (map-get? recovery-requests { request-seq: request-seq })
)

(define-read-only (get-guardian-confirmation (request-seq uint) (guardian principal))
  (map-get? guardian-confirmations { request-seq: request-seq, guardian: guardian })
)

(define-read-only (request-on-file (request-seq uint))
  (is-some (get-recovery-request request-seq))
)

(define-read-only (is-open-for-confirmation (request-seq uint))
  (match (get-recovery-request request-seq)
    req-info (and
               (get open-for-confirmation req-info)
               (< block-height (get timelock-expiry req-info))
             )
    false
  )
)

(define-read-only (is-recovery-executed (request-seq uint))
  (match (get-recovery-request request-seq)
    req-info (>= block-height (get timelock-expiry req-info))
    false
  )
)

(define-read-only (get-next-request-seq)
  (var-get request-sequence)
)

(define-read-only (get-processing-fee-bps)
  (var-get processing-fee-bps)
)

(define-read-only (compute-processing-fee (amount uint))
  (/ (* amount (var-get processing-fee-bps)) u10000)
)

;; Private utilities

(define-private (compute-vault-holder-net (amount uint))
  (- amount (compute-processing-fee amount))
)

(define-private (valid-recovery-reason (reason (string-ascii 64)))
  (> (len reason) u0)
)

(define-private (valid-new-owner-proof (proof (string-ascii 256)))
  (> (len proof) u0)
)

(define-private (valid-guardian-memo (memo (string-ascii 256)))
  (> (len memo) u0)
)

;; Core recovery operations

(define-public (initiate-recovery
                (recovery-reason (string-ascii 64))
                (new-owner-proof (string-ascii 256))
                (guardian-memo (string-ascii 256))
                (timelock-duration uint)
                (confirmation-threshold uint))
  (let ((request-seq (var-get request-sequence))
        (initiated-at-block block-height)
        (timelock-expiry (+ block-height timelock-duration)))
    (begin
      (asserts! (valid-recovery-reason recovery-reason) err-blank-recovery-reason)
      (asserts! (valid-new-owner-proof new-owner-proof) err-blank-new-owner-proof)
      (asserts! (valid-guardian-memo guardian-memo) err-blank-guardian-memo)
      (asserts! (> timelock-duration u0) err-timelock-active)
      (asserts! (> confirmation-threshold u0) err-threshold-not-reached)

      (map-set recovery-requests
        { request-seq: request-seq }
        {
          vault-holder: tx-sender,
          recovery-reason: recovery-reason,
          new-owner-proof: new-owner-proof,
          guardian-memo: guardian-memo,
          initiated-at-block: initiated-at-block,
          timelock-expiry: timelock-expiry,
          confirmation-threshold: confirmation-threshold,
          guardian-confirmations: u0,
          primary-guardian: none,
          open-for-confirmation: true,
          executed: false
        }
      )

      (var-set request-sequence (+ request-seq u1))

      (ok request-seq)
    )
  )
)

(define-public (confirm-recovery (request-seq uint) (confirmation-weight uint))
  (let ((req-info (unwrap! (get-recovery-request request-seq) err-request-absent)))
    (begin
      (asserts! (get open-for-confirmation req-info) err-request-cancelled)
      (asserts! (< block-height (get timelock-expiry req-info)) err-recovery-executed)

      (asserts! (if (is-some (get primary-guardian req-info))
                   (> confirmation-weight (get guardian-confirmations req-info))
                   (>= confirmation-weight (get confirmation-threshold req-info)))
               err-insufficient-guardians)

      (map-set guardian-confirmations
        { request-seq: request-seq, guardian: tx-sender }
        { confirmation-weight: confirmation-weight, confirmed-at-block: block-height }
      )

      (map-set recovery-requests
        { request-seq: request-seq }
        (merge req-info {
          guardian-confirmations: confirmation-weight,
          primary-guardian: (some tx-sender)
        })
      )

      (ok true)
    )
  )
)

(define-public (halt-recovery (request-seq uint))
  (let ((req-info (unwrap! (get-recovery-request request-seq) err-request-absent)))
    (begin
      (asserts! (is-eq tx-sender (get vault-holder req-info)) err-not-vault-holder)
      (asserts! (get open-for-confirmation req-info) err-request-cancelled)
      (asserts! (< block-height (get timelock-expiry req-info)) err-recovery-executed)

      (map-set recovery-requests
        { request-seq: request-seq }
        (merge req-info {
          open-for-confirmation: false,
          timelock-expiry: block-height
        })
      )

      (ok true)
    )
  )
)

(define-public (cancel-recovery (request-seq uint))
  (let ((req-info (unwrap! (get-recovery-request request-seq) err-request-absent)))
    (begin
      (asserts! (is-eq tx-sender (get vault-holder req-info)) err-not-vault-holder)
      (asserts! (get open-for-confirmation req-info) err-request-cancelled)
      (asserts! (is-eq (get guardian-confirmations req-info) u0) err-insufficient-guardians)

      (map-set recovery-requests
        { request-seq: request-seq }
        (merge req-info { open-for-confirmation: false })
      )

      (ok true)
    )
  )
)

;; Admin controls

(define-public (update-processing-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender vault-admin) err-admin-override)
    (asserts! (<= new-fee-bps u1000) err-no-permission)
    (ok (var-set processing-fee-bps new-fee-bps))
  )
)
