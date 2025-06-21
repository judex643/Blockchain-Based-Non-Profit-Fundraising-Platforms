;; Donor Engagement Contract
;; Manages donor interactions and rewards

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_DONOR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_DONATION (err u302))
(define-constant ERR_INSUFFICIENT_BALANCE (err u303))

;; Data structures
(define-map donors principal
  {
    total-donated: uint,
    campaigns-supported: uint,
    join-date: uint,
    reputation-score: uint,
    preferred-categories: (list 5 (string-ascii 50))
  })

(define-map donations uint
  {
    donor: principal,
    campaign-id: uint,
    amount: uint,
    donation-date: uint,
    message: (optional (string-ascii 200))
  })

(define-map donor-rewards principal (list 10 (string-ascii 100)))
(define-data-var next-donation-id uint u1)

;; Read-only functions
(define-read-only (get-donor-profile (donor principal))
  (map-get? donors donor))

(define-read-only (get-donation (donation-id uint))
  (map-get? donations donation-id))

(define-read-only (get-donor-rewards (donor principal))
  (default-to (list) (map-get? donor-rewards donor)))

(define-read-only (calculate-reputation-score (total-donated uint) (campaigns-supported uint))
  (+ (/ total-donated u1000) (* campaigns-supported u10)))

;; Public functions
(define-public (register-donor (preferred-cats (list 5 (string-ascii 50))))
  (let ((donor tx-sender))
    (ok (map-set donors donor
      {
        total-donated: u0,
        campaigns-supported: u0,
        join-date: block-height,
        reputation-score: u0,
        preferred-categories: preferred-cats
      }))))

(define-public (make-donation
  (campaign-id uint)
  (amount uint)
  (message (optional (string-ascii 200))))
  (let ((donation-id (var-get next-donation-id))
        (donor tx-sender)
        (donor-data (default-to
          {
            total-donated: u0,
            campaigns-supported: u0,
            join-date: block-height,
            reputation-score: u0,
            preferred-categories: (list)
          }
          (map-get? donors donor))))
    (asserts! (> amount u0) ERR_INVALID_DONATION)

    ;; Record the donation
    (map-set donations donation-id
      {
        donor: donor,
        campaign-id: campaign-id,
        amount: amount,
        donation-date: block-height,
        message: message
      })

    ;; Update donor profile
    (let ((new-total (+ (get total-donated donor-data) amount))
          (new-campaigns (+ (get campaigns-supported donor-data) u1)))
      (map-set donors donor
        (merge donor-data
          {
            total-donated: new-total,
            campaigns-supported: new-campaigns,
            reputation-score: (calculate-reputation-score new-total new-campaigns)
          })))

    (var-set next-donation-id (+ donation-id u1))
    (ok donation-id)))

(define-public (award-donor-badge (donor principal) (badge (string-ascii 100)))
  (let ((current-rewards (get-donor-rewards donor)))
    (ok (map-set donor-rewards donor
      (unwrap-panic (as-max-len? (append current-rewards badge) u10))))))

(define-public (update-preferences (new-categories (list 5 (string-ascii 50))))
  (let ((donor tx-sender)
        (donor-data (unwrap! (map-get? donors donor) ERR_DONOR_NOT_FOUND)))
    (ok (map-set donors donor
      (merge donor-data { preferred-categories: new-categories })))))
