;; state-compliance core contract
;; A decentralized system for tracking, verifying, and credentialing sustainable state-level compliance efforts.
;; The contract enables public and private entities to submit, validate, and recognize sustainability achievements.

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-RECORD-NOT-FOUND (err u101))
(define-constant ERR-COMPLIANCE-ALREADY-PROCESSED (err u102))
(define-constant ERR-INVALID-COMPLIANCE-TYPE (err u103))
(define-constant ERR-INVALID-QUANTITY (err u104))
(define-constant ERR-INSUFFICIENT-VERIFICATIONS (err u105))
(define-constant ERR-ALREADY-VERIFIED (err u106))
(define-constant ERR-NOT-VALIDATOR (err u107))
(define-constant ERR-EXTERNAL-SOURCE-UNAUTHORIZED (err u108))
(define-constant ERR-VERIFICATION-PERIOD-EXPIRED (err u109))

;; State Management
(define-data-var platform-admin principal tx-sender)

;; Compliance Type Registry
(define-map compliance-types 
  { compliance-type: (string-ascii 32) }
  { 
    carbon-impact-factor: uint, 
    measurement-unit: (string-ascii 16), 
    active: bool 
  }
)

;; Registered Compliance Entities
(define-map compliance-entities
  { entity-id: uint }
  {
    owner: principal,
    name: (string-utf8 50),
    description: (string-utf8 500),
    jurisdiction: (string-utf8 100),
    registered-at: uint,
    total-verified-impact: uint,
    status: (string-ascii 10)
  }
)

;; Entity Validators
(define-map entity-validators
  { entity-id: uint, validator: principal }
  { 
    authorized-at: uint,
    authorized-by: principal
  }
)

;; Compliance Claims
(define-map compliance-claims
  { claim-id: uint }
  {
    entity-id: uint,
    compliance-type: (string-ascii 32),
    quantity: uint,
    evidence-url: (string-utf8 200),
    submitted-by: principal,
    submitted-at: uint,
    status: (string-ascii 12),
    verification-expiry: uint,
    verifications-required: uint,
    verifications-received: uint,
    verified-quantity: uint
  }
)

;; Tracking Counters
(define-data-var next-entity-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var total-platform-compliance uint u0)

;; Private Functions
(define-private (calculate-carbon-impact (compliance-type (string-ascii 32)) (quantity uint))
  (let ((type-info (unwrap! (map-get? compliance-types { compliance-type: compliance-type }) u0)))
    (if (get active type-info)
        (* quantity (get carbon-impact-factor type-info))
        u0)
  )
)

;; Public Functions
(define-public (set-platform-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-admin)) ERR-UNAUTHORIZED)
    (var-set platform-admin new-admin)
    (ok true)
  )
)

(define-public (register-compliance-type 
    (compliance-type (string-ascii 32)) 
    (carbon-impact-factor uint) 
    (measurement-unit (string-ascii 16)))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-admin)) ERR-UNAUTHORIZED)
    (map-set compliance-types 
      { compliance-type: compliance-type }
      { 
        carbon-impact-factor: carbon-impact-factor, 
        measurement-unit: measurement-unit,
        active: true 
      }
    )
    (ok true)
  )
)

(define-public (register-compliance-entity 
    (name (string-utf8 50)) 
    (description (string-utf8 500)) 
    (jurisdiction (string-utf8 100)))
  (let (
    (entity-id (var-get next-entity-id))
    (current-block block-height)
  )
    (map-set compliance-entities
      { entity-id: entity-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        jurisdiction: jurisdiction,
        registered-at: current-block,
        total-verified-impact: u0,
        status: "active"
      }
    )
    ;; Automatically add entity owner as first validator
    (map-set entity-validators
      { entity-id: entity-id, validator: tx-sender }
      {
        authorized-at: current-block,
        authorized-by: tx-sender
      }
    )
    (var-set next-entity-id (+ entity-id u1))
    (ok entity-id)
  )
)

(define-public (submit-compliance-claim
    (entity-id uint)
    (compliance-type (string-ascii 32))
    (quantity uint)
    (evidence-url (string-utf8 200))
    (verification-expiry uint)
    (verifications-required uint))
  (let (
    (entity (unwrap! (map-get? compliance-entities { entity-id: entity-id }) ERR-RECORD-NOT-FOUND))
    (type-info (unwrap! (map-get? compliance-types { compliance-type: compliance-type }) ERR-INVALID-COMPLIANCE-TYPE))
    (claim-id (var-get next-claim-id))
    (current-block block-height)
  )
    ;; Input validation
    (asserts! (is-eq tx-sender (get owner entity)) ERR-UNAUTHORIZED)
    (asserts! (get active type-info) ERR-INVALID-COMPLIANCE-TYPE)
    (asserts! (> quantity u0) ERR-INVALID-QUANTITY)
    (asserts! (> verifications-required u0) (err u112))
    (asserts! (> verification-expiry current-block) (err u113))
    
    ;; Create compliance claim
    (map-set compliance-claims
      { claim-id: claim-id }
      {
        entity-id: entity-id,
        compliance-type: compliance-type,
        quantity: quantity,
        evidence-url: evidence-url,
        submitted-by: tx-sender,
        submitted-at: current-block,
        status: "pending",
        verification-expiry: verification-expiry,
        verifications-required: verifications-required,
        verifications-received: u0,
        verified-quantity: u0
      }
    )
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

;; Read-only Functions
(define-read-only (get-compliance-type-info (compliance-type (string-ascii 32)))
  (map-get? compliance-types { compliance-type: compliance-type })
)

(define-read-only (get-total-platform-compliance)
  (var-get total-platform-compliance)
)