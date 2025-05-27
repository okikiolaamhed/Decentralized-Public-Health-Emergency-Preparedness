;; Health Authority Verification Contract
;; Manages verification and registration of emergency response agencies

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Authority status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map authorities
  { authority-id: principal }
  {
    name: (string-ascii 100),
    authority-type: (string-ascii 50),
    jurisdiction: (string-ascii 100),
    status: uint,
    verified-at: uint,
    verified-by: principal
  }
)

(define-map authority-capabilities
  { authority-id: principal }
  {
    can-coordinate: bool,
    can-allocate-resources: bool,
    can-issue-alerts: bool,
    emergency-level: uint
  }
)

(define-data-var total-authorities uint u0)

;; Register a new health authority
(define-public (register-authority
  (authority-id principal)
  (name (string-ascii 100))
  (authority-type (string-ascii 50))
  (jurisdiction (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? authorities { authority-id: authority-id })) ERR_ALREADY_VERIFIED)

    (map-set authorities
      { authority-id: authority-id }
      {
        name: name,
        authority-type: authority-type,
        jurisdiction: jurisdiction,
        status: STATUS_PENDING,
        verified-at: u0,
        verified-by: tx-sender
      }
    )

    (var-set total-authorities (+ (var-get total-authorities) u1))
    (ok authority-id)
  )
)

;; Verify an authority
(define-public (verify-authority (authority-id principal))
  (let ((authority (unwrap! (map-get? authorities { authority-id: authority-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status authority) STATUS_PENDING) ERR_INVALID_STATUS)

    (map-set authorities
      { authority-id: authority-id }
      (merge authority {
        status: STATUS_VERIFIED,
        verified-at: block-height,
        verified-by: tx-sender
      })
    )

    (ok true)
  )
)

;; Set authority capabilities
(define-public (set-capabilities
  (authority-id principal)
  (can-coordinate bool)
  (can-allocate-resources bool)
  (can-issue-alerts bool)
  (emergency-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? authorities { authority-id: authority-id })) ERR_NOT_FOUND)

    (map-set authority-capabilities
      { authority-id: authority-id }
      {
        can-coordinate: can-coordinate,
        can-allocate-resources: can-allocate-resources,
        can-issue-alerts: can-issue-alerts,
        emergency-level: emergency-level
      }
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-authority (authority-id principal))
  (map-get? authorities { authority-id: authority-id })
)

(define-read-only (get-capabilities (authority-id principal))
  (map-get? authority-capabilities { authority-id: authority-id })
)

(define-read-only (is-verified (authority-id principal))
  (match (map-get? authorities { authority-id: authority-id })
    authority (is-eq (get status authority) STATUS_VERIFIED)
    false
  )
)

(define-read-only (get-total-authorities)
  (var-get total-authorities)
)
