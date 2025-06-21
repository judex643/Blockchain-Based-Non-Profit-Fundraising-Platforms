;; Fundraising Manager Verification Contract
;; Validates and manages non-profit fundraising managers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Data structures
(define-map verified-managers principal
  {
    organization-name: (string-ascii 100),
    verification-date: uint,
    status: (string-ascii 20),
    contact-info: (string-ascii 200)
  })

(define-map pending-verifications principal
  {
    organization-name: (string-ascii 100),
    application-date: uint,
    documents-hash: (string-ascii 64)
  })

;; Read-only functions
(define-read-only (is-verified-manager (manager principal))
  (match (map-get? verified-managers manager)
    manager-data (is-eq (get status manager-data) "active")
    false))

(define-read-only (get-manager-info (manager principal))
  (map-get? verified-managers manager))

(define-read-only (get-pending-application (manager principal))
  (map-get? pending-verifications manager))

;; Public functions
(define-public (apply-for-verification (org-name (string-ascii 100)) (docs-hash (string-ascii 64)))
  (let ((applicant tx-sender))
    (asserts! (is-none (map-get? verified-managers applicant)) ERR_ALREADY_VERIFIED)
    (ok (map-set pending-verifications applicant
      {
        organization-name: org-name,
        application-date: block-height,
        documents-hash: docs-hash
      }))))

(define-public (verify-manager (manager principal) (org-name (string-ascii 100)) (contact (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? pending-verifications manager)) ERR_NOT_FOUND)
    (map-delete pending-verifications manager)
    (ok (map-set verified-managers manager
      {
        organization-name: org-name,
        verification-date: block-height,
        status: "active",
        contact-info: contact
      }))))

(define-public (revoke-verification (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? verified-managers manager)) ERR_NOT_FOUND)
    (ok (map-set verified-managers manager
      (merge (unwrap-panic (map-get? verified-managers manager))
        { status: "revoked" })))))
