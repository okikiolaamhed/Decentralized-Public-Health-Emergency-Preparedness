;; Coordination Protocol Contract
;; Facilitates multi-agency response coordination

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INCIDENT_NOT_FOUND (err u401))
(define-constant ERR_INVALID_STATUS (err u402))
(define-constant ERR_ALREADY_ASSIGNED (err u403))

;; Incident status types
(define-constant STATUS_REPORTED u0)
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_COORDINATING u2)
(define-constant STATUS_RESOLVED u3)
(define-constant STATUS_CLOSED u4)

;; Response types
(define-constant RESPONSE_MEDICAL u1)
(define-constant RESPONSE_EVACUATION u2)
(define-constant RESPONSE_CONTAINMENT u3)
(define-constant RESPONSE_LOGISTICS u4)

;; Data structures
(define-map incidents
  { incident-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    incident-type: (string-ascii 50),
    severity-level: uint,
    location: (string-ascii 100),
    reported-by: principal,
    reported-at: uint,
    status: uint,
    lead-coordinator: (optional principal)
  }
)

(define-map response-assignments
  { incident-id: uint, authority-id: principal }
  {
    response-type: uint,
    assigned-at: uint,
    assigned-by: principal,
    status: uint,
    estimated-completion: uint
  }
)

(define-map coordination-updates
  { update-id: uint }
  {
    incident-id: uint,
    authority-id: principal,
    update-type: (string-ascii 50),
    message: (string-ascii 300),
    timestamp: uint,
    priority: uint
  }
)

(define-data-var next-incident-id uint u1)
(define-data-var next-update-id uint u1)

;; Report new incident
(define-public (report-incident
  (title (string-ascii 100))
  (description (string-ascii 500))
  (incident-type (string-ascii 50))
  (severity-level uint)
  (location (string-ascii 100)))
  (let ((incident-id (var-get next-incident-id)))
    (map-set incidents
      { incident-id: incident-id }
      {
        title: title,
        description: description,
        incident-type: incident-type,
        severity-level: severity-level,
        location: location,
        reported-by: tx-sender,
        reported-at: block-height,
        status: STATUS_REPORTED,
        lead-coordinator: none
      }
    )

    (var-set next-incident-id (+ incident-id u1))
    (ok incident-id)
  )
)

;; Assign response authority to incident
(define-public (assign-response
  (incident-id uint)
  (authority-id principal)
  (response-type uint)
  (estimated-completion uint))
  (let ((incident (unwrap! (map-get? incidents { incident-id: incident-id }) ERR_INCIDENT_NOT_FOUND)))
    (asserts! (is-none (map-get? response-assignments { incident-id: incident-id, authority-id: authority-id })) ERR_ALREADY_ASSIGNED)

    (map-set response-assignments
      { incident-id: incident-id, authority-id: authority-id }
      {
        response-type: response-type,
        assigned-at: block-height,
        assigned-by: tx-sender,
        status: u1,
        estimated-completion: estimated-completion
      }
    )

    ;; Update incident status to coordinating if not already
    (if (is-eq (get status incident) STATUS_REPORTED)
      (map-set incidents
        { incident-id: incident-id }
        (merge incident { status: STATUS_COORDINATING })
      )
      true
    )

    (ok true)
  )
)

;; Set lead coordinator
(define-public (set-lead-coordinator (incident-id uint) (coordinator principal))
  (let ((incident (unwrap! (map-get? incidents { incident-id: incident-id }) ERR_INCIDENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set incidents
      { incident-id: incident-id }
      (merge incident { lead-coordinator: (some coordinator) })
    )

    (ok true)
  )
)

;; Add coordination update
(define-public (add-update
  (incident-id uint)
  (update-type (string-ascii 50))
  (message (string-ascii 300))
  (priority uint))
  (let ((update-id (var-get next-update-id)))
    (asserts! (is-some (map-get? incidents { incident-id: incident-id })) ERR_INCIDENT_NOT_FOUND)

    (map-set coordination-updates
      { update-id: update-id }
      {
        incident-id: incident-id,
        authority-id: tx-sender,
        update-type: update-type,
        message: message,
        timestamp: block-height,
        priority: priority
      }
    )

    (var-set next-update-id (+ update-id u1))
    (ok update-id)
  )
)

;; Update incident status
(define-public (update-incident-status (incident-id uint) (new-status uint))
  (let ((incident (unwrap! (map-get? incidents { incident-id: incident-id }) ERR_INCIDENT_NOT_FOUND)))
    (asserts! (<= new-status STATUS_CLOSED) ERR_INVALID_STATUS)

    (map-set incidents
      { incident-id: incident-id }
      (merge incident { status: new-status })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-incident (incident-id uint))
  (map-get? incidents { incident-id: incident-id })
)

(define-read-only (get-response-assignment (incident-id uint) (authority-id principal))
  (map-get? response-assignments { incident-id: incident-id, authority-id: authority-id })
)

(define-read-only (get-update (update-id uint))
  (map-get? coordination-updates { update-id: update-id })
)

(define-read-only (is-incident-active (incident-id uint))
  (match (map-get? incidents { incident-id: incident-id })
    incident (or (is-eq (get status incident) STATUS_ACTIVE) (is-eq (get status incident) STATUS_COORDINATING))
    false
  )
)
